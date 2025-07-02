#!/usr/bin/env python3
"""
Model Preparation Script for AWS SageMaker
This script helps prepare and package ML models for deployment to SageMaker.
"""

import os
import json
import tarfile
import argparse
import subprocess
import tempfile
import shutil
from pathlib import Path
import boto3
from botocore.exceptions import ClientError

def create_model_package(model_dir, output_file, requirements_file=None):
    """
    Create a SageMaker-compatible model package.
    
    Args:
        model_dir (str): Directory containing model files
        output_file (str): Output tar.gz file path
        requirements_file (str): Path to requirements.txt file
    """
    print(f"Creating model package: {output_file}")
    
    with tarfile.open(output_file, "w:gz") as tar:
        # Add model files
        if os.path.exists(model_dir):
            print(f"Adding model files from: {model_dir}")
            tar.add(model_dir, arcname="model")
        
        # Add requirements.txt if provided
        if requirements_file and os.path.exists(requirements_file):
            print(f"Adding requirements: {requirements_file}")
            tar.add(requirements_file, arcname="requirements.txt")
        
        # Add inference script
        inference_script = create_inference_script()
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(inference_script)
            temp_script = f.name
        
        try:
            tar.add(temp_script, arcname="inference.py")
        finally:
            os.unlink(temp_script)
    
    print(f"Model package created: {output_file}")

def create_inference_script():
    """
    Create a basic inference script for SageMaker.
    """
    return '''import json
import pickle
import os
import numpy as np
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
'''

def upload_to_s3(file_path, bucket_name, s3_key):
    """
    Upload file to S3 bucket.
    
    Args:
        file_path (str): Local file path
        bucket_name (str): S3 bucket name
        s3_key (str): S3 object key
    """
    print(f"Uploading {file_path} to s3://{bucket_name}/{s3_key}")
    
    s3_client = boto3.client('s3')
    
    try:
        s3_client.upload_file(file_path, bucket_name, s3_key)
        print(f"Successfully uploaded to s3://{bucket_name}/{s3_key}")
        return f"s3://{bucket_name}/{s3_key}"
    except ClientError as e:
        print(f"Error uploading to S3: {e}")
        return None

def create_requirements_file(packages):
    """
    Create a requirements.txt file.
    
    Args:
        packages (list): List of package names
    """
    requirements_file = "requirements.txt"
    with open(requirements_file, 'w') as f:
        for package in packages:
            f.write(f"{package}\n")
    print(f"Created requirements.txt with packages: {packages}")
    return requirements_file

def main():
    parser = argparse.ArgumentParser(description='Prepare ML model for SageMaker deployment')
    parser.add_argument('--model-dir', required=True, help='Directory containing model files')
    parser.add_argument('--bucket-name', required=True, help='S3 bucket name')
    parser.add_argument('--model-name', required=True, help='Name for the model')
    parser.add_argument('--requirements', nargs='+', help='Python packages to include')
    parser.add_argument('--output-dir', default='.', help='Output directory for model package')
    
    args = parser.parse_args()
    
    # Create output directory if it doesn't exist
    os.makedirs(args.output_dir, exist_ok=True)
    
    # Create model package
    model_package = os.path.join(args.output_dir, f"{args.model_name}.tar.gz")
    
    # Create requirements.txt if packages are specified
    requirements_file = None
    if args.requirements:
        requirements_file = create_requirements_file(args.requirements)
    
    # Create the model package
    create_model_package(args.model_dir, model_package, requirements_file)
    
    # Upload to S3
    s3_key = f"models/{args.model_name}.tar.gz"
    s3_url = upload_to_s3(model_package, args.bucket_name, s3_key)
    
    if s3_url:
        print(f"\n✅ Model successfully prepared and uploaded!")
        print(f"📦 Model package: {model_package}")
        print(f"☁️  S3 location: {s3_url}")
        print(f"\n📝 Update your terraform.tfvars with:")
        print(f"   model_data_url = \"{s3_url}\"")
    else:
        print("❌ Failed to upload model to S3")
    
    # Clean up requirements.txt if created
    if requirements_file and os.path.exists(requirements_file):
        os.remove(requirements_file)

if __name__ == "__main__":
    main() 