# Deployment Guide

This guide covers deploying the AWS ML DevOps project to production.

## Prerequisites

### Required Tools
- AWS CLI v2
- Terraform v1.6+
- Docker
- Git
- curl (for health checks)

### AWS Account Setup
1. Create an AWS account
2. Configure AWS CLI:
   ```bash
   aws configure
   ```
3. Ensure you have the following permissions:
   - ECS Full Access
   - ECR Full Access
   - VPC Full Access
   - IAM Full Access
   - CloudWatch Full Access
   - Application Load Balancer Full Access

## Deployment Options

### Option 1: Automated Deployment (Recommended)

Use the deployment script for a complete automated deployment:

```bash
# Full deployment
./scripts/deploy.sh

# Deploy only infrastructure
./scripts/deploy.sh infrastructure

# Deploy only application
./scripts/deploy.sh application

# Run health check
./scripts/deploy.sh health

# Show deployment info
./scripts/deploy.sh info
```

### Option 2: Manual Deployment

#### Step 1: Deploy Infrastructure

```bash
cd infrastructure
terraform init
terraform plan
terraform apply
```

#### Step 2: Build and Push Docker Image

```bash
# Get ECR repository URL
ECR_REPO_URL=$(cd infrastructure && terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin $ECR_REPO_URL

# Build and push image
cd ml-model
docker build -t ml-devops-dev-ml-model .
docker tag ml-devops-dev-ml-model:latest $ECR_REPO_URL:latest
docker push $ECR_REPO_URL:latest
```

#### Step 3: Deploy Application

```bash
# Get ECS cluster and service names
ECS_CLUSTER=$(cd infrastructure && terraform output -raw ecs_cluster_name)
ECS_SERVICE=$(cd infrastructure && terraform output -raw ecs_service_name)

# Force new deployment
aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --force-new-deployment

# Wait for deployment
aws ecs wait services-stable --cluster $ECS_CLUSTER --services $ECS_SERVICE
```

### Option 3: CI/CD Pipeline

1. Fork this repository to your GitHub account
2. Set up GitHub Secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
3. Push to main branch to trigger deployment

## Post-Deployment

### Verify Deployment

1. **Check Application Health**:
   ```bash
   ALB_DNS=$(cd infrastructure && terraform output -raw alb_dns_name)
   curl http://$ALB_DNS/health
   ```

2. **Test API Endpoints**:
   ```bash
   # Test sentiment prediction
   curl -X POST http://$ALB_DNS/predict \
     -H 'Content-Type: application/json' \
     -d '{"text": "This is a great product!"}'
   
   # Test batch prediction
   curl -X POST http://$ALB_DNS/batch-predict \
     -H 'Content-Type: application/json' \
     -d '{"texts": ["Great!", "Terrible!", "Okay."]}'
   ```

3. **Check CloudWatch Dashboard**:
   - Navigate to CloudWatch in AWS Console
   - Find the dashboard: `ml-devops-dev-dashboard`

### Monitoring

- **Application Logs**: CloudWatch Logs group `/ecs/ml-devops-dev`
- **Metrics**: CloudWatch Dashboard with ECS and ALB metrics
- **Health Checks**: ALB health checks on `/health` endpoint

## Troubleshooting

### Common Issues

1. **Terraform State Lock**:
   ```bash
   terraform force-unlock <LOCK_ID>
   ```

2. **ECS Service Not Starting**:
   - Check CloudWatch logs
   - Verify ECR image exists
   - Check security groups

3. **Health Check Failures**:
   - Verify application is listening on port 8080
   - Check security group rules
   - Review application logs

4. **Image Pull Errors**:
   - Verify ECR repository exists
   - Check IAM permissions for ECS task role
   - Ensure image is pushed to ECR

### Debug Commands

```bash
# Check ECS service status
aws ecs describe-services --cluster ml-devops-dev-cluster --services ml-devops-dev-service

# Check ECS task logs
aws logs get-log-events --log-group-name /ecs/ml-devops-dev --log-stream-name <STREAM_NAME>

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <TARGET_GROUP_ARN>
```

## Scaling

### Manual Scaling

```bash
# Scale ECS service
aws ecs update-service --cluster ml-devops-dev-cluster --service ml-devops-dev-service --desired-count 5
```

### Auto Scaling

The infrastructure includes auto-scaling policies:
- **CPU-based scaling**: Scales when CPU > 70%
- **Memory-based scaling**: Scales when Memory > 80%
- **Min capacity**: 1 task
- **Max capacity**: 10 tasks

## Security Considerations

1. **Network Security**:
   - VPC with public/private subnets
   - Security groups with least privilege
   - NAT Gateway for private subnet internet access

2. **IAM Security**:
   - Least privilege IAM roles
   - Separate execution and task roles
   - No hardcoded credentials

3. **Container Security**:
   - Non-root user in container
   - Health checks enabled
   - Resource limits set

## Cost Optimization

1. **Use Spot Instances**: Consider ECS with Spot capacity providers
2. **Right-size Resources**: Monitor and adjust CPU/memory allocation
3. **Auto Scaling**: Configure appropriate min/max capacity
4. **Log Retention**: Set appropriate CloudWatch log retention periods

## Cleanup

To destroy all resources:

```bash
cd infrastructure
terraform destroy
```

**Warning**: This will permanently delete all resources and data.
