variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-ops-manager"
}

variable "owner" {
  description = "Owner Name"
  type        = string
  ##default     = "name.surname"
}

variable "keep_until" {
  description = "Keep Until date"
  type        = string
  ##default     = "2025-05-01"
}

variable "profawscli" {
  description = "Profile Credential for AWS CLI"
  type        = string
}

variable "region" {
  description = "Default Region"
  type        = string
  default     = "eu-west-1"
}

variable "cluster_version" {
  description = "EKS cluster version."
  type        = string
  default     = "1.36"
}

variable "ami_release_version" {
  description = "Default EKS AMI release version for node groups"
  type        = string
  default     = "1.36.2-20260625"
}

variable "ami_ami_type_x86" {
  ### https://github.com/awslabs/amazon-eks-ami/releases
  description = "Default EKS AMI AMI Type for Karpenter on node groups"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "ami_ami_type_arm" {
  ### https://github.com/awslabs/amazon-eks-ami/releases
  description = "Default EKS AMI AMI Type for Karpenter on node groups"
  type        = string
  default     = "AL2023_ARM_64_STANDARD"
}

variable "ami_ami_type_nvidia" {
  ### https://github.com/awslabs/amazon-eks-ami/releases
  description = "Default EKS AMI AMI Type for Karpenter on node groups"
  type        = string
  default     = "AL2023_x86_64_NVIDIA"
}

variable "vpc_cidr" {
  description = "Defines the CIDR block used on Amazon VPC created for Amazon EKS."
  type        = string
  default     = "10.42.0.0/16"
}

variable "remote_network_cidr" {
  description = "Defines the remote CIDR blocks used on Amazon VPC created for Amazon EKS Hybrid Nodes."
  type        = string
  default     = "10.52.0.0/16"
}

variable "remote_pod_cidr" {
  description = "Defines the remote CIDR blocks used on Amazon VPC created for Amazon EKS Hybrid Nodes."
  type        = string
  default     = "10.53.0.0/16"
}