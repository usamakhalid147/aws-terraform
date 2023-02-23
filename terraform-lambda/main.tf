provider "aws" {
  region = "us-east-1"
}

data "archive_file" "example_lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/example_lambda.zip"
  source_dir  = "${path.module}/lambda_function"
}

resource "aws_lambda_function" "example_lambda" {
  filename      = "${path.module}/example_lambda.zip"
  function_name = "example_lambda"
  role          = aws_iam_role.lambda_role.arn

  handler = "lambda_handler.handler"
  runtime = "python3.8"

  environment {
    variables = {
      "S3_BUCKET" = "example-bucket"
    }
  }

  source_code_hash = filebase64sha256("${path.module}/example_lambda.zip")  
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  description = "Policy for lambda function"
  policy      = data.aws_iam_policy_document.lambda_policy.json
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      "arn:aws:s3:::example-bucket/*"
    ]
  }
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  policy_arn = aws_iam_policy.lambda_policy.arn
  role       = aws_iam_role.lambda_role.name
}

