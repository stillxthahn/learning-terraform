locals {
  base_name = "${var.prefix}${var.separator}${var.name}"
}


module "mwaa" {
  source = "aws-ia/mwaa/aws"

  name = "${local.base_name}-mwaa"
  # Currently this modules just allows mw1.small and above
  environment_class = "mw1.small"
  create_s3_bucket  = false
  source_bucket_arn = aws_s3_bucket.mwaa_bucket.arn
  dag_s3_path       = "dags"

  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids

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
