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
- ✅ Blue/Green deployment strategy

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
