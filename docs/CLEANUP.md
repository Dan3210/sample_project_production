# Infrastructure Cleanup Guide

This document describes how to clean up AWS infrastructure resources created by this project.

## Automatic Cleanup

### GitHub Actions Cleanup Job

The main deployment workflow (`deploy.yml`) includes an automatic cleanup job that runs after the build and deployment steps complete successfully. This ensures that each deployment starts with a clean slate.

**Key Features:**
- Runs automatically after successful deployment
- Deletes all AWS resources (ECS, ECR, Load Balancer, VPC, IAM roles, etc.)
- Prevents conflicts in subsequent deployments
- Includes verification steps to confirm cleanup completion

**Trigger:** Runs automatically on `main` branch deployments

## Manual Cleanup

### Manual Cleanup Workflow

For emergency cleanup or when you need to clean up specific environments, use the manual cleanup workflow.

**How to trigger:**
1. Go to the GitHub Actions tab in your repository
2. Select "Manual Infrastructure Cleanup" workflow
3. Click "Run workflow"
4. Select the environment (dev, staging, prod)
5. Type `DELETE` in the confirmation field
6. Click "Run workflow"

**Safety Features:**
- Requires explicit confirmation by typing "DELETE"
- Shows clear warnings about what will be deleted
- Includes comprehensive verification steps

### Command Line Cleanup Scripts

For local development or when GitHub Actions is not available, use the cleanup scripts in the `scripts/` directory.

#### Complete Cleanup Script
```bash
# GitHub Actions compatible script
./scripts/cleanup-github-actions.sh
```

#### Individual Cleanup Scripts
```bash
# Clean up all resources
./scripts/cleanup-all.sh

# Clean up remaining resources (VPC, etc.)
./scripts/cleanup-remaining-resources.sh

# Clean up infrastructure using Terraform
./scripts/cleanup-infrastructure.sh
```

## What Gets Cleaned Up

The cleanup process removes the following AWS resources:

### Application Resources
- **ECS Cluster and Service** - Container orchestration
- **ECS Task Definitions** - Container configurations
- **Application Load Balancer** - Traffic distribution
- **Target Groups** - Load balancer targets
- **ECR Repository** - Container image storage
- **CloudWatch Log Groups** - Application logs

### Infrastructure Resources
- **VPC** - Virtual private cloud
- **Subnets** - Network segments
- **Internet Gateway** - Internet connectivity
- **NAT Gateways** - Outbound internet for private subnets
- **Elastic IPs** - Static IP addresses
- **Route Tables** - Network routing rules
- **Security Groups** - Firewall rules

### IAM Resources
- **ECS Execution Role** - Container runtime permissions
- **ECS Task Role** - Application permissions
- **IAM Role Policies** - Associated policies

## Environment Variables

The cleanup scripts support the following environment variables:

```bash
export PROJECT_NAME="ml-devops"        # Default: ml-devops
export ENVIRONMENT="dev"               # Default: dev
export AWS_REGION="us-east-2"         # Default: us-east-2
```

## Safety Considerations

### Automatic Cleanup
- Only runs on successful deployments to prevent cleanup of failed deployments
- Uses `if: always()` to ensure cleanup runs even if previous steps fail
- Includes comprehensive verification steps

### Manual Cleanup
- Requires explicit confirmation by typing "DELETE"
- Shows detailed warnings about what will be deleted
- Supports environment-specific cleanup

### Error Handling
- All cleanup operations use `|| true` to prevent script failure
- Continues cleanup even if individual resources fail to delete
- Provides detailed logging of success/failure for each resource

## Troubleshooting

### Common Issues

**1. Resources Still Exist After Cleanup**
- Check AWS console to verify resources are actually deleted
- Some resources may take time to be fully removed
- Run verification steps to see which resources remain

**2. Permission Errors**
- Ensure AWS credentials have sufficient permissions
- Check that the IAM user/role has delete permissions for all resource types

**3. VPC Cleanup Failures**
- VPCs can be stubborn due to dependencies
- Try running the manual VPC cleanup script: `./scripts/force-delete-vpcs.sh`
- Check for any remaining network interfaces or dependencies

### Verification Commands

After cleanup, verify resources are deleted:

```bash
# Check ECS cluster
aws ecs describe-clusters --clusters ml-devops-dev-cluster --region us-east-2

# Check ECR repository
aws ecs describe-repositories --repository-names ml-devops-dev-ml-model --region us-east-2

# Check Load Balancer
aws elbv2 describe-load-balancers --names ml-devops-dev-alb --region us-east-2

# Check VPCs
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=ml-devops" --region us-east-2

# Check IAM roles
aws iam get-role --role-name ml-devops-dev-ecs-execution-role
aws iam get-role --role-name ml-devops-dev-ecs-task-role
```

## Best Practices

1. **Always verify cleanup completion** using the verification steps
2. **Use manual cleanup for testing** before relying on automatic cleanup
3. **Monitor AWS costs** after cleanup to ensure all resources are removed
4. **Keep backup of important data** before running cleanup
5. **Test cleanup scripts** in a non-production environment first

## Support

If you encounter issues with the cleanup process:

1. Check the GitHub Actions logs for detailed error messages
2. Run the verification commands to identify remaining resources
3. Use the individual cleanup scripts for targeted cleanup
4. Check AWS CloudTrail for detailed API call logs
