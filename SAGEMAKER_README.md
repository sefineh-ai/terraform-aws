# AWS SageMaker Model Deployment with Terraform

This configuration deploys a machine learning model to AWS SageMaker using Terraform, providing a production-ready infrastructure for model serving.

## Overview

The Terraform configuration creates:
- **IAM Role**: Execution role with SageMaker permissions
- **SageMaker Model**: Containerized model with inference code
- **Endpoint Configuration**: Defines how the model will be served
- **SageMaker Endpoint**: Live endpoint for model inference

## Prerequisites

1. **AWS Account**: With appropriate permissions for SageMaker, IAM, and S3
2. **Model Artifacts**: Your trained model packaged and uploaded to S3
3. **Inference Code**: Python script for model inference (e.g., `inference.py`)
4. **Docker Image**: Compatible inference container image

## Model Preparation

### 1. Package Your Model

Your model should be packaged as a `.tar.gz` file containing:
```
model.tar.gz
├── model/           # Your model files
│   ├── model.pkl
│   └── ...
├── inference.py     # Inference script
└── requirements.txt # Python dependencies
```

### 2. Upload to S3

```bash
aws s3 cp model.tar.gz s3://your-bucket/path/to/model.tar.gz
```

### 3. Inference Script Example

Create `inference.py` for your model:

```python
import json
import pickle
import os
from sagemaker_inference import content_types, decoder, default_inference_handler, encoder
from sagemaker_inference import errors

def model_fn(model_dir):
    """Load the model from disk"""
    model_path = os.path.join(model_dir, 'model.pkl')
    with open(model_path, 'rb') as f:
        model = pickle.load(f)
    return model

def input_fn(input_data, content_type):
    """Parse input data payload"""
    if content_type == content_types.JSON:
        input_data = json.loads(input_data)
    return input_data

def predict_fn(input_data, model):
    """Inference request"""
    return model.predict(input_data)

def output_fn(prediction, accept):
    """Format prediction output"""
    if accept == content_types.JSON:
        return json.dumps(prediction.tolist())
    return prediction
```

## Configuration

### 1. Copy and Customize Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific values:

```hcl
model_name = "my-custom-model"
model_data_url = "s3://my-bucket/my-model.tar.gz"
inference_image = "763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference:1.12.1-cpu-py38"
instance_type = "ml.t3.medium"
```

### 2. Supported Container Images

| Framework | Image URI |
|-----------|-----------|
| PyTorch | `763104351884.dkr.ecr.us-east-1.amazonaws.com/pytorch-inference:1.12.1-cpu-py38` |
| TensorFlow | `763104351884.dkr.ecr.us-east-1.amazonaws.com/tensorflow-inference:2.8.0-cpu` |
| Scikit-learn | `246618743249.dkr.ecr.us-west-2.amazonaws.com/sagemaker-scikit-learn:0.23-1-cpu-py3` |
| XGBoost | `246618743249.dkr.ecr.us-west-2.amazonaws.com/sagemaker-xgboost:1.5-1` |

### 3. Instance Types

Choose based on your model's requirements:

| Type | Use Case | Cost |
|------|----------|------|
| `ml.t3.medium` | Development/Testing | Low |
| `ml.m5.large` | Production (CPU) | Medium |
| `ml.c5.large` | Production (CPU optimized) | Medium |
| `ml.g4dn.xlarge` | Production (GPU) | High |

## Deployment

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Plan Deployment

```bash
terraform plan
```

### 3. Deploy

```bash
terraform apply
```

### 4. Verify Deployment

```bash
aws sagemaker describe-endpoint --endpoint-name $(terraform output -raw sagemaker_endpoint_name)
```

## Usage

### Invoke the Endpoint

```python
import boto3
import json

runtime = boto3.client('sagemaker-runtime')

# Prepare your input data
input_data = {"features": [1, 2, 3, 4]}

# Invoke the endpoint
response = runtime.invoke_endpoint(
    EndpointName='my-ml-endpoint',
    ContentType='application/json',
    Body=json.dumps(input_data)
)

# Parse the response
result = json.loads(response['Body'].read().decode())
print(result)
```

### Using AWS CLI

```bash
aws sagemaker-runtime invoke-endpoint \
    --endpoint-name my-ml-endpoint \
    --content-type application/json \
    --body '{"features": [1, 2, 3, 4]}' \
    response.json
```

## Monitoring and Scaling

### Auto Scaling

Add auto scaling configuration:

```hcl
resource "aws_appautoscaling_target" "sagemaker_target" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "endpoint/${aws_sagemaker_endpoint.endpoint.name}/variant/default"
  scalable_dimension = "sagemaker:variant:DesiredInstanceCount"
  service_namespace  = "sagemaker"
}

resource "aws_appautoscaling_policy" "sagemaker_policy" {
  name               = "sagemaker-autoscaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.sagemaker_target.resource_id
  scalable_dimension = aws_appautoscaling_target.sagemaker_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.sagemaker_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "SageMakerVariantInvocationsPerInstance"
    }
    target_value = 100.0
  }
}
```

### CloudWatch Monitoring

Monitor your endpoint with CloudWatch metrics:
- `Invocations`: Number of inference requests
- `ModelLatency`: Time taken for inference
- `OverheadLatency`: Time spent in SageMaker overhead
- `Invocation4XXErrors`: Client errors
- `Invocation5XXErrors`: Server errors

## Cost Optimization

1. **Use Spot Instances**: For non-critical workloads
2. **Right-size Instances**: Start with smaller instances and scale up
3. **Auto Scaling**: Scale down during low traffic
4. **Delete Unused Endpoints**: Endpoints incur costs even when idle

## Security Best Practices

1. **VPC Configuration**: Deploy in a private subnet
2. **IAM Roles**: Use least privilege principle
3. **Data Encryption**: Enable encryption at rest and in transit
4. **Network Security**: Use security groups to restrict access

## Troubleshooting

### Common Issues

1. **Model Loading Errors**: Check S3 path and file format
2. **Inference Errors**: Verify inference script and dependencies
3. **Permission Errors**: Ensure IAM role has necessary permissions
4. **Timeout Errors**: Increase instance size or optimize model

### Debugging

```bash
# Check endpoint status
aws sagemaker describe-endpoint --endpoint-name my-ml-endpoint

# View CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix /aws/sagemaker/Endpoints/my-ml-endpoint
```

## Cleanup

To avoid ongoing costs, destroy the infrastructure:

```bash
terraform destroy
```

## Outputs

After deployment, you'll get:
- `sagemaker_endpoint_name`: Name of the deployed endpoint
- `sagemaker_endpoint_arn`: ARN of the endpoint
- `sagemaker_model_name`: Name of the model

Use these outputs to integrate with your applications or CI/CD pipelines. 