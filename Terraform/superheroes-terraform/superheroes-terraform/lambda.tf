
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "./python/main.py"
  output_path = "./python/main.py.zip"
}

module "lambda-function" {
  source  = "mineiros-io/lambda-function/aws"
  version = "~> 0.5.0"

  function_name = "python-function"
  description   = "Example Python Lambda function that returns an HTTP response."
  filename      = data.archive_file.lambda.output_path
  runtime       = "python3.8"
  handler       = "main.lambda_handler"
  timeout       = 30
  memory_size   = 128

  role_arn = module.iam_role.role.arn

  module_tags = {
    Environment = "Dev"
  }
}

module "iam_role" {
  source  = "mineiros-io/iam-role/aws"
  version = "~> 0.6.0"

  name = "python-function"

  assume_role_principals = [
    {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  ]

  tags = {
    Environment = "Dev"
  }
}