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
resource "aws_lambda_function" "health_monitor_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "health-monitor-handler"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "handler.handler"
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

# EventBridge rule — hourly schedule
resource "aws_cloudwatch_event_rule" "lambda" {
  name                = "health-alert-hourly"
  description         = "Triggers s3 health check every hour"
  schedule_expression = "rate(1 hour)"
}

# EventBridge target — points the rule at Lambda
resource "aws_cloudwatch_event_target" "lambda_target" {
  target_id = "hourly-alert"
  rule      = aws_cloudwatch_event_rule.lambda.name
  arn       = aws_lambda_function.health_monitor_lambda.arn
}

# Lambda permission — allows EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeToInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.health_monitor_lambda.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda.arn
}

# CloudWatch alarm - every hour
resource "aws_cloudwatch_metric_alarm" "health_monitor_alarm" {
  alarm_name          = "health_monitor_alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "S3BucketHealth"
  namespace           = "HealthMonitor"
  period              = 3600
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "This alarm triggers when S3 bucket deletion or access permission failures."
  alarm_actions       = [aws_sns_topic.sns_topic.arn]
  treat_missing_data  = "notBreaching"
}