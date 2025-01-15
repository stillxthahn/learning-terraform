# Create S3 bucket to store /dags and /req
resource "aws_s3_bucket" "mwaa_bucket" {
  bucket = "${local.base_name}-bucket"
}

resource "aws_s3_object" "dags_upload" {
  for_each = fileset("dags/", "*")
  bucket   = aws_s3_bucket.mwaa_bucket.id
  key      = "dags/${each.value}"
  source   = "dags/${each.value}"
  etag     = filemd5("dags/${each.value}")
}


