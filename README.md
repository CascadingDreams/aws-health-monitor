# aws-health-monitor

Serverless AWS infrastructure health monitor built with Python and Terraform.

A Lambda function runs on an hourly schedule, checks S3 bucket availability, publishes a custom metric to CloudWatch, and sends an SNS email alert when the bucket is unreachable. All infrastructure is provisioned as code using Terraform.

---

## Architecture
```
EventBridge (hourly) → Lambda (Python) → S3 head_bucket check
                                        → CloudWatch custom metric
                                        → SNS email alert (on failure)
```

**CloudWatch alarm** watches the `HealthMonitor/S3BucketHealth` metric and triggers when the minimum value drops below 1 in a 3600-second period.

---

## Stack

| Layer | Technology |
|---|---|
| Language | Python 3.12 |
| AWS SDK | boto3 |
| Compute | AWS Lambda |
| Scheduling | EventBridge |
| Storage | S3 |
| Observability | CloudWatch Logs + Metrics + Alarms |
| Alerting | SNS → email |
| IaC | Terraform |
| State backend | S3 |

---

## What it monitors

Uses `head_bucket` to check S3 bucket availability every hour. Publishes:

- `1` — bucket exists and is reachable
- `0` — bucket is unreachable (deleted, permission failure, or service issue)

The CloudWatch alarm triggers when the metric value drops below `1`, sending an email via SNS.

---

## Screenshots

**Lambda function with EventBridge trigger**
![Lambda and EventBridge](docs/screenshots/Lambda%20and%20eventbridge%20in%20aws%20console.png)

**EventBridge scheduled rule — fixed rate of 1 hour**
![EventBridge scheduled rule](docs/screenshots/eventbridge%20scheduled%20rule.png)

**CloudWatch dashboard — S3BucketHealth metric and alarm status**
![CloudWatch dashboard](docs/screenshots/cloudwatch%20dashboard.png)

**SNS email alert when the alarm fires**
![SNS alert](docs/screenshots/sns%20alert.png)

---

## Prerequisites

- AWS account with programmatic access
- Terraform installed (`>= 1.0`)
- An S3 bucket for Terraform remote state — **create this manually before running Terraform** (bootstrap requirement; everything else is managed by Terraform)
- AWS credentials configured (`~/.aws/credentials` or environment variables)

---

## Deploy

**1. Clone the repo**
```bash
git clone https://github.com/CascadingDreams/aws-health-monitor.git
cd aws-health-monitor
```

**2. Copy and fill in variables**
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
region        = "ap-southeast-2"
bucket_name   = "your-bucket-name"
email_address = "your@email.com"
```

**3. Initialise and apply**
```bash
terraform init
terraform plan
terraform apply
```

**4. Confirm SNS subscription**

Check your email and click the confirmation link from AWS Notifications — alerts won't send until this is done.

---

## IAM design

Two-role structure:

- **`terraform_admin`** — IAM user with AdministratorAccess, used only to run Terraform. No console access, programmatic access only. Its access keys are what you store as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in GitHub Actions secrets.
- **`lambda_exec_role`** — IAM role assumed by Lambda at runtime. Scoped inline policy grants only what the function needs:
  - `s3:ListBucket`, `s3:GetObject` on the monitored bucket
  - `sns:Publish` on the health monitor topic
  - `cloudwatch:PutMetricData`, `logs:*` for observability

**Recommended: replicate this setup.** When creating the `terraform_admin` user in the AWS console, select **programmatic access only** (no AWS Management Console access). This limits the blast radius if the credentials are ever leaked — an attacker gets API access but cannot log in to the console.

### Least privilege

The project applies least privilege at every layer — each identity gets only the permissions it needs to do its specific job, nothing more.

**`terraform_admin` (IAM user)**
Broad `AdministratorAccess` is intentional here — Terraform needs to create and destroy arbitrary infrastructure. The risk is contained by removing console access, so the credentials only work via API, and by never embedding them in code (stored as GitHub Actions secrets only).

**`lambda_exec_role` (IAM role)**
The Lambda function has a tightly scoped inline policy with three statements:

| Permission | Resource | Why |
|---|---|---|
| `s3:ListBucket`, `s3:GetObject` | The monitored bucket only | Enough to run `head_bucket`; no write access, no access to other buckets |
| `sns:Publish` | The health monitor topic ARN only | Can only publish to this one topic; cannot create, delete, or subscribe |
| `cloudwatch:PutMetricData`, `logs:*` | `*` (required by CloudWatch/Logs) | Standard Lambda observability permissions; no ability to read or delete metrics/logs |

The role uses an inline policy rather than a managed policy — it belongs to this role only and cannot be accidentally attached elsewhere. The trust policy restricts `sts:AssumeRole` to `lambda.amazonaws.com`, so no other service or user can assume it.

---

## Test the alarm

Force the alarm into ALARM state without waiting for a real failure:

```bash
aws cloudwatch set-alarm-state \
  --alarm-name "health_monitor_alarm" \
  --state-value ALARM \
  --state-reason "Testing alarm notification" \
  --region ap-southeast-2
```

Reset:

```bash
aws cloudwatch set-alarm-state \
  --alarm-name "health_monitor_alarm" \
  --state-value OK \
  --state-reason "Resetting after test" \
  --region ap-southeast-2
```

---

## Tear down

```bash
terraform destroy
```

Note: the S3 state bucket was created manually and must be deleted manually.

---

## Key design decisions

**Why Sydney (ap-southeast-2) not Melbourne (ap-southeast-4)?**
Terraform's S3 backend has a known compatibility issue with ap-southeast-4. Switched to Sydney to unblock — a real-world tradeoff between ideal and pragmatic.

**Why inline IAM policy not managed policy?**
The policy belongs to this role specifically and won't be reused. Inline is simpler and easier to reason about for a single-purpose project.

**Why `rate(1 hour)` not `rate(5 minutes)`?**
A 5-minute schedule is appropriate for tight production SLAs. Hourly is sufficient for a dev health monitor and demonstrates intentional scheduling rather than defaulting to the most frequent option.

**Why `Minimum` as the CloudWatch statistic?**
One data point per hour, value is either 1 or 0. `Minimum` is semantically correct — if the minimum in the period is 0, a failure occurred.

**Why `notBreaching` for missing data?**
Avoids false alarms on first deploy before the Lambda has run and published its first data point.

---

## Roadmap

- [x] GitHub Actions CI pipeline (lint, validate, plan on PR)
- [ ] Runbook

---

## GitHub Actions setup

The CI pipeline requires three secrets added to your repo under **Settings > Secrets and variables > Actions > New repository secret**:

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access key ID for the `terraform_admin` IAM user |
| `AWS_SECRET_ACCESS_KEY` | Secret access key for the `terraform_admin` IAM user |
| `TF_VAR_EMAIL` | Email address to receive SNS health alert notifications |

`TF_VAR_EMAIL` is automatically mapped to the `email_address` Terraform variable via the `TF_VAR_` prefix convention.

---

## Author

[Samantha Hill](https://samanthahill.dev) · [LinkedIn](https://www.linkedin.com/in/sammy-hill-173078142/) · contact@samanthahill.dev
