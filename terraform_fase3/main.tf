terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# VPC predeterminada de AWS
data "aws_vpc" "default" {
  default = true
}

# Subredes disponibles en la VPC predeterminada
data "aws_subnet" "default" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "us-east-1a"
  default_for_az    = true
}

# Ubuntu Server 24.04 LTS oficial de Canonical
data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Llave pública utilizada por Ansible para SSH
resource "aws_key_pair" "fase3" {
  key_name   = "fase3-vault-angel"
  public_key = file(pathexpand("~/.ssh/fase3-vault.pub"))
}

# Security Group del servidor Vault
resource "aws_security_group" "vault" {
  name        = "fase3-vault-sg-angel"
  description = "Acceso SSH y Vault para Fase III"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "fase3-vault-sg-angel"
  }
}

# SSH
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.vault.id
  description       = "SSH para administracion mediante Ansible"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

# Vault UI / API
resource "aws_vpc_security_group_ingress_rule" "vault" {
  security_group_id = aws_security_group.vault.id
  description       = "Vault UI y acceso desde GitHub Actions"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 8200
  to_port     = 8200
  ip_protocol = "tcp"
}

# Salida a Internet
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.vault.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# EC2 donde vivirá Vault
resource "aws_instance" "vault" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnet.default.id
  key_name                    = aws_key_pair.fase3.key_name
  vpc_security_group_ids      = [aws_security_group.vault.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 10

    tags = {
      Name = "fase3-vault-data"
    }
  }

  tags = {
    Name    = "fase3-vault-server"
    Project = "Proyecto-Integrador-DevOps"
    Phase   = "Fase-3"
  }
}

output "vault_public_ip" {
  description = "IP publica del servidor Vault"
  value       = aws_instance.vault.public_ip
}

output "vault_url" {
  description = "Direccion web de Vault"
  value       = "http://${aws_instance.vault.public_ip}:8200"
}

output "ssh_command" {
  description = "Comando para conectarse al servidor"
  value       = "ssh -i ~/.ssh/fase3-vault ubuntu@${aws_instance.vault.public_ip}"
}