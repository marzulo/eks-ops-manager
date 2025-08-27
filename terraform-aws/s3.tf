resource "random_id" "suffix" {
  byte_length = 4
}

module "s3-ops-manager-logs" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.11.0"

  bucket                   = "${var.cluster_name}-logs-${random_id.suffix.hex}"
  acl                      = "private"
  force_destroy            = "true"
  control_object_ownership = true
  object_ownership         = "ObjectWriter"
  object_lock_enabled      = "false"

  versioning = {
    enabled = false
  }
  tags = local.tags
}

resource "aws_s3_bucket_ownership_controls" "s3opsmanager_acl_ownership" {
  bucket = module.s3-ops-manager-logs.s3_bucket_id
  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_policy" "s3opsmanagerlogspolicy" {
  bucket = module.s3-ops-manager-logs.s3_bucket_id
  policy = data.aws_iam_policy_document.bucketpolicylogsdoc.json
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3opsmanagerlogsencryption" {
  bucket = module.s3-ops-manager-logs.s3_bucket_id
  rule {
    bucket_key_enabled = "true"
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "local_file" "opsmanagers3_yaml" {
  filename = "${path.cwd}/../mongodb-kubernetes/mongodb-om-tls-backup.yaml"
  content = templatefile("${path.cwd}/../mongodb-kubernetes/mongodb-om-tls-backup.tmpl.yaml", {
    s3BucketName     = module.s3-ops-manager-logs.s3_bucket_id
    s3BucketEndpoint = "https://s3.${var.region}.amazonaws.com"
  })
}
