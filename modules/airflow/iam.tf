locals {
  base_name = "${var.prefix}${var.separator}${var.name}"
}

resource "aws_iam_role" "this" {
  name               = "${local.base_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags = {
    Name = "${local.base_name}-execution-role"
  }
}



resource "aws_iam_role_policy" "this" {
  name   = "${local.base_name}-execution-policy"
  policy = data.aws_iam_policy_document.this.json
  role   = aws_iam_role.this.id
}


data "aws_iam_policy_document" "assume" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    principals {
      identifiers = [
        "airflow-env.amazonaws.com",
        "airflow.amazonaws.com"
      ]
      type = "Service"
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}

data "aws_iam_policy_document" "base" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = [
      "airflow:PublishMetrics"
    ]
    resources = [
      "arn:aws:airflow:${var.region}:${var.account_id}:environment/${local.base_name}"
    ]
  }
  statement {
    effect  = "Deny"
    actions = ["s3:ListAllMyBuckets"]
    resources = [
      aws_s3_bucket.airflow_bucket.arn,
      "${aws_s3_bucket.airflow_bucket.arn}/*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject*",
      "s3:GetBucket*",
      "s3:List*"
    ]
    resources = [
      aws_s3_bucket.airflow_bucket.arn,
      "${aws_s3_bucket.airflow_bucket.arn}/*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetAccountPublicAccessBlock"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:GetLogRecord",
      "logs:GetLogGroupFields",
      "logs:GetQueryResults"
    ]
    resources = [
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:airflow-${local.base_name}-*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups"
    ]
    resources = [
      "*"
    ]
  }
  statement {

    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
      "sqs:SendMessage"
    ]
    resources = [
      "arn:aws:sqs:${var.region}:*:airflow-celery-*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey*",
      "kms:Encrypt"
    ]
    resources = var.kms_key_arn != null ? [
      var.kms_key_arn
    ] : []
    not_resources = var.kms_key_arn == null ? [
      "arn:aws:kms:*:${var.account_id}:key/*"
    ] : []
    condition {
      test = "StringLike"
      values = var.kms_key_arn != null ? [
        "sqs.${var.region}.amazonaws.com",
        "s3.${var.region}.amazonaws.com"
        ] : [
        "sqs.${var.region}.amazonaws.com"
      ]
      variable = "kms:ViaService"
    }
  }
}

data "aws_iam_policty_document" "additional_execution_policy_doc" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "this" {
  source_policy_documents = [
    data.aws_iam_policy_document.base.json,

    ## Additional policies - Lambda
    var.additional_execution_role_policy_document_json
  ]
}