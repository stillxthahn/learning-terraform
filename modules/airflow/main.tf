locals {
  base_name = "${var.prefix}${var.separator}${var.name}"
}


resource "aws_mwaa_environment" "main" {
  dag_s3_path        = "dags/"
  execution_role_arn = aws_iam_role.this.arn
  name               = local.base_name

  network_configuration {
    security_group_ids = [aws_security_group.main.id]
    subnet_ids         = var.subnet_ids
  }

  source_bucket_arn = aws_s3_bucket.airflow_bucket.arn

  max_workers           = 1
  webserver_access_mode = "PUBLIC_ONLY"

  airflow_configuration_options = {
    "core.load_default_connections" = "false"
    "core.load_examples"            = "false"
    "webserver.dag_default_view"    = "tree"
    "webserver.dag_orientation"     = "TB"
    "logging.logging_level"         = "INFO"
  }

  tags = {
    Name = "${local.base_name}-mwmm"
  }
}
