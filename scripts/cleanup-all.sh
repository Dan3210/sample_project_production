#!/bin/bash

# AWS ML DevOps Complete Cleanup Script
# This script destroys ALL AWS resources created by this project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="ml-devops"
ENVIRONMENT="dev"
AWS_REGION="us-east-2"

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
        log_error "AWS credentials not configured. Please run 'aws configure' first."
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

# Cleanup VPC resources (if created by this project)
cleanup_vpc() {
    log_info "Cleaning up VPC resources..."
    
    # This is more complex as VPC resources might be shared
    # We'll use Terraform to handle this safely
    if [ -d "infrastructure" ]; then
        cd infrastructure
        
        # Initialize Terraform
        terraform init -upgrade || true
        
        # Import existing resources and destroy
        log_info "Using Terraform to destroy infrastructure..."
        terraform destroy -auto-approve -var="aws_region=$AWS_REGION" -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" || true
        
        cd ..
        log_success "VPC and infrastructure resources cleaned up"
    else
        log_warning "Infrastructure directory not found, skipping Terraform cleanup"
    fi
}

# Main cleanup function
main() {
    log_info "Starting complete AWS resource cleanup..."
    log_warning "This will destroy ALL resources created by this project!"
    echo ""
    
    check_aws_credentials
    
    # Cleanup in reverse dependency order
    cleanup_ecs
    cleanup_load_balancer
    cleanup_ecr
    cleanup_cloudwatch
    cleanup_vpc
    
    log_success "All AWS resources have been cleaned up!"
    log_info "You may want to check the AWS console to verify all resources are deleted."
}

# Run main function
main "$@"

