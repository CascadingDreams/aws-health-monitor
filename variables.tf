# variables

variable "region" {
    type = string
    description = "AWS region"
}

variable "bucket_name" {
    type = string
    description = "Your s3 Bucket name"
}

variable "email_address" {
    type = string
    description = "Email address for SNS alerts"
}