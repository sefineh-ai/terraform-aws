# Terraform AWS EC2 Deployment

## Overview
This repository provides Terraform configurations to deploy a secure and minimal Ubuntu EC2 instance on AWS. It is designed for rapid prototyping, learning, and as a starting point for more complex AWS infrastructure projects.

## Architecture
- **Provider:** AWS (region: `eu-north-1`)
- **Resources:**
  - EC2 instance (Ubuntu 20.04 LTS, `t3.micro`)
  - Security Group allowing SSH (port 22) from all IPs (customizable)
  - Uses the default VPC in the selected region

## Features
- Automated provisioning of a tagged Ubuntu EC2 instance
- Public IP output for easy access
- Security group with SSH access (can be restricted for production)

## Prerequisites
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0.0
- AWS account and credentials configured (via environment variables or AWS CLI)
- An existing EC2 key pair in AWS (update `key_name` in `main.tf`)

## Setup & Usage
1. **Clone the repository:**
   ```bash
   git clone <repo-url>
   cd terraform-aws
   ```
2. **Initialize Terraform:**
   ```bash
   terraform init
   ```
3. **Review and customize variables:**
   - Update the `key_name` in `main.tf` to match your AWS EC2 key pair.
   - (Optional) Restrict the SSH CIDR block in `security_group.tf` for better security.
4. **Plan and apply the configuration:**
   ```bash
   terraform plan
   terraform apply
   ```
5. **Access your instance:**
   - The public IP will be displayed as an output after apply.
   - Connect via SSH:
     ```bash
     ssh -i <path-to-your-private-key> ubuntu@<public-ip>
     ```

## Security Notes
- **SSH Access:** By default, SSH is open to the world (`0.0.0.0/0`). For production, restrict this to trusted IPs only in `security_group.tf`.
- **Key Management:** Ensure your private key is kept secure and never committed to version control.

## Outputs
- `public_ip`: The public IP address of the deployed EC2 instance.

## Contributing
Contributions, issues, and feature requests are welcome! Please open an issue or submit a pull request.

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details. 