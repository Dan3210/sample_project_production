# AWS ML DevOps Project Makefile

.PHONY: help install test lint format build deploy clean

# Default target
help:
	@echo "AWS ML DevOps Project"
	@echo "===================="
	@echo ""
	@echo "Available targets:"
	@echo "  install     - Install Python dependencies"
	@echo "  test        - Run tests"
	@echo "  lint        - Run linting"
	@echo "  format      - Format code"
	@echo "  build       - Build Docker image"
	@echo "  deploy      - Deploy to AWS"
	@echo "  deploy-infra - Deploy infrastructure only"
	@echo "  deploy-app  - Deploy application only"
	@echo "  health      - Run health check"
	@echo "  clean       - Clean up local files"

# Variables
PROJECT_NAME = ml-devops
ENVIRONMENT = dev
AWS_REGION = us-east-2
ECR_REPO = $(PROJECT_NAME)-$(ENVIRONMENT)-ml-model

# Install dependencies
install:
	@echo "Installing Python dependencies..."
	cd ml-model && pip install -r requirements.txt

# Run tests
test:
	@echo "Running tests..."
	cd ml-model && python -m pytest tests/ -v

# Run linting
lint:
	@echo "Running linting..."
	cd ml-model && flake8 app.py
	cd ml-model && black --check app.py

# Format code
format:
	@echo "Formatting code..."
	cd ml-model && black app.py

# Build Docker image
build:
	@echo "Building Docker image..."
	cd ml-model && docker build -t $(ECR_REPO) .

# Deploy everything
deploy:
	@echo "Deploying to AWS..."
	./scripts/deploy.sh

# Deploy infrastructure only
deploy-infra:
	@echo "Deploying infrastructure..."
	./scripts/deploy.sh infrastructure

# Deploy application only
deploy-app:
	@echo "Deploying application..."
	./scripts/deploy.sh application

# Run health check
health:
	@echo "Running health check..."
	./scripts/deploy.sh health

# Show deployment info
info:
	@echo "Showing deployment info..."
	./scripts/deploy.sh info

# Clean up local files
clean:
	@echo "Cleaning up local files..."
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} +
	find . -type f -name ".coverage" -delete
	find . -type d -name ".pytest_cache" -exec rm -rf {} +


# Setup development environment
setup:
	@echo "Setting up development environment..."
	python3 -m venv venv
	. venv/bin/activate && pip install -r ml-model/requirements.txt
	@echo "Development environment ready!"
	@echo "Activate with: source venv/bin/activate"

# Run local development server
dev:
	@echo "Starting development server..."
	cd ml-model && python app.py

# Run tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	cd ml-model && python -m pytest tests/ --cov=app --cov-report=html

# Security scan
security-scan:
	@echo "Running security scan..."
	docker run --rm -v $(PWD):/app aquasec/trivy fs /app

# Check AWS credentials
check-aws:
	@echo "Checking AWS credentials..."
	aws sts get-caller-identity

# Get deployment status
status:
	@echo "Getting deployment status..."
	@echo "ECS Cluster:"
	aws ecs describe-clusters --clusters $(PROJECT_NAME)-$(ENVIRONMENT)-cluster
	@echo ""
	@echo "ECS Service:"
	aws ecs describe-services --cluster $(PROJECT_NAME)-$(ENVIRONMENT)-cluster --services $(PROJECT_NAME)-$(ENVIRONMENT)-service

# View logs
logs:
	@echo "Viewing application logs..."
	aws logs tail /ecs/$(PROJECT_NAME)-$(ENVIRONMENT) --follow

# Scale service
scale:
	@echo "Scaling ECS service to $(DESIRED_COUNT) tasks..."
	aws ecs update-service --cluster $(PROJECT_NAME)-$(ENVIRONMENT)-cluster --service $(PROJECT_NAME)-$(ENVIRONMENT)-service --desired-count $(DESIRED_COUNT)

# Update service
update:
	@echo "Updating ECS service..."
	aws ecs update-service --cluster $(PROJECT_NAME)-$(ENVIRONMENT)-cluster --service $(PROJECT_NAME)-$(ENVIRONMENT)-service --force-new-deployment
