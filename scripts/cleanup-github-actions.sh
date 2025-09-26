#!/bin/bash

# GitHub Actions Compatible Cleanup Script
# This script destroys ALL AWS resources created by this project
# Designed to run in GitHub Actions environment

set -e

# Colors for output (GitHub Actions supports these)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - Use environment variables with defaults
PROJECT_NAME="${PROJECT_NAME:-ml-devops}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-us-east-2}"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check AWS credentials
check_aws_credentials() {
    log_info "Checking AWS credentials..."
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured."
        exit 1
    fi
    log_success "AWS credentials verified"
}

# Cleanup ECS resources
cleanup_ecs() {
    log_info "Cleaning up ECS resources..."
    
    # Get cluster name
    CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cluster"
    SERVICE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-service"
    
    # Check if cluster exists
    if aws ecs describe-clusters --clusters $CLUSTER_NAME --region $AWS_REGION &> /dev/null; then
        log_info "Found ECS cluster: $CLUSTER_NAME"
        
        # Check if service exists and scale it down
        if aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION &> /dev/null; then
            log_info "Scaling down ECS service..."
            aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --desired-count 0 --region $AWS_REGION || true
            
            log_info "Waiting for tasks to stop..."
            aws ecs wait services-stable --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION || true
            
            log_info "Deleting ECS service..."
            aws ecs delete-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --region $AWS_REGION || true
        fi
        
        log_info "Deleting ECS cluster..."
        aws ecs delete-cluster --cluster $CLUSTER_NAME --region $AWS_REGION || true
        log_success "ECS resources cleaned up"
    else
        log_info "ECS cluster not found"
    fi
}

# Cleanup Load Balancer resources
cleanup_load_balancer() {
    log_info "Cleaning up Load Balancer resources..."
    
    ALB_NAME="${PROJECT_NAME}-${ENVIRONMENT}-alb"
    TG_NAME="${PROJECT_NAME}-${ENVIRONMENT}-tg"
    
    # Get ALB ARN
    ALB_ARN=$(aws elbv2 describe-load-balancers --names $ALB_NAME --region $AWS_REGION --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "None")
    
    if [ "$ALB_ARN" != "None" ] && [ ! -z "$ALB_ARN" ]; then
        log_info "Found Load Balancer: $ALB_ARN"
        
        # Get Target Group ARN
        TG_ARN=$(aws elbv2 describe-target-groups --names $TG_NAME --region $AWS_REGION --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "None")
        
        if [ "$TG_ARN" != "None" ] && [ ! -z "$TG_ARN" ]; then
            log_info "Found Target Group: $TG_ARN"
        fi
        
        # Delete Load Balancer
        log_info "Deleting Load Balancer..."
        aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region $AWS_REGION || true
        
        # Delete Target Group
        if [ "$TG_ARN" != "None" ] && [ ! -z "$TG_ARN" ]; then
            log_info "Deleting Target Group..."
            aws elbv2 delete-target-group --target-group-arn $TG_ARN --region $AWS_REGION || true
        fi
        
        log_success "Load Balancer resources cleaned up"
    else
        log_info "Load Balancer not found"
    fi
}

# Cleanup ECR resources
cleanup_ecr() {
    log_info "Cleaning up ECR resources..."
    
    REPO_NAME="${PROJECT_NAME}-${ENVIRONMENT}-ml-model"
    
    # Check if repository exists
    if aws ecr describe-repositories --repository-names $REPO_NAME --region $AWS_REGION &> /dev/null; then
        log_info "Found ECR repository: $REPO_NAME"
        
        # Delete all images in the repository
        log_info "Deleting all images in repository..."
        aws ecr list-images --repository-name $REPO_NAME --region $AWS_REGION --query 'imageIds[*]' --output json | \
        aws ecr batch-delete-image --repository-name $REPO_NAME --region $AWS_REGION --image-ids file:///dev/stdin || true
        
        # Delete the repository
        log_info "Deleting ECR repository..."
        aws ecr delete-repository --repository-name $REPO_NAME --force --region $AWS_REGION || true
        
        log_success "ECR resources cleaned up"
    else
        log_info "ECR repository not found"
    fi
}

# Cleanup CloudWatch resources
cleanup_cloudwatch() {
    log_info "Cleaning up CloudWatch resources..."
    
    LOG_GROUP_NAME="/ecs/${PROJECT_NAME}-${ENVIRONMENT}"
    
    # Delete log group
    if aws logs describe-log-groups --log-group-name-prefix $LOG_GROUP_NAME --region $AWS_REGION --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q $LOG_GROUP_NAME; then
        log_info "Found CloudWatch Log Group: $LOG_GROUP_NAME"
        aws logs delete-log-group --log-group-name $LOG_GROUP_NAME --region $AWS_REGION || true
        log_success "CloudWatch Log Group deleted"
    else
        log_info "CloudWatch Log Group not found"
    fi
}

# Cleanup IAM resources
cleanup_iam() {
    log_info "Cleaning up IAM resources..."
    
    # IAM Role names
    EXECUTION_ROLE="${PROJECT_NAME}-${ENVIRONMENT}-ecs-execution-role"
    TASK_ROLE="${PROJECT_NAME}-${ENVIRONMENT}-ecs-task-role"
    
    # Delete IAM Role Policies first
    log_info "Deleting IAM Role Policies..."
    aws iam delete-role-policy --role-name $EXECUTION_ROLE --policy-name "${PROJECT_NAME}-${ENVIRONMENT}-ecs-execution-policy" || true
    aws iam delete-role-policy --role-name $TASK_ROLE --policy-name "${PROJECT_NAME}-${ENVIRONMENT}-ecs-task-policy" || true
    
    # Delete IAM Roles
    log_info "Deleting IAM Roles..."
    aws iam delete-role --role-name $EXECUTION_ROLE || true
    aws iam delete-role --role-name $TASK_ROLE || true
    
    log_success "IAM resources cleaned up"
}

# Cleanup VPC resources using Terraform
cleanup_vpc_terraform() {
    log_info "Cleaning up VPC resources using Terraform..."
    
    if [ -d "infrastructure" ]; then
        cd infrastructure
        
        # Set Terraform environment variables for automation
        export TF_IN_AUTOMATION=true
        export TF_INPUT=false
        
        # Initialize Terraform
        terraform init -upgrade || true
        
        # Destroy infrastructure
        log_info "Using Terraform to destroy infrastructure..."
        terraform destroy -auto-approve -var="aws_region=$AWS_REGION" -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" || true
        
        cd ..
        log_success "VPC and infrastructure resources cleaned up"
    else
        log_warning "Infrastructure directory not found, skipping Terraform cleanup"
    fi
}

# Cleanup VPC resources manually (fallback)
cleanup_vpc_manual() {
    log_info "Cleaning up VPC resources manually..."
    
    # Get the VPC ID
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=$PROJECT_NAME" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")
    
    if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
        log_info "No VPC found with Project=$PROJECT_NAME tag."
        return 0
    fi
    
    log_info "Found VPC: $VPC_ID"
    
    # Delete NAT Gateways and release Elastic IPs
    log_info "Deleting NAT Gateways..."
    NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text 2>/dev/null || echo "")
    if [ ! -z "$NAT_GATEWAYS" ] && [ "$NAT_GATEWAYS" != "None" ]; then
        for nat_gw in $NAT_GATEWAYS; do
            log_info "Deleting NAT Gateway: $nat_gw"
            aws ec2 delete-nat-gateway --nat-gateway-id "$nat_gw" || true
        done
        log_info "Waiting for NAT Gateways to be deleted..."
        sleep 30
    fi
    
    # Release Elastic IPs
    log_info "Releasing Elastic IPs..."
    ELASTIC_IPS=$(aws ec2 describe-addresses --query "Addresses[?Tags[?Key==\`Project\` && Value==\`$PROJECT_NAME\`]].AllocationId" --output text 2>/dev/null || echo "")
    if [ ! -z "$ELASTIC_IPS" ] && [ "$ELASTIC_IPS" != "None" ]; then
        for eip in $ELASTIC_IPS; do
            log_info "Releasing Elastic IP: $eip"
            aws ec2 release-address --allocation-id "$eip" || true
        done
    fi
    
    # Delete Internet Gateway
    log_info "Deleting Internet Gateway..."
    IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null || echo "")
    if [ ! -z "$IGW_ID" ] && [ "$IGW_ID" != "None" ]; then
        aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" || true
        aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" || true
    fi
    
    # Delete Route Tables (except main)
    log_info "Deleting Route Tables..."
    ROUTE_TABLES=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text 2>/dev/null || echo "")
    if [ ! -z "$ROUTE_TABLES" ] && [ "$ROUTE_TABLES" != "None" ]; then
        for rt in $ROUTE_TABLES; do
            aws ec2 delete-route-table --route-table-id "$rt" || true
        done
    fi
    
    # Delete Subnets
    log_info "Deleting Subnets..."
    SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")
    if [ ! -z "$SUBNETS" ] && [ "$SUBNETS" != "None" ]; then
        for subnet in $SUBNETS; do
            aws ec2 delete-subnet --subnet-id "$subnet" || true
        done
    fi
    
    # Delete Security Groups (except default)
    log_info "Deleting Security Groups..."
    SECURITY_GROUPS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null || echo "")
    if [ ! -z "$SECURITY_GROUPS" ] && [ "$SECURITY_GROUPS" != "None" ]; then
        for sg in $SECURITY_GROUPS; do
            aws ec2 delete-security-group --group-id "$sg" || true
        done
    fi
    
    # Finally delete the VPC
    log_info "Deleting VPC: $VPC_ID"
    aws ec2 delete-vpc --vpc-id "$VPC_ID" || true
    
    log_success "VPC resources cleaned up manually"
}

# Main cleanup function
main() {
    log_info "Starting complete AWS resource cleanup for GitHub Actions..."
    log_warning "This will destroy ALL resources created by this project!"
    echo ""
    
    check_aws_credentials
    
    # Cleanup in reverse dependency order
    cleanup_ecs
    cleanup_load_balancer
    cleanup_ecr
    cleanup_cloudwatch
    cleanup_iam
    
    # Try Terraform cleanup first, then manual cleanup as fallback
    cleanup_vpc_terraform
    cleanup_vpc_manual
    
    log_success "All AWS resources have been cleaned up!"
    log_info "Next GitHub Actions run should have no conflicts."
}

# Run main function
main "$@"
