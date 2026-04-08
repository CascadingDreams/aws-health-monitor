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

