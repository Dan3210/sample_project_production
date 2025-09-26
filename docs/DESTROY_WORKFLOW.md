# GitHub Actions Destroy Workflow

This document explains how to use the GitHub Actions workflow to destroy Terraform infrastructure.

## Overview

The destroy workflow (`destroy.yml`) provides a safe, automated way to destroy all infrastructure created by the main deployment workflow. It includes safety checks and verification steps to ensure proper cleanup.

## How to Use

### 1. Manual Trigger

1. Go to your GitHub repository
2. Navigate to **Actions** tab
3. Select **"Destroy ML Model Infrastructure"** workflow
4. Click **"Run workflow"**
5. Fill in the required parameters:
   - **Environment**: Choose `dev`, `staging`, or `prod`
   - **Confirm Destroy**: Type `DESTROY` to confirm
   - **Destroy ECR Images**: Check if you want to delete ECR repository images

### 2. Safety Features

- **Confirmation Required**: Must type `DESTROY` to proceed
- **Resource Listing**: Shows what will be destroyed before proceeding
- **Verification**: Checks that resources were actually destroyed
- **Cleanup**: Removes local Terraform files after destruction

### 3. What Gets Destroyed

The workflow destroys all infrastructure resources:

- ✅ **ECS Cluster and Service**
- ✅ **Application Load Balancer**
- ✅ **ECR Repository** (with optional image cleanup)
- ✅ **VPC and networking components**
- ✅ **IAM roles and policies**
- ✅ **CloudWatch resources**
- ✅ **Auto Scaling resources**

## Workflow Steps

### 1. Validation
- Verifies the confirmation input
- Cancels if `DESTROY` is not typed exactly

### 2. Infrastructure Destruction
- Initializes Terraform
- Lists resources to be destroyed
- Executes `terraform destroy`
- Optionally cleans up ECR images

### 3. Verification
- Checks that ECS cluster is destroyed
- Verifies ECR repository is removed
- Confirms ALB is deleted
- Validates VPC destruction

### 4. Cleanup
- Removes local Terraform state files
- Cleans up `.terraform` directory
- Removes lock files

## Usage Examples

### Destroy Development Environment
```
Environment: dev
Confirm Destroy: DESTROY
Destroy ECR Images: false
```

### Destroy Production Environment with ECR Cleanup
```
Environment: prod
Confirm Destroy: DESTROY
Destroy ECR Images: true
```

## Safety Considerations

⚠️ **Important Safety Notes:**

1. **Irreversible**: This action cannot be undone
2. **Data Loss**: All application data will be permanently deleted
3. **Costs**: Ensure you're not destroying production infrastructure accidentally
4. **Dependencies**: Some resources may have dependencies that prevent deletion

## Troubleshooting

### Common Issues

1. **Workflow Fails**: Check AWS credentials and permissions
2. **Resources Not Deleted**: Some resources may need manual cleanup
3. **Permission Errors**: Ensure GitHub Actions has proper AWS permissions

### Manual Cleanup

If the workflow fails, you can use the local destroy script:
```bash
./destroy-infrastructure.sh aws-commands
```

## Best Practices

1. **Test First**: Always test on development environment first
2. **Backup Data**: Ensure important data is backed up before destruction
3. **Verify Environment**: Double-check you're destroying the correct environment
4. **Monitor Costs**: Check AWS billing to ensure resources are actually deleted

## Integration with Local Scripts

The GitHub Actions destroy workflow complements the local destroy script:

- **GitHub Actions**: Automated, consistent, with proper state management
- **Local Script**: Manual control, AWS CLI commands, local state cleanup

Both approaches ensure complete infrastructure destruction while maintaining safety through confirmation requirements.
