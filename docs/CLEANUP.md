# Infrastructure Cleanup Guide

⚠️ **IMPORTANT**: This project does **NOT** include automatic cleanup functionality. Resources will persist between deployments to ensure stability and avoid accidental data loss.

## Manual Cleanup Options

Since automatic cleanup has been removed for safety reasons, you have the following options for manual cleanup:

### 1. **Terraform Destroy**
The most reliable way to clean up infrastructure is using Terraform:

```bash
cd infrastructure
terraform destroy
```

This will remove all infrastructure managed by Terraform, including:
- ECS Cluster and Service
- Application Load Balancer
- ECR Repository
- VPC and networking components
- IAM roles and policies
- CloudWatch resources

### 2. **AWS Console**
Manually delete resources through the AWS Console:
- Navigate to each AWS service (ECS, ECR, VPC, etc.)
- Delete resources individually
- **Note**: Be careful to delete resources in the correct order to avoid dependency issues

### 3. **AWS CLI Commands**
Use AWS CLI to delete specific resources:

```bash
# Delete ECS service and cluster
aws ecs delete-service --cluster ml-devops-dev-cluster --service ml-devops-dev-service
aws ecs delete-cluster --cluster ml-devops-dev-cluster

# Delete ECR repository
aws ecr delete-repository --repository-name ml-devops-dev-ml-model --force

# Delete Load Balancer
aws elbv2 delete-load-balancer --load-balancer-arn <your-alb-arn>
```

## What Gets Cleaned Up

Manual cleanup removes the following AWS resources:

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

## Safety Considerations

### Why No Automatic Cleanup?
- **Data Protection**: Prevents accidental deletion of valuable resources
- **Cost Management**: Avoids unexpected cleanup that could disrupt services
- **Stability**: Ensures resources persist between deployments
- **Manual Control**: Gives you full control over when and what to delete

### Manual Cleanup Best Practices
- **Always backup important data** before cleanup
- **Test in non-production environments** first
- **Delete resources in correct order** to avoid dependency issues
- **Monitor AWS costs** after cleanup to ensure all resources are removed
- **Use Terraform destroy** for the most reliable cleanup

## Troubleshooting

### Common Issues

**1. Resources Still Exist After Cleanup**
- Check AWS console to verify resources are actually deleted
- Some resources may take time to be fully removed
- Run verification commands to see which resources remain

**2. Permission Errors**
- Ensure AWS credentials have sufficient permissions
- Check that the IAM user/role has delete permissions for all resource types

**3. VPC Cleanup Failures**
- VPCs can be stubborn due to dependencies
- Delete resources in this order: NAT Gateways → Internet Gateway → Subnets → Security Groups → VPC
- Check for any remaining network interfaces or dependencies

### Verification Commands

After cleanup, verify resources are deleted:

```bash
# Check ECS cluster
aws ecs describe-clusters --clusters ml-devops-dev-cluster --region us-east-2

# Check ECR repository
aws ecr describe-repositories --repository-names ml-devops-dev-ml-model --region us-east-2

# Check Load Balancer
aws elbv2 describe-load-balancers --names ml-devops-dev-alb --region us-east-2

# Check VPCs
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=ml-devops" --region us-east-2

# Check IAM roles
aws iam get-role --role-name ml-devops-dev-ecs-execution-role
aws iam get-role --role-name ml-devops-dev-ecs-task-role
```

## Best Practices

1. **Use Terraform destroy** for the most reliable cleanup
2. **Always backup important data** before cleanup
3. **Test cleanup in non-production environments** first
4. **Monitor AWS costs** after cleanup to ensure all resources are removed
5. **Delete resources in correct dependency order** to avoid errors

## Support

If you encounter issues with the cleanup process:

1. Check AWS CloudTrail for detailed API call logs
2. Run the verification commands to identify remaining resources
3. Use AWS Console for visual cleanup of stubborn resources
4. Contact AWS Support for complex cleanup scenarios
