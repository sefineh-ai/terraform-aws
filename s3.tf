# S3 Bucket for Model Artifacts and Data
# This configuration creates an S3 bucket for storing ML models and datasets

# S3 Bucket for ML artifacts
resource "aws_s3_bucket" "ml_bucket" {
  bucket = var.s3_bucket_name

  tags = merge(var.tags, {
    Name = var.s3_bucket_name
    Purpose = "ml-artifacts"
  })
}

# Enable versioning for model artifacts
resource "aws_s3_bucket_versioning" "ml_bucket_versioning" {
  bucket = aws_s3_bucket.ml_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "ml_bucket_encryption" {
  bucket = aws_s3_bucket.ml_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "ml_bucket_public_access_block" {
  bucket = aws_s3_bucket.ml_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy for SageMaker access
resource "aws_s3_bucket_policy" "ml_bucket_policy" {
  bucket = aws_s3_bucket.ml_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SageMakerAccess"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.ml_bucket.arn,
          "${aws_s3_bucket.ml_bucket.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Create folders for organizing ML artifacts
resource "aws_s3_object" "models_folder" {
  bucket = aws_s3_bucket.ml_bucket.id
  key    = "models/"
  source = "/dev/null"
}

resource "aws_s3_object" "data_folder" {
  bucket = aws_s3_bucket.ml_bucket.id
  key    = "data/"
  source = "/dev/null"
}

resource "aws_s3_object" "scripts_folder" {
  bucket = aws_s3_bucket.ml_bucket.id
  key    = "scripts/"
  source = "/dev/null"
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Outputs
output "s3_bucket_name" {
  value       = aws_s3_bucket.ml_bucket.bucket
  description = "Name of the S3 bucket for ML artifacts"
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.ml_bucket.arn
  description = "ARN of the S3 bucket for ML artifacts"
}

output "model_artifacts_path" {
  value       = "s3://${aws_s3_bucket.ml_bucket.bucket}/models/"
  description = "S3 path for model artifacts"
}

output "data_path" {
  value       = "s3://${aws_s3_bucket.ml_bucket.bucket}/data/"
  description = "S3 path for datasets"
} 