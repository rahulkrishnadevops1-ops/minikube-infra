# Terraform + Ansible Minikube EC2 setup

This repository provisions an AWS EC2 instance with Terraform, configures it with Ansible, and automates both steps through Jenkins.

## Structure

- `infra/`: Terraform for the EC2 instance, security group, and generated Ansible inventory
- `ansible/`: Host configuration for Docker, Minikube, `kubectl`, and Helm
- `Jenkinsfile`: CI/CD pipeline that runs Terraform and then Ansible

## Prerequisites

- AWS account and permissions to create EC2, security groups, and to access the S3/DynamoDB backend
- S3 bucket and DynamoDB table for Terraform remote state (see `infra/backend.tf`)
- An existing EC2 key pair in AWS (region `eu-north-1` by default)
- Matching private key available locally or as a Jenkins credential
- Terraform 1.5+
- Ansible installed on the machine or Jenkins agent that will run the playbook

## Local usage

1. Update `infra/terraform.tfvars` with your values (especially `key_name`).
2. Run Terraform.
3. Run Ansible after Terraform generates `infra/inventory.ini`.

```powershell
cd infra
terraform init
terraform apply -var-file="terraform.tfvars"

cd ../ansible
ansible-playbook playbook.yml
```

## Terraform backend

The backend is configured in `infra/backend.tf` to use S3 with DynamoDB locking. Ensure the S3 bucket and DynamoDB table exist before running `terraform init`.

## Jenkins usage

The `Jenkinsfile` expects:

- a Linux Jenkins agent with `terraform` and `ansible-playbook`
- AWS credentials via instance role on the Jenkins EC2 instance
- a Jenkins Secret file credential containing the SSH private key
  - ID: `ssh-private-key`
  - Username used by Ansible: `ec2-user`

The pipeline provisions the instance, uses the Terraform-generated inventory, and then installs Minikube and Helm on the EC2 host.

## What gets created

- 1 EC2 instance (`c7i-flex.large` by default) in the default VPC
- 1 security group allowing SSH (22), HTTP (80), HTTPS (443), and NodePort range (30000-32767)
- Ansible inventory file at `infra/inventory.ini`

## Defaults in `infra/terraform.tfvars`

- Region: `eu-north-1`
- Instance type: `c7i-flex.large`
- Instance name: `minikube-control`
- Key pair: `Ansible`
- SSH CIDR: `0.0.0.0/0`
