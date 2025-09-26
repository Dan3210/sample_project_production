# AWS ML DevOps Project

A comprehensive DevOps project demonstrating infrastructure as code, CI/CD, and ML model deployment on AWS. This project deploys a **Sentiment Analysis API** that analyzes the emotional tone of text input using a keyword-based approach.

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
├── ml-model/               # Sentiment Analysis API
│   ├── app.py              # Flask API with sentiment analysis
│   ├── Dockerfile          # Container configuration
│   ├── requirements.txt    # Python dependencies
│   └── tests/              # Unit tests
├── .github/workflows/      # CI/CD Pipeline
│   └── deploy.yml
├── scripts/               # Deployment Scripts
│   └── deploy.sh          # Manual deployment script
└── docs/                  # Documentation
```

## Features

### 🚀 **ML Model Features**
- ✅ **Sentiment Analysis API** - Analyzes text sentiment (positive/negative/neutral)
- ✅ **Keyword-Based Model** - Fast, lightweight sentiment analysis
- ✅ **Batch Processing** - Analyze multiple texts at once
- ✅ **REST API** - Easy integration with any application
- ✅ **Input Validation** - Comprehensive error handling and validation

### 🏗️ **Infrastructure Features**
- ✅ Infrastructure as Code with Terraform
- ✅ Automated CI/CD with GitHub Actions
- ✅ Containerized ML model deployment
- ✅ Auto-scaling ECS Fargate service
- ✅ Application Load Balancer
- ✅ CloudWatch monitoring and logging
- ✅ VPC with public/private subnets
- ✅ Security groups and IAM roles
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

## 🧠 **ML Model API Usage**

### **Single Text Sentiment Analysis**
```bash
curl -X POST http://your-alb-dns/predict \
  -H "Content-Type: application/json" \
  -d '{"text": "This product is amazing and I love it!"}'
```

**Response:**
```json
{
  "prediction": {
    "sentiment": "positive",
    "confidence": 0.667,
    "positive_words": 2,
    "negative_words": 0
  },
  "input_text": "This product is amazing and I love it!",
  "model_version": "1.0.0"
}
```

### **Batch Sentiment Analysis**
```bash
curl -X POST http://your-alb-dns/batch-predict \
  -H "Content-Type: application/json" \
  -d '{"texts": ["Great product!", "Terrible service", "It'\''s okay"]}'
```

### **Health Check**
```bash
curl http://your-alb-dns/health
```

### **API Documentation**
```bash
curl http://your-alb-dns/
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

## 🔧 **Environment Configuration**

### **Required GitHub Secrets**
- `AWS_ACCESS_KEY_ID` - AWS access key for deployment
- `AWS_SECRET_ACCESS_KEY` - AWS secret key for deployment

### **Environment Variables**
- `AWS_REGION` - AWS region (default: us-east-2)
- `ENVIRONMENT` - Deployment environment (default: dev)
- `PROJECT_NAME` - Project name (default: ml-devops)

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
