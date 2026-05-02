################################
# Package Lambda (zip local)
################################
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/lambda/function.zip"
}

################################
# Lambda Function
################################
resource "aws_lambda_function" "processor" {
  function_name    = "pritunl-processor"
  runtime          = "python3.11"
  handler          = "index.handler"
  role             = aws_iam_role.lambda.arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.configs.id
    }
  }

  tags = { Name = "pritunl-processor" }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy.lambda_s3
  ]
}

################################
# CloudWatch Log Group Lambda
################################
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.processor.function_name}"
  retention_in_days = 7
}
