provider "aws" {
  region = "eu-north-1"
}

resource "aws_instance" "ubuntu_server" {
  ami                    = "ami-01637463b2cbe7cb6"   # Ubuntu 20.04 LTS in eu-north-1
  instance_type          = "t3.micro"
  key_name               = "terraform-key-pair"        # Your SSH key pair name
  vpc_security_group_ids = [aws_security_group.ssh_access.id]

  tags = {
    Name = "MyUbuntuServer"
  }
}

output "public_ip" {
  value = aws_instance.ubuntu_server.public_ip
  description = "Public IP address of the EC2 instance"
}
