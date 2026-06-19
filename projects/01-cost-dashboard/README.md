# Project 1 — Cost Visibility Dashboard

## Problem
Business owners can't read, predict, or explain their cloud bill. A surprise
$5K invoice causes panic. This project gives you a daily email breakdown of
exactly what's spending money and alerts before you blow the budget.

## What gets built
| Resource | Purpose |
|----------|---------|
| AWS Budget | Alerts at 80% and 100% of monthly limit |
| Lambda (Python) | Queries Cost Explorer, formats report |
| EventBridge Rule | Triggers Lambda every day at 8am UTC |
| SNS Topic + Email | Delivers the report to your inbox |
| CloudWatch Dashboard | Visual cost chart in the console |

## Architecture
```
EventBridge (daily 8am)
        │
        ▼
    Lambda
    ├── Calls Cost Explorer API
    ├── Formats cost-by-service breakdown
        │
        ▼
    SNS Topic ──→ Email: "AWS Cost Report — $12.47"

AWS Budgets ────→ SNS Topic ──→ Email: "You've hit 80% of budget"
```

## What you learn
- IAM least-privilege roles for Lambda
- Cost Explorer API (ce:GetCostAndUsage)
- EventBridge cron scheduling
- SNS email subscriptions
- CloudWatch Dashboards as code

## Deploy
```bash
terraform init
terraform apply -var="alert_email=you@email.com" -var="monthly_budget=50"
```
Check your email — confirm the SNS subscription, then trigger the Lambda
manually to see your first report immediately.

## Talking points for interviews
> "I built a cost alerting system on AWS that queries Cost Explorer daily,
> breaks spend down by service, and emails a report automatically. It also
> has budget alerts at 80% and 100% so nothing is a surprise. All of it is
> Terraform — you can deploy it or destroy it in one command."
