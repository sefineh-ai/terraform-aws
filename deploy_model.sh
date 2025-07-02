#!/bin/bash

# Model Deployment Script for AWS SageMaker
# This script automates the entire process from model preparation to deployment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
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

# Function to check AWS credentials
check_aws_credentials() {
    print_status "Checking AWS credentials..."
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    print_success "AWS credentials verified"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_deps=()
    
    if ! command_exists terraform; then
        missing_deps+=("terraform")
    fi
    
    if ! command_exists python3; then
        missing_deps+=("python3")
    fi
    
    if ! command_exists aws; then
        missing_deps+=("aws-cli")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_status "Please install the missing dependencies and try again."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Function to create terraform.tfvars
create_tfvars() {
    local bucket_name=$1
    local model_name=$2
    local model_url=$3
    
    print_status "Creating terraform.tfvars..."
    
    cat > terraform.tfvars << EOF
# SageMaker Model Deployment Configuration
model_name = "${model_name}"
endpoint_name = "${model_name}-endpoint"
endpoint_config_name = "${model_name}-config"

# Model artifacts location in S3
model_data_url = "${model_url}"

# S3 bucket configuration
s3_bucket_name = "${bucket_name}"

# Inference container image (PyTorch example)
inference_image = "763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference:1.12.1-cpu-py38"

# Instance configuration
instance_type = "ml.t3.medium"
initial_instance_count = 1

# Environment variables
environment = {
  SAGEMAKER_PROGRAM           = "inference.py"
  SAGEMAKER_SUBMIT_DIRECTORY  = "/opt/ml/model"
  SAGEMAKER_CONTAINER_LOG_LEVEL = "20"
}

# Tags
tags = {
  Environment = "production"
  Project     = "ml-deployment"
  Model       = "${model_name}"
}
EOF
    
    print_success "Created terraform.tfvars"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    print_status "Planning deployment..."
    terraform plan -out=tfplan
    
    # Ask for confirmation
    echo
    print_warning "Review the plan above. Do you want to proceed with deployment? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled"
        exit 0
    fi
    
    # Apply deployment
    print_status "Applying deployment..."
    terraform apply tfplan
    
    print_success "Infrastructure deployed successfully"
}

# Function to test the endpoint
test_endpoint() {
    local endpoint_name=$1
    
    print_status "Testing SageMaker endpoint..."
    
    # Get endpoint name from Terraform output
    local actual_endpoint_name
    actual_endpoint_name=$(terraform output -raw sagemaker_endpoint_name 2>/dev/null || echo "$endpoint_name")
    
    # Wait for endpoint to be in service
    print_status "Waiting for endpoint to be in service..."
    aws sagemaker wait endpoint-in-service --endpoint-name "$actual_endpoint_name"
    
    # Test with sample data
    print_status "Testing endpoint with sample data..."
    
    # Create test data
    cat > test_data.json << EOF
{
  "features": [1.0, 2.0, 3.0, 4.0]
}
EOF
    
    # Invoke endpoint
    aws sagemaker-runtime invoke-endpoint \
        --endpoint-name "$actual_endpoint_name" \
        --content-type application/json \
        --body file://test_data.json \
        response.json
    
    if [ -f response.json ]; then
        print_success "Endpoint test completed"
        print_status "Response:"
        cat response.json
        echo
        rm -f test_data.json response.json
    else
        print_error "Failed to test endpoint"
    fi
}

# Main script
main() {
    echo "🚀 SageMaker Model Deployment Script"
    echo "====================================="
    echo
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --model-dir)
                MODEL_DIR="$2"
                shift 2
                ;;
            --bucket-name)
                BUCKET_NAME="$2"
                shift 2
                ;;
            --model-name)
                MODEL_NAME="$2"
                shift 2
                ;;
            --requirements)
                REQUIREMENTS="$2"
                shift 2
                ;;
            --skip-model-prep)
                SKIP_MODEL_PREP=true
                shift
                ;;
            --test-endpoint)
                TEST_ENDPOINT=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  --model-dir DIR        Directory containing model files"
                echo "  --bucket-name NAME     S3 bucket name (must be globally unique)"
                echo "  --model-name NAME      Name for the model"
                echo "  --requirements PKGS    Space-separated list of Python packages"
                echo "  --skip-model-prep      Skip model preparation (use existing S3 model)"
                echo "  --test-endpoint        Test the endpoint after deployment"
                echo "  --help                 Show this help message"
                echo
                echo "Example:"
                echo "  $0 --model-dir ./my-model --bucket-name my-ml-bucket --model-name my-model --requirements scikit-learn numpy"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Validate required arguments
    if [ -z "$BUCKET_NAME" ] || [ -z "$MODEL_NAME" ]; then
        print_error "Missing required arguments"
        echo "Use --help for usage information"
        exit 1
    fi
    
    if [ "$SKIP_MODEL_PREP" != "true" ] && [ -z "$MODEL_DIR" ]; then
        print_error "Model directory is required unless --skip-model-prep is used"
        exit 1
    fi
    
    # Check prerequisites
    check_prerequisites
    check_aws_credentials
    
    # Step 1: Prepare and upload model (if not skipped)
    if [ "$SKIP_MODEL_PREP" != "true" ]; then
        print_status "Step 1: Preparing and uploading model..."
        
        # Prepare model package
        python3 prepare_model.py \
            --model-dir "$MODEL_DIR" \
            --bucket-name "$BUCKET_NAME" \
            --model-name "$MODEL_NAME" \
            ${REQUIREMENTS:+--requirements $REQUIREMENTS}
        
        MODEL_URL="s3://$BUCKET_NAME/models/$MODEL_NAME.tar.gz"
    else
        print_status "Skipping model preparation..."
        MODEL_URL="s3://$BUCKET_NAME/models/$MODEL_NAME.tar.gz"
    fi
    
    # Step 2: Create Terraform configuration
    print_status "Step 2: Creating Terraform configuration..."
    create_tfvars "$BUCKET_NAME" "$MODEL_NAME" "$MODEL_URL"
    
    # Step 3: Deploy infrastructure
    print_status "Step 3: Deploying infrastructure..."
    deploy_infrastructure
    
    # Step 4: Test endpoint (if requested)
    if [ "$TEST_ENDPOINT" = "true" ]; then
        print_status "Step 4: Testing endpoint..."
        test_endpoint "$MODEL_NAME-endpoint"
    fi
    
    # Final output
    echo
    print_success "🎉 Deployment completed successfully!"
    echo
    print_status "Next steps:"
    echo "  1. Your SageMaker endpoint is ready for inference"
    echo "  2. Use the endpoint name: $(terraform output -raw sagemaker_endpoint_name)"
    echo "  3. Monitor costs in AWS Console"
    echo "  4. To clean up: terraform destroy"
    echo
}

# Run main function with all arguments
main "$@" 