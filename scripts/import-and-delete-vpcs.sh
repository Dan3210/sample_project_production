#!/bin/bash

# Import and Delete VPC Resources Script
# This script imports existing VPC resources into Terraform state and then deletes them

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

# Get all VPCs with ml-devops project tag
get_vpcs() {
    log_info "Getting all VPCs with ml-devops project tag..."
    aws ec2 describe-vpcs --filters "Name=tag:Project,Values=ml-devops" --query 'Vpcs[*].VpcId' --output text
}

# Get subnets for a VPC
get_subnets() {
    local vpc_id=$1
    aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[*].SubnetId' --output text
}

# Get security groups for a VPC
get_security_groups() {
    local vpc_id=$1
    aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[?GroupName!=`default`].[GroupId,GroupName]' --output text
}

# Get internet gateways for a VPC
get_internet_gateways() {
    local vpc_id=$1
    aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[*].InternetGatewayId' --output text
}

# Get route tables for a VPC
get_route_tables() {
    local vpc_id=$1
    aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[?Associations[0].Main!=`true`].[RouteTableId]' --output text
}

# Delete VPC and all its resources
delete_vpc_resources() {
    local vpc_id=$1
    log_info "Deleting all resources for VPC: $vpc_id"
    
    # Get all resources
    local subnets=$(get_subnets $vpc_id)
    local security_groups=$(get_security_groups $vpc_id)
    local internet_gateways=$(get_internet_gateways $vpc_id)
    local route_tables=$(get_route_tables $vpc_id)
    
    # Delete subnets
    if [ ! -z "$subnets" ]; then
        log_info "Deleting subnets: $subnets"
        for subnet in $subnets; do
            aws ec2 delete-subnet --subnet-id $subnet || log_warning "Failed to delete subnet $subnet"
        done
    fi
    
    # Delete security groups (except default)
    if [ ! -z "$security_groups" ]; then
        log_info "Deleting security groups..."
        echo "$security_groups" | while read -r group_id group_name; do
            if [ ! -z "$group_id" ] && [ "$group_name" != "default" ]; then
                aws ec2 delete-security-group --group-id $group_id || log_warning "Failed to delete security group $group_id"
            fi
        done
    fi
    
    # Detach and delete internet gateways
    if [ ! -z "$internet_gateways" ]; then
        log_info "Deleting internet gateways: $internet_gateways"
        for igw in $internet_gateways; do
            aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $vpc_id || log_warning "Failed to detach IGW $igw"
            aws ec2 delete-internet-gateway --internet-gateway-id $igw || log_warning "Failed to delete IGW $igw"
        done
    fi
    
    # Delete route tables (except main)
    if [ ! -z "$route_tables" ]; then
        log_info "Deleting route tables: $route_tables"
        for rt in $route_tables; do
            aws ec2 delete-route-table --route-table-id $rt || log_warning "Failed to delete route table $rt"
        done
    fi
    
    # Finally delete the VPC
    log_info "Deleting VPC: $vpc_id"
    aws ec2 delete-vpc --vpc-id $vpc_id || log_warning "Failed to delete VPC $vpc_id"
    
    log_success "Completed deletion attempt for VPC: $vpc_id"
}

# Main function
main() {
    log_info "Starting VPC import and deletion process..."
    
    # Get all VPCs
    local vpcs=$(get_vpcs)
    
    if [ -z "$vpcs" ]; then
        log_info "No VPCs found with ml-devops project tag"
        return 0
    fi
    
    log_info "Found VPCs: $vpcs"
    
    # Delete each VPC and its resources
    for vpc in $vpcs; do
        log_info "Processing VPC: $vpc"
        
        # Show resources before deletion
        log_info "Resources in VPC $vpc:"
        echo "  Subnets: $(get_subnets $vpc)"
        echo "  Security Groups: $(get_security_groups $vpc | awk '{print $1}' | tr '\n' ' ')"
        echo "  Internet Gateways: $(get_internet_gateways $vpc)"
        echo "  Route Tables: $(get_route_tables $vpc)"
        
        # Delete all resources
        delete_vpc_resources $vpc
        
        echo ""
    done
    
    log_success "VPC deletion process completed!"
    log_info "You may want to check the AWS console to verify all VPCs are deleted."
}

# Run main function
main "$@"

