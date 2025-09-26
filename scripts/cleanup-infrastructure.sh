#!/bin/bash

# Script to import existing AWS resources and destroy infrastructure
# This script handles cases where GitHub Actions fails and manual cleanup is needed

set -e

echo "=========================================="
echo "AWS Infrastructure Cleanup Script"
echo "=========================================="

# Change to infrastructure directory
cd "$(dirname "$0")/../infrastructure"

# Check if AWS credentials are configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "Error: AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

echo "AWS credentials verified."

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Function to safely import a resource
import_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local aws_resource_id="$3"
    
    echo "Attempting to import $resource_type: $resource_name"
    if terraform import "$resource_type" "$aws_resource_id" 2>/dev/null; then
        echo "✓ Successfully imported $resource_name"
    else
        echo "⚠ $resource_name not found or already in state"
    fi
}

# Function to get AWS resource ARN/ID safely
get_resource_id() {
    local aws_command="$1"
    local query="$2"
    local fallback="$3"
    
    local result=$(eval "$aws_command" 2>/dev/null || echo "")
    if [ -z "$result" ] || [ "$result" = "None" ] || [ "$result" = "null" ]; then
        echo "$fallback"
    else
        echo "$result"
    fi
}

echo ""
echo "Importing existing AWS resources into Terraform state..."

# Import IAM Roles
echo "Importing IAM roles..."
import_resource "aws_iam_role.ecs_execution_role" "ECS Execution Role" "ml-devops-dev-ecs-execution-role"
import_resource "aws_iam_role.ecs_task_role" "ECS Task Role" "ml-devops-dev-ecs-task-role"

# Import IAM Role Policies
echo "Importing IAM role policies..."
import_resource "aws_iam_role_policy.ecs_execution_role_policy" "ECS Execution Role Policy" "ml-devops-dev-ecs-execution-role:ml-devops-dev-ecs-execution-policy"
import_resource "aws_iam_role_policy.ecs_task_role_policy" "ECS Task Role Policy" "ml-devops-dev-ecs-task-role:ml-devops-dev-ecs-task-policy"

# Import ECR Repository
echo "Importing ECR repository..."
import_resource "aws_ecr_repository.ml_model" "ECR Repository" "ml-devops-dev-ml-model"

# Import ECS Cluster
echo "Importing ECS cluster..."
import_resource "aws_ecs_cluster.main" "ECS Cluster" "ml-devops-dev-cluster"

# Import Load Balancer
echo "Importing Application Load Balancer..."
ALB_ARN=$(get_resource_id "aws elbv2 describe-load-balancers --names ml-devops-dev-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text" "LoadBalancerArn" "")
if [ "$ALB_ARN" != "" ]; then
    import_resource "aws_lb.main" "Application Load Balancer" "$ALB_ARN"
fi

# Import Target Group
echo "Importing Target Group..."
TG_ARN=$(get_resource_id "aws elbv2 describe-target-groups --names ml-devops-dev-tg --query 'TargetGroups[0].TargetGroupArn' --output text" "TargetGroupArn" "")
if [ "$TG_ARN" != "" ]; then
    import_resource "aws_lb_target_group.main" "Target Group" "$TG_ARN"
fi

# Import ALB Listener
echo "Importing ALB Listener..."
LISTENER_ARN=$(get_resource_id "aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --query 'Listeners[0].ListenerArn' --output text" "ListenerArn" "")
if [ "$LISTENER_ARN" != "" ]; then
    import_resource "aws_lb_listener.main" "ALB Listener" "$LISTENER_ARN"
fi

# Import ECS Service
echo "Importing ECS service..."
import_resource "aws_ecs_service.main" "ECS Service" "ml-devops-dev-cluster/ml-devops-dev-service"

# Import ECS Task Definition
echo "Importing ECS task definition..."
TASK_DEF_ARN=$(get_resource_id "aws ecs describe-task-definition --task-definition ml-devops-dev-task --query 'taskDefinition.taskDefinitionArn' --output text" "TaskDefinitionArn" "")
if [ "$TASK_DEF_ARN" != "" ]; then
    import_resource "aws_ecs_task_definition.main" "ECS Task Definition" "$TASK_DEF_ARN"
fi

# Import CloudWatch Log Group
echo "Importing CloudWatch Log Group..."
import_resource "aws_cloudwatch_log_group.main" "CloudWatch Log Group" "/ecs/ml-devops-dev"

# Import Auto Scaling Target
echo "Importing Auto Scaling Target..."
import_resource "aws_appautoscaling_target.ecs_target" "Auto Scaling Target" "ecs/service/ml-devops-dev-cluster/ml-devops-dev-service"

# Import Auto Scaling Policies
echo "Importing Auto Scaling Policies..."
import_resource "aws_appautoscaling_policy.ecs_policy_cpu" "CPU Scaling Policy" "ecs/service/ml-devops-dev-cluster/ml-devops-dev-service:ml-devops-dev-cpu-scaling"
import_resource "aws_appautoscaling_policy.ecs_policy_memory" "Memory Scaling Policy" "ecs/service/ml-devops-dev-cluster/ml-devops-dev-service:ml-devops-dev-memory-scaling"

# Import Security Groups
echo "Importing Security Groups..."
ALB_SG_ID=$(get_resource_id "aws ec2 describe-security-groups --filters 'Name=group-name,Values=ml-devops-dev-alb-*' --query 'SecurityGroups[0].GroupId' --output text" "GroupId" "")
if [ "$ALB_SG_ID" != "" ]; then
    import_resource "aws_security_group.alb" "ALB Security Group" "$ALB_SG_ID"
fi

ECS_SG_ID=$(get_resource_id "aws ec2 describe-security-groups --filters 'Name=group-name,Values=ml-devops-dev-ecs-tasks-*' --query 'SecurityGroups[0].GroupId' --output text" "GroupId" "")
if [ "$ECS_SG_ID" != "" ]; then
    import_resource "aws_security_group.ecs_tasks" "ECS Tasks Security Group" "$ECS_SG_ID"
fi

# Import CloudWatch Dashboard
echo "Importing CloudWatch Dashboard..."
import_resource "aws_cloudwatch_dashboard.main" "CloudWatch Dashboard" "ml-devops-dev-dashboard"

echo ""
echo "All resources imported. Running terraform plan to verify state..."

# Run terraform plan to verify everything is in sync
terraform plan -out=tfplan

echo ""
echo "=========================================="
echo "Ready to destroy infrastructure"
echo "=========================================="
echo ""
echo "The following resources will be destroyed:"
terraform show -no-color | grep -E "^(Plan:|# |~ |\+ |\- )" || true

echo ""
read -p "Do you want to proceed with destroying all infrastructure? (yes/no): " confirm

if [ "$confirm" = "yes" ] || [ "$confirm" = "y" ]; then
    echo ""
    echo "Destroying infrastructure..."
    terraform destroy -auto-approve
    
    echo ""
    echo "=========================================="
    echo "Infrastructure cleanup completed successfully!"
    echo "=========================================="
else
    echo ""
    echo "Cleanup cancelled. Infrastructure remains intact."
    echo "You can run this script again later to destroy the infrastructure."
fi
