# aws-health-monitor

> 🚧 Work in progress — actively under development.

A serverless AWS infrastructure health monitor. A Python Lambda function 
runs on a schedule, checks S3 bucket availability, publishes custom metrics 
to CloudWatch, and sends email alerts via SNS when something is unhealthy. 
All infrastructure is provisioned with Terraform.

| Layer | Service |
|---|---|
| Compute | AWS Lambda |
| Scheduling | EventBridge |
| Storage | S3 |
| Observability | CloudWatch Logs + Metrics + Alarms |
| Alerting | SNS → email |
| IaC | Terraform (S3 remote backend) |

## Prerequisites

- AWS CLI configured with a `terraform_admin` IAM user
- Terraform >= 1.9
- Python 3.12

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# fill in your values

terraform init
terraform plan
terraform apply
```

## How it works

1. **EventBridge** triggers the Lambda on an hourly schedule (`rate(1 hour)`)
2. **Lambda** calls `s3:HeadBucket` on the monitored bucket — healthy = `1`, unhealthy = `0`
3. The result is pushed to **CloudWatch** as a custom metric (`HealthMonitor/S3BucketHealth`)
4. A **CloudWatch alarm** watches the metric; if it drops below `1`, it fires
5. The alarm publishes to an **SNS topic**, which sends an email alert to the configured address

## Status

- [x] Terraform base config (S3 backend, SNS topic + subscription)
- [x] IAM role and scoped policy for Lambda
- [x] Lambda health check function
- [x] EventBridge scheduled trigger (hourly)
- [x] CloudWatch alarm
- [ ] CloudWatch dashboard
- [ ] Runbook
- [ ] CI pipeline