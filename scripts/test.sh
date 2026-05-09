#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to run unit tests
run_unit_tests() {
    print_status "Running unit tests..."
    
    go test -v -race -coverprofile=coverage.out -covermode=atomic ./...
    
    if [ $? -eq 0 ]; then
        print_status "Unit tests passed"
    else
        print_error "Unit tests failed"
        exit 1
    fi
}

# Function to run integration tests
run_integration_tests() {
    print_status "Running integration tests..."
    
    # Start the application
    go run main.go &
    APP_PID=$!
    
    # Wait for application to start
    sleep 5
    
    # Test health endpoint
    if curl -f http://localhost:8080/health; then
        print_status "Health endpoint test passed"
    else
        print_error "Health endpoint test failed"
        kill $APP_PID
        exit 1
    fi
    
    # Test ready endpoint
    if curl -f http://localhost:8080/ready; then
        print_status "Ready endpoint test passed"
    else
        print_error "Ready endpoint test failed"
        kill $APP_PID
        exit 1
    fi
    
    # Test metrics endpoint
    if curl -f http://localhost:8080/metrics; then
        print_status "Metrics endpoint test passed"
    else
        print_error "Metrics endpoint test failed"
        kill $APP_PID
        exit 1
    fi
    
    # Test main endpoint
    if curl -f http://localhost:8080/; then
        print_status "Main endpoint test passed"
    else
        print_error "Main endpoint test failed"
        kill $APP_PID
        exit 1
    fi
    
    # Stop the application
    kill $APP_PID
    print_status "Integration tests passed"
}

# Function to run load tests
run_load_tests() {
    print_status "Running load tests..."
    
    if ! command_exists hey; then
        print_warning "hey is not installed, skipping load tests"
        return
    fi
    
    # Start the application
    go run main.go &
    APP_PID=$!
    
    # Wait for application to start
    sleep 5
    
    # Run load test
    hey -n 100 -c 10 http://localhost:8080/health
    
    if [ $? -eq 0 ]; then
        print_status "Load tests passed"
    else
        print_error "Load tests failed"
        kill $APP_PID
        exit 1
    fi
    
    # Stop the application
    kill $APP_PID
}

# Function to run security tests
run_security_tests() {
    print_status "Running security tests..."
    
    # Run gosec
    if command_exists gosec; then
        gosec ./...
        print_status "Security scan completed"
    else
        print_warning "gosec is not installed, skipping security scan"
    fi
    
    # Run static analysis
    if command_exists staticcheck; then
        staticcheck ./...
        print_status "Static analysis completed"
    else
        print_warning "staticcheck is not installed, skipping static analysis"
    fi
}

# Function to check code quality
check_code_quality() {
    print_status "Checking code quality..."
    
    # Format check
    if ! gofmt -l . | grep -q .; then
        print_status "Code formatting is correct"
    else
        print_error "Code formatting issues found"
        gofmt -l .
        exit 1
    fi
    
    # Vet check
    go vet ./...
    if [ $? -eq 0 ]; then
        print_status "go vet passed"
    else
        print_error "go vet failed"
        exit 1
    fi
    
    # Ineffassign check
    if command_exists ineffassign; then
        ineffassign ./...
        print_status "ineffassign check passed"
    else
        print_warning "ineffassign is not installed, skipping ineffassign check"
    fi
}

# Function to generate coverage report
generate_coverage_report() {
    print_status "Generating coverage report..."
    
    if [ -f coverage.out ]; then
        go tool cover -html=coverage.out -o coverage.html
        go tool cover -func=coverage.out
        
        COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | sed 's/%//')
        print_status "Total coverage: ${COVERAGE}%"
        
        # Check if coverage meets threshold
        THRESHOLD=80
        if (( $(echo "$COVERAGE >= $THRESHOLD" | bc -l) )); then
            print_status "Coverage threshold (${THRESHOLD}%) met"
        else
            print_warning "Coverage threshold (${THRESHOLD}%) not met"
        fi
    else
        print_error "Coverage file not found"
        exit 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  unit        Run unit tests only"
    echo "  integration  Run integration tests only"
    echo "  load        Run load tests only"
    echo "  security    Run security tests only"
    echo "  quality     Check code quality"
    echo "  coverage    Generate coverage report"
    echo "  all         Run all tests"
    echo ""
    echo "Examples:"
    echo "  $0 unit"
    echo "  $0 all"
}

# Main script logic
main() {
    case "${1:-all}" in
        unit)
            run_unit_tests
            ;;
        integration)
            run_integration_tests
            ;;
        load)
            run_load_tests
            ;;
        security)
            run_security_tests
            ;;
        quality)
            check_code_quality
            ;;
        coverage)
            generate_coverage_report
            ;;
        all)
            check_code_quality
            run_unit_tests
            run_integration_tests
            run_security_tests
            generate_coverage_report
            run_load_tests
            print_status "All tests completed successfully"
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
