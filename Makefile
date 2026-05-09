.PHONY: help build test clean docker-build docker-run deploy-dev deploy-staging deploy-prod terraform-init terraform-plan terraform-apply lint security-scan coverage

# Default target
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Development targets
build: ## Build the Go application
	@echo "Building Go application..."
	go build -o bin/go-web-app .

run: ## Run the Go application locally
	@echo "Running Go application..."
	go run main.go

test: ## Run all tests
	@echo "Running tests..."
	./scripts/test.sh all

test-unit: ## Run unit tests only
	@echo "Running unit tests..."
	./scripts/test.sh unit

test-integration: ## Run integration tests only
	@echo "Running integration tests..."
	./scripts/test.sh integration

test-security: ## Run security tests only
	@echo "Running security tests..."
	./scripts/test.sh security

coverage: ## Generate coverage report
	@echo "Generating coverage report..."
	./scripts/test.sh coverage

# Docker targets
docker-build: ## Build Docker image
	@echo "Building Docker image..."
	docker build -t saas-go-web-app:latest .

docker-run: ## Run Docker container
	@echo "Running Docker container..."
	docker run --rm -p 8080:8080 saas-go-web-app:latest

docker-push: ## Push Docker image to registry
	@echo "Pushing Docker image..."
	docker tag saas-go-web-app:latest $(DOCKERHUB_USERNAME)/go-web-app:latest
	docker push $(DOCKERHUB_USERNAME)/go-web-app:latest

# Code quality targets
lint: ## Run linter
	@echo "Running linter..."
	golangci-lint run

format: ## Format Go code
	@echo "Formatting Go code..."
	go fmt ./...

vet: ## Run go vet
	@echo "Running go vet..."
	go vet ./...

security-scan: ## Run security scanning
	@echo "Running security scanning..."
	./scripts/test.sh security

# Terraform targets
terraform-init: ## Initialize Terraform
	@echo "Initializing Terraform..."
	cd terraform && terraform init

terraform-plan-dev: ## Plan Terraform for development
	@echo "Planning Terraform for development..."
	cd terraform && terraform plan -var-file=dev.tfvars

terraform-plan-staging: ## Plan Terraform for staging
	@echo "Planning Terraform for staging..."
	cd terraform && terraform plan -var-file=staging.tfvars

terraform-plan-prod: ## Plan Terraform for production
	@echo "Planning Terraform for production..."
	cd terraform && terraform plan -var-file=prod.tfvars

terraform-apply-dev: ## Apply Terraform for development
	@echo "Applying Terraform for development..."
	cd terraform && terraform apply -var-file=dev.tfvars -auto-approve

terraform-apply-staging: ## Apply Terraform for staging
	@echo "Applying Terraform for staging..."
	cd terraform && terraform apply -var-file=staging.tfvars -auto-approve

terraform-apply-prod: ## Apply Terraform for production
	@echo "Applying Terraform for production..."
	cd terraform && terraform apply -var-file=prod.tfvars -auto-approve

terraform-destroy-dev: ## Destroy Terraform for development
	@echo "Destroying Terraform for development..."
	cd terraform && terraform destroy -var-file=dev.tfvars -auto-approve

terraform-destroy-staging: ## Destroy Terraform for staging
	@echo "Destroying Terraform for staging..."
	cd terraform && terraform destroy -var-file=staging.tfvars -auto-approve

terraform-destroy-prod: ## Destroy Terraform for production
	@echo "Destroying Terraform for production..."
	cd terraform && terraform destroy -var-file=prod.tfvars -auto-approve

# Kubernetes/Helm targets
kube-config-dev: ## Update kubeconfig for development
	@echo "Updating kubeconfig for development..."
	aws eks update-kubeconfig --name saas-platform-eks-dev --region us-east-1

kube-config-staging: ## Update kubeconfig for staging
	@echo "Updating kubeconfig for staging..."
	aws eks update-kubeconfig --name saas-platform-eks-staging --region us-east-1

kube-config-prod: ## Update kubeconfig for production
	@echo "Updating kubeconfig for production..."
	aws eks update-kubeconfig --name saas-platform-eks-prod --region us-east-1

deploy-dev: ## Deploy to development environment
	@echo "Deploying to development..."
	./scripts/deploy.sh deploy dev

deploy-staging: ## Deploy to staging environment
	@echo "Deploying to staging..."
	./scripts/deploy.sh deploy staging

deploy-prod: ## Deploy to production environment
	@echo "Deploying to production..."
	./scripts/deploy.sh deploy prod

rollback-dev: ## Rollback development deployment
	@echo "Rolling back development..."
	./scripts/deploy.sh rollback dev

rollback-staging: ## Rollback staging deployment
	@echo "Rolling back staging..."
	./scripts/deploy.sh rollback staging

rollback-prod: ## Rollback production deployment
	@echo "Rolling back production..."
	./scripts/deploy.sh rollback prod

# Monitoring targets
monitoring-setup: ## Setup monitoring stack
	@echo "Setting up monitoring stack..."
	kubectl apply -f monitoring/prometheus.yaml
	kubectl apply -f monitoring/grafana.yaml

monitoring-delete: ## Delete monitoring stack
	@echo "Deleting monitoring stack..."
	kubectl delete -f monitoring/grafana.yaml --ignore-not-found
	kubectl delete -f monitoring/prometheus.yaml --ignore-not-found

# Utility targets
clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	rm -rf bin/
	rm -f coverage.out coverage.html
	go clean -cache

deps: ## Download dependencies
	@echo "Downloading dependencies..."
	go mod download
	go mod tidy

deps-update: ## Update dependencies
	@echo "Updating dependencies..."
	go get -u ./...
	go mod tidy

pre-commit: format vet lint test security-scan ## Run pre-commit checks
	@echo "Pre-commit checks completed"

ci: ## Run full CI pipeline locally
	@echo "Running full CI pipeline..."
	make format
	make vet
	make lint
	make test
	make security-scan
	make docker-build

# Quick deployment targets
quick-deploy-dev: terraform-apply-dev deploy-dev ## Quick deploy to development (infra + app)
quick-deploy-staging: terraform-apply-staging deploy-staging ## Quick deploy to staging (infra + app)
quick-deploy-prod: terraform-apply-prod deploy-prod ## Quick deploy to production (infra + app)

# Status targets
status-dev: ## Show deployment status for development
	@echo "Development deployment status..."
	kubectl get pods -n development -l app=saas-go-web-app

status-staging: ## Show deployment status for staging
	@echo "Staging deployment status..."
	kubectl get pods -n staging -l app=saas-go-web-app

status-prod: ## Show deployment status for production
	@echo "Production deployment status..."
	kubectl get pods -n production -l app=saas-go-web-app

logs-dev: ## Show logs for development
	@echo "Development logs..."
	kubectl logs -n development -l app=saas-go-web-app -f

logs-staging: ## Show logs for staging
	@echo "Staging logs..."
	kubectl logs -n staging -l app=saas-go-web-app -f

logs-prod: ## Show logs for production
	@echo "Production logs..."
	kubectl logs -n production -l app=saas-go-web-app -f

# Health check targets
health-dev: ## Check health of development deployment
	@echo "Checking development health..."
	./scripts/deploy.sh health dev

health-staging: ## Check health of staging deployment
	@echo "Checking staging health..."
	./scripts/deploy.sh health staging

health-prod: ## Check health of production deployment
	@echo "Checking production health..."
	./scripts/deploy.sh health prod
