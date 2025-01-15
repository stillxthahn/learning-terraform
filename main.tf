terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.region
}



module "vpc" {
  source = "./modules/vpc"

  prefix    = var.environment_name
  separator = "-"
  name      = "streamsong"

  vpc_cidr_block = var.vpc_cidr_block
}

# Additional policies
data "aws_iam_policy" "lambda_full_access" {
  arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}

data "aws_iam_policy" "emr_full_access" {
  arn = "arn:aws:iam::aws:policy/AmazonEMRFullAccessPolicy_v2"
}


# Create S3 bucket to store /dags and /req
resource "aws_s3_bucket" "airflow_bucket" {
  bucket = "airflow_bucket"
  tags = {
    Name = "${var.environment_name}-streamsong-bucket"
  }
}

resource "aws_s3_object" "dags_upload" {
  for_each = fileset("dags/", "*")
  bucket   = aws_s3_bucket.airflow_bucket.id
  key      = "dags/${each.value}"
  source   = "dags/${each.value}"
  etag     = filemd5("dags/${each.value}")
}

module "mwaa" {
  source = "aws-ia/mwaa/aws"

  name = "${var.environment_name}-streamsong-mwaa"
  # Currently this modules just allows mw1.small and above
  environment_class = "mw1.small"
  create_s3_bucket  = false
  source_bucket_arn = aws_s3_bucket.airflow_bucket.arn
  dag_s3_path       = "dags"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  min_workers           = 1
  max_workers           = 2
  webserver_access_mode = "PUBLIC_ONLY" # Default PRIVATE_ONLY for production environments

  iam_role_additional_policies = {
    "additional-policy-1" = data.aws_iam_policy.lambda_full_access.arn
    "additional-policy-2" = data.aws_iam_policy.emr_full_access.arn
  }

  logging_configuration = {
    dag_processing_logs = {
      enabled   = true
      log_level = "INFO"
    }

    scheduler_logs = {
      enabled   = true
      log_level = "INFO"
    }

    task_logs = {
      enabled   = true
      log_level = "INFO"
    }

    webserver_logs = {
      enabled   = true
      log_level = "INFO"
    }

    worker_logs = {
      enabled   = true
      log_level = "INFO"
    }
  }

  airflow_configuration_options = {
    "core.load_default_connections" = "false"
    "core.load_examples"            = "true"
    "webserver.dag_default_view"    = "tree"
    "webserver.dag_orientation"     = "TB"
    "logging.logging_level"         = "INFO"
  }
}



