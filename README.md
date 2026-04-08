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

## Status

- [x] Terraform base config (S3 backend, SNS topic + subscription)
- [x] IAM role and scoped policy for Lambda
- [x] Lambda health check function
- [ ] EventBridge scheduled trigger
- [ ] CloudWatch alarm
- [ ] CloudWatch dashboard
- [ ] Runbook
- [ ] CI pipeline