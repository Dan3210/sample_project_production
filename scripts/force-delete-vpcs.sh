#!/bin/bash

# Force Delete VPC Resources Script
# This script forcefully deletes VPC resources by handling dependencies

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

# Force delete VPC and all its resources
force_delete_vpc() {
    local vpc_id=$1
    log_info "Force deleting VPC: $vpc_id"
    
    # Get all resources
    local subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[*].SubnetId' --output text 2>/dev/null || echo "")
    local security_groups=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null || echo "")
    local internet_gateways=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[*].InternetGatewayId' --output text 2>/dev/null || echo "")
    local route_tables=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text 2>/dev/null || echo "")
    local network_interfaces=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$vpc_id" --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text 2>/dev/null || echo "")
    
    log_info "Resources found:"
    log_info "  Subnets: $subnets"
    log_info "  Security Groups: $security_groups"
    log_info "  Internet Gateways: $internet_gateways"
    log_info "  Route Tables: $route_tables"
    log_info "  Network Interfaces: $network_interfaces"
    
    # Delete network interfaces first
    if [ ! -z "$network_interfaces" ]; then
        log_info "Deleting network interfaces..."
        for eni in $network_interfaces; do
            log_info "Deleting network interface: $eni"
            aws ec2 delete-network-interface --network-interface-id $eni || log_warning "Failed to delete ENI $eni"
        done
    fi
    
    # Delete subnets
    if [ ! -z "$subnets" ]; then
        log_info "Deleting subnets..."
        for subnet in $subnets; do
            log_info "Deleting subnet: $subnet"
            aws ec2 delete-subnet --subnet-id $subnet || log_warning "Failed to delete subnet $subnet"
        done
    fi
    
    # Delete route tables (except main)
    if [ ! -z "$route_tables" ]; then
        log_info "Deleting route tables..."
        for rt in $route_tables; do
            log_info "Deleting route table: $rt"
            aws ec2 delete-route-table --route-table-id $rt || log_warning "Failed to delete route table $rt"
        done
    fi
    
    # Detach and delete internet gateways
    if [ ! -z "$internet_gateways" ]; then
        log_info "Deleting internet gateways..."
        for igw in $internet_gateways; do
            log_info "Detaching internet gateway: $igw"
            aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $vpc_id || log_warning "Failed to detach IGW $igw"
            log_info "Deleting internet gateway: $igw"
            aws ec2 delete-internet-gateway --internet-gateway-id $igw || log_warning "Failed to delete IGW $igw"
        done
    fi
    
    # Delete security groups (except default)
    if [ ! -z "$security_groups" ]; then
        log_info "Deleting security groups..."
        for sg in $security_groups; do
            log_info "Deleting security group: $sg"
            aws ec2 delete-security-group --group-id $sg || log_warning "Failed to delete security group $sg"
        done
    fi
    
    # Finally delete the VPC
    log_info "Deleting VPC: $vpc_id"
    aws ec2 delete-vpc --vpc-id $vpc_id || log_warning "Failed to delete VPC $vpc_id"
    
    log_success "Completed force deletion attempt for VPC: $vpc_id"
}

# Get all VPCs with ml-devops project tag
get_vpcs() {
    aws ec2 describe-vpcs --filters "Name=tag:Project,Values=ml-devops" --query 'Vpcs[*].VpcId' --output text
}

# Main function
main() {
    log_info "Starting force VPC deletion process..."
    
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
        force_delete_vpc $vpc
        echo ""
    done
    
    log_success "Force VPC deletion process completed!"
    log_info "You may want to check the AWS console to verify all VPCs are deleted."
}

# Run main function
main "$@"

