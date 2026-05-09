#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists kubectl; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    if ! command_exists helm; then
        print_error "helm is not installed"
        exit 1
    fi
    
    if ! command_exists terraform; then
        print_error "terraform is not installed"
        exit 1
    fi
    
    if ! command_exists aws; then
        print_error "aws cli is not installed"
        exit 1
    fi
    
    print_status "All prerequisites are installed"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    local env=$1
    print_status "Deploying infrastructure for environment: $env"
    
    cd terraform
    terraform init
    terraform plan -var-file="${env}.tfvars" -out="tfplan-${env}"
    terraform apply -auto-approve "tfplan-${env}"
    cd ..
    
    print_status "Infrastructure deployment completed for $env"
}

# Function to deploy application
deploy_application() {
    local env=$1
    local values_file="values-${env}.yaml"
    
    print_status "Deploying application to environment: $env"
    
    # Update kubeconfig
    aws eks update-kubeconfig --name "saas-platform-eks-${env}" --region us-east-1
    
    # Create namespace if it doesn't exist
    kubectl create namespace "$env" --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy secrets
    if [ -f "helm/go-web-app/${values_file}" ]; then
        helm upgrade --install go-web-app ./helm/go-web-app \
            --namespace "$env" \
            --values "helm/go-web-app/${values_file}" \
            --wait \
            --timeout=10m
        
        print_status "Application deployed successfully to $env"
    else
        print_error "Values file not found: helm/go-web-app/${values_file}"
        exit 1
    fi
}

# Function to run health checks
run_health_checks() {
    local env=$1
    
    print_status "Running health checks for environment: $env"
    
    # Wait for pods to be ready
    kubectl wait --for=condition=ready pod -l app=saas-go-web-app -n "$env" --timeout=300s
    
    # Get pod status
    kubectl get pods -n "$env" -l app=saas-go-web-app
    
    # Port forward and test endpoints
    kubectl port-forward -n "$env" svc/saas-go-web-app 8080:80 &
    PF_PID=$!
    
    sleep 10
    
    # Test health endpoint
    if curl -f http://localhost:8080/health; then
        print_status "Health check passed"
    else
        print_error "Health check failed"
        kill $PF_PID
        exit 1
    fi
    
    # Test ready endpoint
    if curl -f http://localhost:8080/ready; then
        print_status "Readiness check passed"
    else
        print_error "Readiness check failed"
        kill $PF_PID
        exit 1
    fi
    
    kill $PF_PID
    print_status "All health checks passed for $env"
}

# Function to rollback deployment
rollback_deployment() {
    local env=$1
    local revision=${2:-1}
    
    print_warning "Rolling back deployment in environment: $env to revision: $revision"
    
    aws eks update-kubeconfig --name "saas-platform-eks-${env}" --region us-east-1
    
    helm rollback go-web-app "$revision" -n "$env"
    
    print_status "Rollback completed for $env"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  deploy <env>           Deploy infrastructure and application"
    echo "  infra <env>            Deploy infrastructure only"
    echo "  app <env>              Deploy application only"
    echo "  health <env>           Run health checks"
    echo "  rollback <env> [rev]   Rollback to specific revision"
    echo ""
    echo "Environments:"
    echo "  dev, staging, prod"
    echo ""
    echo "Examples:"
    echo "  $0 deploy dev"
    echo "  $0 app staging"
    echo "  $0 rollback prod 2"
}

# Main script logic
main() {
    case "${1:-}" in
        deploy)
            if [ -z "${2:-}" ]; then
                print_error "Environment not specified"
                show_usage
                exit 1
            fi
            check_prerequisites
            deploy_infrastructure "$2"
            deploy_application "$2"
            run_health_checks "$2"
            ;;
        infra)
            if [ -z "${2:-}" ]; then
                print_error "Environment not specified"
                show_usage
                exit 1
            fi
            check_prerequisites
            deploy_infrastructure "$2"
            ;;
        app)
            if [ -z "${2:-}" ]; then
                print_error "Environment not specified"
                show_usage
                exit 1
            fi
            check_prerequisites
            deploy_application "$2"
            run_health_checks "$2"
            ;;
        health)
            if [ -z "${2:-}" ]; then
                print_error "Environment not specified"
                show_usage
                exit 1
            fi
            run_health_checks "$2"
            ;;
        rollback)
            if [ -z "${2:-}" ]; then
                print_error "Environment not specified"
                show_usage
                exit 1
            fi
            check_prerequisites
            rollback_deployment "$2" "${3:-1}"
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
