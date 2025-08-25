locals {
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 3, k + 3)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 3, k)]
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = var.cluster_name
  cidr = var.vpc_cidr

  azs                   = local.azs
  public_subnets        = local.public_subnets
  private_subnets       = local.private_subnets
  public_subnet_suffix  = "SubnetPublic"
  private_subnet_suffix = "SubnetPrivate"

  enable_nat_gateway      = true
  create_igw              = true
  enable_dns_hostnames    = true
  enable_dns_support      = true
  single_nat_gateway      = true
  enable_dhcp_options     = true
  map_public_ip_on_launch = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = merge(local.tags, { Name = "${var.cluster_name}-default" })
  manage_default_route_table    = true
  default_route_table_tags      = merge(local.tags, { Name = "${var.cluster_name}-default" })
  manage_default_security_group = true
  default_security_group_tags   = merge(local.tags, { Name = "${var.cluster_name}-default" })

  public_subnet_tags = merge(local.tags, {
    "kubernetes.io/role/elb" = "1"
  })
  private_subnet_tags = merge(local.tags, {
    #"karpenter.sh/discovery"          = var.cluster_name
    "kubernetes.io/role/internal-elb" = "1"
  })

  tags = local.tags
}

module "vpc_vpc-endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "5.19.0"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.vpc.default_security_group_id]
  subnet_ids         = module.vpc.private_subnets

  endpoints = {
    s3 = {
      service         = "s3"
      route_table_ids = module.vpc.private_route_table_ids
      tags            = merge(local.tags, { Name = "s3-vpc-endpoint${var.cluster_name}" })
      service_type    = "Gateway"
    },
  }
  tags = local.tags
}