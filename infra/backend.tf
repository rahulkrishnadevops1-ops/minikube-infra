terraform {
  backend "s3" {
    bucket = "kubecoin-terraform-state-rahul"
    key    = "kubecoin/terraform.tfstate"
    region = "ap-south-1"
  }
}

