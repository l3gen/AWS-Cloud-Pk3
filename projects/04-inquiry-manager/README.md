# Project 4 — Customer Inquiry Manager

## Problem
As a business grows, leads and urgent requests get buried in the inbox.
Sales leads sit unread next to spam. Urgent issues look the same as
general questions. This project uses AI to categorize every inquiry and
immediately escalate urgent ones.

## What gets built
| Resource | Purpose |
|----------|---------|
| API Gateway (HTTP) | Receives POST /inquiry from any form or app |
| Lambda | Categorizes, analyzes sentiment, stores, routes |
| Amazon Comprehend | AI sentiment analysis (POSITIVE/NEGATIVE/NEUTRAL) |
| DynamoDB | Stores all inquiries with category + sentiment |
| SNS | Alerts on URGENT or NEGATIVE sentiment inquiries |

## Architecture
```
Contact Form / App
        │
        ▼ POST /inquiry
  API Gateway
        │
        ▼
    Lambda
    ├── Comprehend: DetectSentiment (AI)
    ├── Rule-based: categorize (URGENT / SALES / SUPPORT / GENERAL)
    ├── DynamoDB: store inquiry + metadata
    │
    └── If URGENT or NEGATIVE sentiment:
        SNS → Email "[URGENT] New inquiry from John"
```

## What you learn
- API Gateway v2 (HTTP API) with Lambda integration
- DynamoDB single-table design with TTL
- Amazon Comprehend for NLP/AI without writing ML code
- Event-driven routing with SNS
- JSON body parsing in Lambda

## Test it
After deploy, `terraform output test_command` gives you a curl command to
submit a test inquiry. Try sending an urgent-sounding message and watch
the alert arrive in under 10 seconds.

## Talking points for interviews
> "I built an inquiry routing system using API Gateway, Lambda, and
> Amazon Comprehend. Every contact form submission gets sentiment analysis
> and keyword categorization. Urgent or negative inquiries trigger an
> immediate SNS alert. Everything is stored in DynamoDB. The business
> never misses a critical message again."
