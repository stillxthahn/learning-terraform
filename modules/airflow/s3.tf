locals {
  base_name = "${var.prefix}${var.separator}${var.name}"
}

# S3 bucket
resource "aws_s3_bucket" "airflow_bucket" {
  bucket = "airflow_bucket"

  tags = {
    Name = "${local.base_name}-bucket"
  }
}
