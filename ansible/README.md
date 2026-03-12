# Ansible configuration

This playbook configures the EC2 instance created by Terraform as a single-node Minikube host and installs Helm.

## Run locally

```powershell
cd infra
terraform init
terraform apply -var-file="terraform.tfvars"

cd ../ansible
ansible-playbook playbook.yml
```

## Remote Minikube API access

The playbook prepares Minikube for direct remote access (without mandatory SSH tunnel).

Implemented behavior:

1. Minikube starts with API SANs for public IP and localhost (`--apiserver-ips=<public-ip>,127.0.0.1`).
2. A systemd service (`minikube-apiserver-expose.service`) exposes API port `8443` on EC2 host.
3. A systemd service (`minikube-nodeport-expose.service`) exposes NodePort range `30000-32767` on EC2 public interface.
4. `minikube update-context` is run on EC2 to keep host-side kubectl healthy.
5. Flattened kubeconfigs are generated:
   - `/home/ec2-user/kubeconfig-public.yaml` (public endpoint)
   - `/home/ec2-user/kubeconfig-tunnel.yaml` (localhost endpoint)
6. Both kubeconfigs are fetched to `ansible/artifacts/`.

## Using kubeconfig from another machine

1. Get `ansible/artifacts/kubeconfig-public-<host-ip>.yaml` from local run output or Jenkins artifact.
2. Run:

```bash
kubectl --kubeconfig kubeconfig-public-<host-ip>.yaml get nodes
```

## Access app via public IP (NodePort)

If your service is NodePort `30081`, access it directly from outside:

```text
http://<ec2-public-ip>:30081
```

No per-app SSH tunnel is needed for NodePort services after this playbook runs.
