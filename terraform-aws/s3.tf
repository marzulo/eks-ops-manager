resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  buckets = {
    logs = {
      versioning_enabled  = false
      object_lock_enabled = false
    }
    logs-immutable = {
      versioning_enabled  = true
      object_lock_enabled = true
    }
  }
}

module "s3-ops-manager-logs" {
  source   = "terraform-aws-modules/s3-bucket/aws"
  version  = "4.11.0"
  for_each = local.buckets

  bucket                   = "${var.cluster_name}-${each.key}-${random_id.suffix.hex}"
  acl                      = "private"
  force_destroy            = true
  control_object_ownership = true
  object_ownership         = "ObjectWriter"
  object_lock_enabled      = each.value.object_lock_enabled

  versioning = {
    enabled = each.value.versioning_enabled
  }

  server_side_encryption_configuration = {
    rule = {
      bucket_key_enabled = true
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.tags
}

resource "aws_s3_bucket_ownership_controls" "s3opsmanager_acl_ownership" {
  for_each = module.s3-ops-manager-logs
  bucket   = each.value.s3_bucket_id
  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_policy" "s3opsmanagerlogspolicy" {
  bucket = module.s3-ops-manager-logs["logs"].s3_bucket_id
  policy = data.aws_iam_policy_document.bucketpolicylogsdoc.json
}

resource "local_file" "opsmanagers3_yaml" {
  filename = "${path.cwd}/../mongodb-kubernetes/mongodb-om-tls-backup.yaml"
  content = templatefile("${path.cwd}/../mongodb-kubernetes/mongodb-om-tls-backup.tmpl.yaml", {
    s3BucketName          = module.s3-ops-manager-logs["logs"].s3_bucket_id
    s3BucketEndpoint      = "https://s3.${var.region}.amazonaws.com"
    s3ImmutBucketName     = module.s3-ops-manager-logs["logs-immutable"].s3_bucket_id
    s3ImmutBucketEndpoint = "https://s3.${var.region}.amazonaws.com"
  })
}
