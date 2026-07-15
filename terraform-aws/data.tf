data "aws_caller_identity" "current" {}

locals {
  ## Check the principal based in your region here 
  ## https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html#attach-bucket-policy
  ## identifiers = ["arn:aws:iam::054676820928:root"] ## eu-central-1 Frankfurt
  ## identifiers = ["arn:aws:iam::156460612806:root"] ## eu-west-1 Ireland
  ## identifiers = ["arn:aws:iam::897822967062:root"] ## eu-north-1 Stockholm
  ## identifiers = ["arn:aws:iam::127311923021:root"] ## us-east-1 N. Virginia
  elb_account_ids = {
    "eu-central-1" = "054676820928"
    "eu-west-1"    = "156460612806"
    "eu-north-1"   = "897822967062"
    "us-east-1"    = "127311923021"
  }
}

data "aws_iam_policy_document" "bucketpolicylogsdoc" {

  statement {
    sid = "GetObjectELBeucentral1"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.elb_account_ids[var.region]}:root"]
    }
    actions = [
      "s3:GetObject", "s3:PutObject"
    ]
    resources = [
      "${module.s3-ops-manager-logs["logs"].s3_bucket_arn}/*"
    ]
  }
  statement {
    sid = "AWSLogDeliveryAclCheck"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions = [
      "s3:GetBucketAcl"
    ]
    resources = [
      "${module.s3-ops-manager-logs["logs"].s3_bucket_arn}"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = ["${data.aws_caller_identity.current.account_id}"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:elasticloadbalancing:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
  statement {
    sid = "AWSLogDeliveryWrite"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "${module.s3-ops-manager-logs["logs"].s3_bucket_arn}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = ["${data.aws_caller_identity.current.account_id}"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:elasticloadbalancing:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}
