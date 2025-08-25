
module "efs" {
  source = "terraform-aws-modules/efs/aws"

  name      = "efs_${var.cluster_name}"
  encrypted = false

  deny_nonsecure_transport         = false
  enable_backup_policy             = false
  create_replication_configuration = false
  throughput_mode                  = "bursting"
  performance_mode                 = "generalPurpose"

  #creation_token = "example-token"
  #kms_key_arn    = "arn:aws:kms:eu-west-1:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab"

  lifecycle_policy = {
    transition_to_ia = "AFTER_30_DAYS"
  }

  security_group_description = "EFS Default Terraform Security Group ${var.cluster_name}"
  security_group_vpc_id      = module.vpc.vpc_id
  security_group_rules = {
    vpc = {
      # relying on the defaults provided for EFS/NFS (2049/TCP + ingress)
      description = "NFS ingress from VPC private subnets"
      cidr_blocks = concat(module.vpc.private_subnets_cidr_blocks, module.vpc.public_subnets_cidr_blocks)
    }
  }

  attach_policy                      = true
  bypass_policy_lockout_safety_check = false
  policy_statements = [
    {
      sid     = "efs statement for eks"
      actions = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientRootAccess", "elasticfilesystem:ClientWrite"]
      principals = [
        {
          type = "AWS"
          identifiers = [aws_iam_role.role_node_eks.arn,
            aws_iam_role.pods_eks.arn,
            aws_iam_role.role_cluster_eks.arn
          ]
        }
      ]
    }
  ]

  mount_targets = { for k, v in zipmap(local.azs, module.vpc.private_subnets) : k => { subnet_id = v } }

  # Access point(s)
  access_points = {
    root = {
      root_directory = {
        path = "/"
        creation_info = {
          owner_gid   = 2000
          owner_uid   = 2000
          permissions = "777"
        }
      }
      tags = local.tags
    }
  }

  tags = local.tags
}

resource "local_file" "efs_storage_class" {
  content         = <<-EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: efs-sc
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: efs.csi.aws.com
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  provisioningMode: efs-ap
  fileSystemId: ${module.efs.id}
  directoryPerms: "777"
  uid: "2000"
  gid: "2000"
  EOF
  file_permission = "0644"
  filename        = "${path.cwd}/../mongodb-kubernetes/mongodb-storageclass-efs.yaml"
}
