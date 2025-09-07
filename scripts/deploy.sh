#!/bin/bash

# AWS ML DevOps Deployment Script
# This script deploys the infrastructure and application to AWS

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
TERRAFORM_DIR="infrastructure"
ML_MODEL_DIR="ml-model"

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

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    log_success "All prerequisites are met"
}

deploy_infrastructure() {
    log_info "Deploying infrastructure with Terraform..."
    
    cd $TERRAFORM_DIR
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    log_info "Planning Terraform deployment..."
    terraform plan -var="aws_region=$AWS_REGION" -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT"
    
    # Apply deployment
    log_info "Applying Terraform deployment..."
    terraform apply -auto-approve -var="aws_region=$AWS_REGION" -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT"
    
    # Get outputs
    ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
    ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)
    ALB_DNS=$(terraform output -raw alb_dns_name)
    
    log_success "Infrastructure deployed successfully"
    log_info "ECR Repository: $ECR_REPO_URL"
    log_info "ECS Cluster: $ECS_CLUSTER"
    log_info "ALB DNS: $ALB_DNS"
    
    cd ..
}

build_and_push_image() {
    log_info "Building and pushing Docker image..."
    
    # Get ECR repository URL
    ECR_REPO_URL=$(cd $TERRAFORM_DIR && terraform output -raw ecr_repository_url)
    
    # Login to ECR
    log_info "Logging in to ECR..."
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO_URL
    
    # Build image
    log_info "Building Docker image..."
    cd $ML_MODEL_DIR
    docker build -t $PROJECT_NAME-$ENVIRONMENT-ml-model .
    
    # Tag image
    docker tag $PROJECT_NAME-$ENVIRONMENT-ml-model:latest $ECR_REPO_URL:latest
    docker tag $PROJECT_NAME-$ENVIRONMENT-ml-model:latest $ECR_REPO_URL:$(date +%Y%m%d-%H%M%S)
    
    # Push image
    log_info "Pushing image to ECR..."
    docker push $ECR_REPO_URL:latest
    docker push $ECR_REPO_URL:$(date +%Y%m%d-%H%M%S)
    
    log_success "Docker image built and pushed successfully"
    cd ..
}

deploy_application() {
    log_info "Deploying application to ECS..."
    
    # Get ECS cluster name
    ECS_CLUSTER=$(cd $TERRAFORM_DIR && terraform output -raw ecs_cluster_name)
    ECS_SERVICE=$(cd $TERRAFORM_DIR && terraform output -raw ecs_service_name)
    
    # Force new deployment
    log_info "Forcing new ECS deployment..."
    aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --force-new-deployment
    
    # Wait for deployment to complete
    log_info "Waiting for deployment to complete..."
    aws ecs wait services-stable --cluster $ECS_CLUSTER --services $ECS_SERVICE
    
    log_success "Application deployed successfully"
}

run_health_check() {
    log_info "Running health check..."
    
    # Get ALB DNS name
    ALB_DNS=$(cd $TERRAFORM_DIR && terraform output -raw alb_dns_name)
    
    # Wait for service to be ready
    log_info "Waiting for service to be ready..."
    sleep 60
    
    # Test health endpoint
    HEALTH_URL="http://$ALB_DNS/health"
    log_info "Testing health endpoint: $HEALTH_URL"
    
    for i in {1..10}; do
        if curl -f $HEALTH_URL &> /dev/null; then
            log_success "Health check passed!"
            log_info "Application is accessible at: http://$ALB_DNS"
            return 0
        else
            log_warning "Health check failed, retrying in 30 seconds... (attempt $i/10)"
            sleep 30
        fi
    done
    
    log_error "Health check failed after 10 attempts"
    return 1
}

show_deployment_info() {
    log_info "Deployment Summary:"
    echo "=================="
    
    # Get outputs
    ALB_DNS=$(cd $TERRAFORM_DIR && terraform output -raw alb_dns_name)
    ECR_REPO_URL=$(cd $TERRAFORM_DIR && terraform output -raw ecr_repository_url)
    ECS_CLUSTER=$(cd $TERRAFORM_DIR && terraform output -raw ecs_cluster_name)
    CLOUDWATCH_DASHBOARD=$(cd $TERRAFORM_DIR && terraform output -raw cloudwatch_dashboard_url)
    
    echo "Application URL: http://$ALB_DNS"
    echo "Health Check URL: http://$ALB_DNS/health"
    echo "API Documentation: http://$ALB_DNS/"
    echo "ECR Repository: $ECR_REPO_URL"
    echo "ECS Cluster: $ECS_CLUSTER"
    echo "CloudWatch Dashboard: $CLOUDWATCH_DASHBOARD"
    echo ""
    echo "Test the API:"
    echo "curl -X POST http://$ALB_DNS/predict -H 'Content-Type: application/json' -d '{\"text\": \"This is great!\"}'"
}

# Main deployment function
main() {
    log_info "Starting AWS ML DevOps deployment..."
    echo "Project: $PROJECT_NAME"
    echo "Environment: $ENVIRONMENT"
    echo "Region: $AWS_REGION"
    echo ""
    
    check_prerequisites
    deploy_infrastructure
    build_and_push_image
    deploy_application
    
    if run_health_check; then
        show_deployment_info
        log_success "Deployment completed successfully!"
    else
        log_error "Deployment completed but health check failed"
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    "infrastructure")
        check_prerequisites
        deploy_infrastructure
        ;;
    "application")
        build_and_push_image
        deploy_application
        run_health_check
        ;;
    "health")
        run_health_check
        ;;
    "info")
        show_deployment_info
        ;;
    *)
        main
        ;;
esac
