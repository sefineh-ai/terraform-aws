# Variables for SageMaker Model Deployment

variable "model_name" {
  description = "Name of the SageMaker model"
  type        = string
  default     = "my-ml-model"
}

variable "endpoint_name" {
  description = "Name of the SageMaker endpoint"
  type        = string
  default     = "my-ml-endpoint"
}

variable "endpoint_config_name" {
  description = "Name of the SageMaker endpoint configuration"
  type        = string
  default     = "my-endpoint-config"
}

variable "model_data_url" {
  description = "S3 URL where the model artifacts are stored"
  type        = string
  default     = "s3://your-model-bucket/model.tar.gz"
}

variable "inference_image" {
  description = "Docker image for model inference"
  type        = string
  default     = "763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference:1.12.1-cpu-py38"
}

variable "instance_type" {
  description = "SageMaker instance type for the endpoint"
  type        = string
  default     = "ml.t3.medium"
}

variable "initial_instance_count" {
  description = "Initial number of instances for the endpoint"
  type        = number
  default     = 1
}

variable "environment" {
  description = "Environment variables for the model container"
  type        = map(string)
  default = {
    SAGEMAKER_PROGRAM           = "inference.py"
    SAGEMAKER_SUBMIT_DIRECTORY  = "/opt/ml/model"
    SAGEMAKER_CONTAINER_LOG_LEVEL = "20"
  }
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for ML artifacts (must be globally unique)"
  type        = string
  default     = "my-ml-artifacts-bucket"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "production"
    Project     = "ml-deployment"
  }
} 