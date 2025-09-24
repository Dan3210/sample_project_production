# AWS ML DevOps Project

A comprehensive DevOps project demonstrating infrastructure as code, CI/CD, and ML model deployment on AWS.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │───▶│  GitHub Actions │───▶│   AWS ECR       │
│                 │    │   CI/CD Pipeline│    │   Container     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CloudWatch    │◀───│   ECS Fargate   │◀───│   ALB           │
│   Monitoring    │    │   ML Service    │    │   Load Balancer │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Project Structure

```
├── infrastructure/          # Terraform IaC
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
├── ml-model/               # ML Model Code
│   ├── app.py
│   ├── Dockerfile
│   ├── requirements.txt
│   └── model/
├── .github/workflows/      # CI/CD Pipeline
│   └── deploy.yml
├── scripts/               # Deployment Scripts
└── docs/                  # Documentation
```

## Features

- ✅ Infrastructure as Code with Terraform
- ✅ Automated CI/CD with GitHub Actions
- ✅ Containerized ML model deployment
- ✅ Auto-scaling ECS Fargate service
- ✅ Application Load Balancer
- ✅ CloudWatch monitoring and logging
- ✅ VPC with public/private subnets
- ✅ Security groups and IAM roles
- ✅ Secrets management
- ✅ Rolling deployment strategy with zero-downtime updates

## Quick Start

1. **Prerequisites**
   ```bash
   # Install required tools
   terraform --version
   aws --version
   docker --version
   ```

2. **Configure AWS**
   ```bash
   aws configure
   ```

3. **Deploy Infrastructure**
   ```bash
   cd infrastructure
   terraform init
   terraform plan
   terraform apply
   ```

4. **Deploy ML Model**
   ```bash
   # Push to GitHub to trigger CI/CD
   git add .
   git commit -m "Initial deployment"
   git push origin main
   ```

## Deployment Strategy

This project uses a **rolling deployment** strategy with ECS Fargate:

- **Zero-downtime deployments**: New tasks are started before old ones are terminated
- **Health checks**: Automatic rollback if new deployment fails health checks
- **Gradual traffic shift**: Load balancer gradually shifts traffic to new tasks
- **Automatic scaling**: ECS handles task replacement during deployments

### Deployment Methods

1. **Automated CI/CD**: GitHub Actions triggers deployment on push to main branch
2. **Manual deployment**: Use `./scripts/deploy.sh` for manual deployments
3. **Infrastructure updates**: Terraform manages infrastructure changes

## Monitoring

- CloudWatch Dashboards
- Application Logs
- Performance Metrics
- Health Checks

## Security

- VPC with private subnets
- Security groups
- IAM roles with least privilege
- Secrets Manager for sensitive data
- HTTPS/TLS encryption
