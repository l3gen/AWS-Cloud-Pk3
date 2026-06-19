# Project 3 — Website Uptime Monitor

## Problem
The site goes down and the owner finds out from an angry customer tweet.
This project checks your site every 5 minutes from Lambda AND uses
Route53 health checks (AWS global network) for redundancy, alerting via
email and SMS the moment something fails.

## What gets built
| Resource | Purpose |
|----------|---------|
| Lambda | HTTP checker — tests URL, measures response time, publishes metrics |
| EventBridge (rate 5m) | Triggers Lambda every 5 minutes |
| Route53 Health Check | AWS-managed check from 18 global locations |
| CloudWatch Alarm | Fires on Route53 health check failure |
| SNS (email + SMS) | Sends alert within seconds of failure |
| CloudWatch Metrics | Custom IsUp and ResponseTimeMs metrics |

## Architecture
```
EventBridge (every 5 min)
        │
        ▼
    Lambda
    ├── HTTP GET each URL
    ├── Records response time
    ├── Publishes IsUp / ResponseTimeMs to CloudWatch
    │
    └── If down: SNS → Email + SMS "SITE DOWN ALERT"

Route53 Health Check (AWS global)
    ├── Checks from 18 AWS regions
        │
        ▼
CloudWatch Alarm → SNS → Email + SMS
```

## What you learn
- Custom CloudWatch metrics from Lambda
- Route53 health checks as a service
- CloudWatch Alarms and alarm actions
- SNS SMS subscriptions
- Multi-layer monitoring (Lambda check + AWS-native check)

## Deploy
```bash
terraform apply \
  -var="alert_email=you@email.com" \
  -var="alert_phone=+15551234567" \
  -var='urls_to_monitor=["https://yoursite.com","https://yoursite.com/health"]'
```

## Talking points for interviews
> "I built a two-layer uptime monitor. Lambda checks the site every 5
> minutes and publishes response time metrics to CloudWatch. Route53 health
> checks run from AWS's global network. If either layer detects a failure,
> SNS fires an email and SMS within 60 seconds. The whole thing is Terraform
> — spin it up for any domain in under 2 minutes."
