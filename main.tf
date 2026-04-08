terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.39.0"
    }
  }
}

provider "aws" {
    region = var.region
}

# s3 Bucket
resource "aws_s3_bucket" "hm_s3" {
    bucket = var.bucket_name
    
    tags = {
        Name = var.bucket_name
    }
}

# SNS Topic
resource "aws_sns_topic" "sns_topic" {
    name = "health-monitor-topic"
    tags = {
        Project   = "health-monitor"
        ManagedBy = "Terraform"
    }
}

# SNS subscription
resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "email"
  endpoint  = var.email_address
}

# zip the python file
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/handler.py"
  output_path = "${path.module}/src/handler.zip"
}

# lambda function
resource "aws_lambda_function" "health-monitor-lambda" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "health-monitor-handler"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "handler.handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME   = var.bucket_name
      SNS_TOPIC_ARN = aws_sns_topic.sns_topic.arn
    }
  }
      tags = {
    Project   = "health-monitor"
    ManagedBy = "Terraform"
      }
}