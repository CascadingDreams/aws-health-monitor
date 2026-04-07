terraform {
  backend "s3" {
    bucket = "health-monitor-tool-bucket"
    key    = "health-monitor/terraform.tfstate"
    region = "ap-southeast-2"
  }
}