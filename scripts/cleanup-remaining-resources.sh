#!/bin/bash

# Script to clean up remaining AWS resources (VPC, subnets, Elastic IPs, etc.)
# This handles resources that weren't in the Terraform state

set -e

echo "=========================================="
echo "Cleaning up remaining AWS resources"
echo "=========================================="

# Check if AWS credentials are configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "Error: AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

echo "AWS credentials verified."

# Get the VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=ml-devops" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")

if [ -z "$VPC_ID" ] || [ "$VPC_ID" = "None" ]; then
    echo "No VPC found with Project=ml-devops tag. Nothing to clean up."
    exit 0
fi

echo "Found VPC: $VPC_ID"

# Function to safely delete resources
safe_delete() {
    local resource_type="$1"
    local resource_id="$2"
    local description="$3"
    
    if [ -z "$resource_id" ] || [ "$resource_id" = "None" ]; then
        echo "⚠ $description not found"
        return
    fi
    
    echo "Deleting $description: $resource_id"
    if eval "$4" 2>/dev/null; then
        echo "✓ Successfully deleted $description"
    else
        echo "⚠ Failed to delete $description (may already be deleted)"
    fi
}

echo ""
echo "Step 1: Deleting NAT Gateways and releasing Elastic IPs..."

# Get NAT Gateways
NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text 2>/dev/null || echo "")

if [ ! -z "$NAT_GATEWAYS" ] && [ "$NAT_GATEWAYS" != "None" ]; then
    for nat_gw in $NAT_GATEWAYS; do
        echo "Deleting NAT Gateway: $nat_gw"
        aws ec2 delete-nat-gateway --nat-gateway-id "$nat_gw" || echo "Failed to delete NAT Gateway $nat_gw"
    done
    echo "Waiting for NAT Gateways to be deleted..."
    sleep 30
fi

# Get and release Elastic IPs
echo "Releasing Elastic IPs..."
ELASTIC_IPS=$(aws ec2 describe-addresses --query 'Addresses[?Tags[?Key==`Project` && Value==`ml-devops`]].AllocationId' --output text 2>/dev/null || echo "")

if [ ! -z "$ELASTIC_IPS" ] && [ "$ELASTIC_IPS" != "None" ]; then
    for eip in $ELASTIC_IPS; do
        echo "Releasing Elastic IP: $eip"
        aws ec2 release-address --allocation-id "$eip" || echo "Failed to release Elastic IP $eip"
    done
fi

echo ""
echo "Step 2: Deleting Internet Gateway..."

# Get and delete Internet Gateway
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null || echo "")

if [ ! -z "$IGW_ID" ] && [ "$IGW_ID" != "None" ]; then
    echo "Detaching Internet Gateway: $IGW_ID"
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" || echo "Failed to detach IGW"
    
    echo "Deleting Internet Gateway: $IGW_ID"
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" || echo "Failed to delete IGW"
fi

echo ""
echo "Step 3: Deleting Route Tables..."

# Get and delete custom route tables (not the main one)
ROUTE_TABLES=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text 2>/dev/null || echo "")

if [ ! -z "$ROUTE_TABLES" ] && [ "$ROUTE_TABLES" != "None" ]; then
    for rt in $ROUTE_TABLES; do
        echo "Deleting Route Table: $rt"
        aws ec2 delete-route-table --route-table-id "$rt" || echo "Failed to delete Route Table $rt"
    done
fi

echo ""
echo "Step 4: Deleting Subnets..."

# Get and delete subnets
SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")

if [ ! -z "$SUBNETS" ] && [ "$SUBNETS" != "None" ]; then
    for subnet in $SUBNETS; do
        echo "Deleting Subnet: $subnet"
        aws ec2 delete-subnet --subnet-id "$subnet" || echo "Failed to delete Subnet $subnet"
    done
fi

echo ""
echo "Step 5: Deleting Security Groups..."

# Get and delete security groups (except default)
SECURITY_GROUPS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null || echo "")

if [ ! -z "$SECURITY_GROUPS" ] && [ "$SECURITY_GROUPS" != "None" ]; then
    for sg in $SECURITY_GROUPS; do
        echo "Deleting Security Group: $sg"
        aws ec2 delete-security-group --group-id "$sg" || echo "Failed to delete Security Group $sg"
    done
fi

echo ""
echo "Step 6: Deleting VPC..."

# Finally delete the VPC
echo "Deleting VPC: $VPC_ID"
if aws ec2 delete-vpc --vpc-id "$VPC_ID"; then
    echo "✓ Successfully deleted VPC"
else
    echo "⚠ Failed to delete VPC (may have dependencies)"
fi

echo ""
echo "Step 7: Cleaning up any remaining ECS resources..."

# Delete any remaining ECS services
ECS_SERVICES=$(aws ecs list-services --cluster ml-devops-dev-cluster --query 'serviceArns' --output text 2>/dev/null || echo "")
if [ ! -z "$ECS_SERVICES" ] && [ "$ECS_SERVICES" != "None" ]; then
    for service in $ECS_SERVICES; do
        echo "Deleting ECS Service: $service"
        aws ecs update-service --cluster ml-devops-dev-cluster --service "$service" --desired-count 0 || echo "Failed to scale down service"
        aws ecs delete-service --cluster ml-devops-dev-cluster --service "$service" || echo "Failed to delete service"
    done
fi

# Delete ECS cluster
echo "Deleting ECS Cluster: ml-devops-dev-cluster"
aws ecs delete-cluster --cluster ml-devops-dev-cluster || echo "ECS cluster not found or already deleted"

# Delete Load Balancer
ALB_ARN=$(aws elbv2 describe-load-balancers --names ml-devops-dev-alb --query 'LoadBalancers[0].LoadBalancerArn --output text 2>/dev/null || echo "")
if [ ! -z "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
    echo "Deleting Load Balancer: $ALB_ARN"
    aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" || echo "Failed to delete Load Balancer"
fi

# Delete Target Group
TG_ARN=$(aws elbv2 describe-target-groups --names ml-devops-dev-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "")
if [ ! -z "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
    echo "Deleting Target Group: $TG_ARN"
    aws elbv2 delete-target-group --target-group-arn "$TG_ARN" || echo "Failed to delete Target Group"
fi

# Delete ECR repository
echo "Deleting ECR Repository: ml-devops-dev-ml-model"
aws ecr delete-repository --repository-name ml-devops-dev-ml-model --force || echo "ECR repository not found"

# Delete CloudWatch Log Group
echo "Deleting CloudWatch Log Group: /ecs/ml-devops-dev"
aws logs delete-log-group --log-group-name /ecs/ml-devops-dev || echo "Log Group not found"

echo ""
echo "=========================================="
echo "Cleanup completed!"
echo "=========================================="
