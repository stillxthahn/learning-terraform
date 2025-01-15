# Additional policies
data "aws_iam_policy" "lambda_full_access" {
  arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}

data "aws_iam_policy" "emr_full_access" {
  arn = "arn:aws:iam::aws:policy/AmazonEMRFullAccessPolicy_v2"
}
