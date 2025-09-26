#!/bin/bash

# Script to import existing AWS resources into Terraform state
# This resolves the "EntityAlreadyExists" errors when resources already exist in AWS

set -e

echo "Importing existing IAM roles into Terraform state..."

# Change to infrastructure directory
cd "$(dirname "$0")/../infrastructure"

# Import ECS Execution Role
echo "Importing ECS Execution Role..."
terraform import aws_iam_role.ecs_execution_role ml-devops-dev-ecs-execution-role

# Import ECS Task Role  
echo "Importing ECS Task Role..."
terraform import aws_iam_role.ecs_task_role ml-devops-dev-ecs-task-role

# Import ECS Execution Role Policy
echo "Importing ECS Execution Role Policy..."
terraform import aws_iam_role_policy.ecs_execution_role_policy ml-devops-dev-ecs-execution-role:ml-devops-dev-ecs-execution-policy

# Import ECS Task Role Policy
echo "Importing ECS Task Role Policy..."
terraform import aws_iam_role_policy.ecs_task_role_policy ml-devops-dev-ecs-task-role:ml-devops-dev-ecs-task-policy

echo "Import completed successfully!"
echo "Running terraform plan to verify state..."

# Run terraform plan to verify everything is in sync
terraform plan

echo "All existing resources have been imported successfully!"
