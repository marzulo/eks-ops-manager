locals {
  tags = {
    owner         = var.owner
    keep_until    = var.keep_until
    provisionedby = "Terraform"
    env           = var.cluster_name
  }
}