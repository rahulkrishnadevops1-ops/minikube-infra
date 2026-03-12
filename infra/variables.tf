variable "aws_region" {
  type        = string
  default     = "ap-south-1"
  description = "AWS region where the EC2 instance will be created."
}

variable "instance_type" {
  type        = string
  default     = "c7i.large"
  description = "EC2 instance type for the Minikube host."
}

variable "instance_name" {
  type        = string
  default     = "minikube-control"
  description = "Name tag for the EC2 instance."
}

variable "key_name" {
  type        = string
  default     = "Nov-jenkins"
  description = "Existing AWS key pair name used to access the instance."
}

variable "allowed_ssh_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR block allowed to SSH to the instance."
}
