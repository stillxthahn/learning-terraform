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

module "mwaa" {
  source = "aws-ia/mwaa/aws"

  name              = "${var.environment_name}-streamsong-mwaa"
  environment_class = "mw1.small"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  min_workers           = 1
  max_workers           = 2
  webserver_access_mode = "PUBLIC_ONLY" # Default PRIVATE_ONLY for production environments

  iam_role_additional_policies = {
    "additional-policy-1" = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    # "additional-policy-2" = "arn:aws:iam::aws:policy/service-role/AmazonEMRFullAccessPolicy"
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



