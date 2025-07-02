# AWS SageMaker Model Deployment
# This configuration deploys a machine learning model to AWS SageMaker

# IAM Role for SageMaker
resource "aws_iam_role" "sagemaker_execution_role" {
  name = "sagemaker-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })
}

# Attach SageMaker execution policy
resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# SageMaker Model
resource "aws_sagemaker_model" "ml_model" {
  name               = var.model_name
  execution_role_arn = aws_iam_role.sagemaker_execution_role.arn

  primary_container {
    image = var.inference_image
    mode  = "SingleModel"
    
    model_data_url = var.model_data_url
    
    environment = var.environment
  }

  tags = merge(var.tags, {
    Name = var.model_name
  })
}

# SageMaker Endpoint Configuration
resource "aws_sagemaker_endpoint_configuration" "endpoint_config" {
  name = var.endpoint_config_name

  production_variants {
    variant_name           = "default"
    model_name            = aws_sagemaker_model.ml_model.name
    initial_instance_count = var.initial_instance_count
    instance_type         = var.instance_type
    initial_weight        = 1
  }

  tags = merge(var.tags, {
    Name = var.endpoint_config_name
  })
}

# SageMaker Endpoint
resource "aws_sagemaker_endpoint" "endpoint" {
  name                 = var.endpoint_name
  endpoint_config_name = aws_sagemaker_endpoint_configuration.endpoint_config.name

  tags = merge(var.tags, {
    Name = var.endpoint_name
  })
}

# Output the endpoint name and ARN
output "sagemaker_endpoint_name" {
  value       = aws_sagemaker_endpoint.endpoint.name
  description = "Name of the SageMaker endpoint"
}

output "sagemaker_endpoint_arn" {
  value       = aws_sagemaker_endpoint.endpoint.arn
  description = "ARN of the SageMaker endpoint"
}

output "sagemaker_model_name" {
  value       = aws_sagemaker_model.ml_model.name
  description = "Name of the SageMaker model"
} 