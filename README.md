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
- Python 3 and `boto3` installed on the Jenkins agent (for dynamic inventory)

The pipeline provisions the instance, uses the Terraform-generated inventory, and then installs Minikube and Helm on the EC2 host.

## What gets created

- 1 EC2 instance (`c7i-flex.large` by default) in the default VPC
- 1 security group allowing SSH (22), HTTP (80), HTTPS (443), Kubernetes API (8443), and NodePort range (30000-32767)
- Ansible inventory file at `infra/inventory.ini`

## Access Minikube from another machine

The Ansible playbook keeps Minikube local context healthy and now exposes the API server on EC2 host `:8443`.

What the playbook does:

1. Starts Minikube with API SANs (`<ec2-public-ip>,127.0.0.1`).
2. Exposes API port `8443` from EC2 host to Minikube IP via `minikube-apiserver-expose.service`.
3. Exposes NodePort range `30000-32767` from EC2 host to Minikube IP via `minikube-nodeport-expose.service`.
4. Runs `minikube update-context` on the EC2 host to avoid kubeconfig mismatch.
5. Generates and fetches two kubeconfigs:
   - `kubeconfig-public-<host-ip>.yaml` (server `https://<ec2-public-ip>:8443`)
   - `kubeconfig-tunnel-<host-ip>.yaml` (server `https://127.0.0.1:8443`, optional fallback)

Where to get kubeconfig:

- Local run: `ansible/artifacts/kubeconfig-public-<host-ip>.yaml` in this repository.
- Jenkins run: same path inside Jenkins workspace and archived by the pipeline as a build artifact.

Use public kubeconfig (no tunnel needed):

```bash
kubectl --kubeconfig kubeconfig-public-<host-ip>.yaml get nodes
helm --kubeconfig kubeconfig-public-<host-ip>.yaml list -A
```

NodePort app access (example `30081`) from another machine:

```bash
http://<ec2-public-ip>:30081
```

This now works without per-port tunneling because Ansible installs `minikube-nodeport-expose.service`, which forwards NodePort range `30000-32767` from EC2 host to Minikube IP.

Ensure EC2 security group allows required NodePort(s) from your source IP.

## Dynamic inventory

We use a small Python script (`ansible/inventory.py`) to discover the EC2 instance by tag.
Defaults:

- Tag filter: `Project=minikube-host`
- Region: `eu-north-1`
- User: `ec2-user`

Why not the `amazon.aws.aws_ec2` plugin?

- The plugin is standard, but it requires the `amazon.aws` collection to be installed and loaded correctly on the Jenkins agent.
- In this environment the plugin failed to load reliably, so the pipeline could not resolve hosts.
- The custom script is small, explicit, and only depends on `boto3`, which is already required for AWS access.

Is this standard?

- Yes. Custom dynamic inventory scripts are a supported and common Ansible pattern.
- If you want to switch back to the plugin later, add the `amazon.aws` collection and replace `ansible/ansible.cfg` to point at a `aws_ec2.yaml` inventory.

## Defaults in `infra/terraform.tfvars`

- Region: `eu-north-1`
- Instance type: `c7i-flex.large`
- Instance name: `minikube-control`
- Key pair: `Ansible`
- SSH CIDR: `0.0.0.0/0`
