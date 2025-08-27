locals {
  remote_node_cidr = var.remote_network_cidr
  remote_pod_cidr  = var.remote_pod_cidr
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.2"

  cluster_name                             = var.cluster_name
  cluster_version                          = var.cluster_version
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  cluster_enabled_log_types                = ["audit", "api", "authenticator"]
  cloudwatch_log_group_retention_in_days   = 30
  cluster_endpoint_private_access          = true

  cluster_upgrade_policy = {
    support_type = "STANDARD"
  }

  create_iam_role = false
  iam_role_arn    = aws_iam_role.role_cluster_eks.arn

  cluster_addons = {
    coredns = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"

      configuration_values = jsonencode({
        "replicaCount" : 1,
        "resources" : {
          "limits" : {
            "cpu" : "100m",
            "memory" : "200Mi"
          },
          "requests" : {
            "cpu" : "100m",
            "memory" : "200Mi"
          }
        }
      })
      tags = merge(local.tags, {
        "eks_addon" = "coredns"
      })
    }
    aws-ebs-csi-driver = {
      service_account_role_arn = aws_iam_role.pods_eks.arn
      resolve_conflicts        = "PRESERVE"

      tags = merge(local.tags, {
        "eks_addon" = "aws-ebs-csi-driver"
      })
    }
    aws-efs-csi-driver = {
      service_account_role_arn = aws_iam_role.efs_cni_role.arn
      resolve_conflicts        = "OVERWRITE"

      tags = merge(local.tags, {
        "eks_addon" = "aws-efs-csi-driver"
      })
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      before_compute = true
      most_recent    = true
      configuration_values = jsonencode({
        env = {
          ENABLE_POD_ENI                    = "true"
          ENABLE_PREFIX_DELEGATION          = "true"
          POD_SECURITY_GROUP_ENFORCING_MODE = "standard"
        }
        nodeAgent = {
          enablePolicyEventLogs = "true"
        }
        enableNetworkPolicy = "true"
      })
      service_account_role_arn = aws_iam_role.vpc_cni_role.arn
      tags = merge(local.tags, {
        "eks_addon" = "vpc-cni"
      })
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = concat(module.vpc.private_subnets, module.vpc.public_subnets)

  eks_managed_node_group_defaults = {
    instance_types = ["r7i.large", "r7i.xlarge"]
  }

  create_cluster_security_group = false
  create_node_security_group    = false
  cluster_security_group_additional_rules = {
    hybrid-node = {
      cidr_blocks = [local.remote_node_cidr]
      description = "Allow all traffic from remote node/pod network"
      from_port   = 0
      to_port     = 0
      protocol    = "all"
      type        = "ingress"
    }

    hybrid-pod = {
      cidr_blocks = [local.remote_pod_cidr]
      description = "Allow all traffic from remote node/pod network"
      from_port   = 0
      to_port     = 0
      protocol    = "all"
      type        = "ingress"
    }
  }

  node_security_group_additional_rules = {
    hybrid_node_rule = {
      cidr_blocks = [local.remote_node_cidr]
      description = "Allow all traffic from remote node/pod network"
      from_port   = 0
      to_port     = 0
      protocol    = "all"
      type        = "ingress"
    }

    hybrid_pod_rule = {
      cidr_blocks = [local.remote_pod_cidr]
      description = "Allow all traffic from remote node/pod network"
      from_port   = 0
      to_port     = 0
      protocol    = "all"
      type        = "ingress"
    }
  }

  cluster_remote_network_config = {
    remote_node_networks = {
      cidrs = [local.remote_node_cidr]
    }
    # Required if running webhooks on Hybrid nodes
    remote_pod_networks = {
      cidrs = [local.remote_pod_cidr]
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = ["r7i.xlarge", "r7i.2xlarge"]
      #force_update_version     = true
      release_version          = var.ami_release_version
      ami_type                 = var.ami_ami_type
      use_name_prefix          = false
      create_iam_role          = false
      iam_role_arn             = aws_iam_role.role_node_eks.arn
      iam_role_use_name_prefix = false
      disk_size                = 60
      ebs_optimized            = true
      iam_role_additional_policies = {
        ssm_access        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        cloudwatch_access = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
        service_role_ssm  = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
        default_policy    = "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"
      }

      min_size     = 1
      max_size     = 5
      desired_size = 3

      update_config = {
        max_unavailable_percentage = 100
      }

      labels = {
        "karpenter.sh/controller"     = "false"
        "${var.cluster_name}-default" = "yes"
      }
    }
  }

  #node_security_group_tags = merge(local.tags, {
  #  "karpenter.sh/discovery" = var.cluster_name
  #})
  node_security_group_tags = local.tags
  #tags = merge(local.tags, {
  #  "karpenter.sh/discovery" = var.cluster_name
  #})
  tags = local.tags
}

#Role for vpc cni
resource "aws_iam_role" "vpc_cni_role" {
  name               = "role-${var.cluster_name}-vpc-cni"
  tags               = local.tags
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${module.eks.oidc_provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${module.eks.oidc_provider}:sub": "system:serviceaccount:kube-system:aws-node"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "vpc_cni_policy" {
  role       = aws_iam_role.vpc_cni_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

#Role for efs cni controler
resource "aws_iam_role" "efs_cni_role" {
  name               = "role-${var.cluster_name}-efs-cni"
  tags               = local.tags
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${module.eks.oidc_provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${module.eks.oidc_provider}:sub": "system:serviceaccount:kube-system:efs-csi-controller-sa",
          "${module.eks.oidc_provider}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "efs_cni_policy" {
  role       = aws_iam_role.efs_cni_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "efs_full_policy" {
  role       = aws_iam_role.efs_cni_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess"
}

resource "aws_iam_role" "pods_eks" {
  name               = "role-${var.cluster_name}-podseks"
  tags               = local.tags
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "pods.eks.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_ebs" {
  role       = aws_iam_role.pods_eks.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_efs" {
  role       = aws_iam_role.pods_eks.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  role       = aws_iam_role.pods_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_s3" {
  role       = aws_iam_role.pods_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "eks_ca" {
  role       = aws_iam_role.pods_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AWSPrivateCAConnectorForKubernetesPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cloudwatch" {
  role       = aws_iam_role.pods_eks.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_pods_efs" {
  role       = aws_iam_role.pods_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess"
}

resource "aws_iam_role" "role_cluster_eks" {
  name               = "role-${var.cluster_name}-cluster_eks"
  tags               = local.tags
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "eks.amazonaws.com"
            },
            "Action": [
                "sts:AssumeRole",
                "sts:TagSession"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cluster_eks_ebs" {
  role       = aws_iam_role.role_cluster_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_eks_vpcrsc" {
  role       = aws_iam_role.role_cluster_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

resource "aws_iam_role_policy_attachment" "cluster_eks_cluster" {
  role       = aws_iam_role.role_cluster_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_eks_service" {
  role       = aws_iam_role.role_cluster_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_eks_compute" {
  role       = aws_iam_role.role_cluster_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_eks_lb" {
  role       = aws_iam_role.role_cluster_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_eks_network" {
  role       = aws_iam_role.role_cluster_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_eks_s3" {
  role       = aws_iam_role.role_cluster_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "cluster_eks_efs" {
  role       = aws_iam_role.role_cluster_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess"
}

resource "aws_iam_role" "role_node_eks" {
  name               = "role-${var.cluster_name}-nodes_eks"
  tags               = local.tags
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "nodes_eks_ecrP" {
  role       = aws_iam_role.role_node_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy_attachment" "nodes_eks_ecrR" {
  role       = aws_iam_role.role_node_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "nodes_eks_worker" {
  role       = aws_iam_role.role_node_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "nodes_eks_cni" {
  role       = aws_iam_role.role_node_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "nodes_eks_s3" {
  role       = aws_iam_role.role_node_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "nodes_ebs" {
  role       = aws_iam_role.role_node_eks.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "nodes_efs_scsi" {
  role       = aws_iam_role.role_node_eks.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "nodes_efs" {
  role       = aws_iam_role.role_node_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess"
}

resource "aws_iam_role_policy_attachment" "nodes_lb" {
  role       = aws_iam_role.role_node_eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
}

/*resource "local_file" "efs_cni_serviceacct" {
  content  = <<-EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/name: aws-efs-csi-driver
  annotations:
    eks.amazonaws.com/role-arn: ${aws_iam_role.efs_cni_role.arn}
  name: efs-csi-controller-sa
  namespace: kube-system
  EOF
  file_permission = "0644"
  filename = "${path.cwd}/../../mongodb/mongodb_efscniserviceacct.yaml"
}*/
