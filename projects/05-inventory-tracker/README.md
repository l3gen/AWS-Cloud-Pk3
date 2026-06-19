# Project 5 — AI Inventory Tracker

## Problem
Businesses run out of hot items or tie up cash in dead stock because
decisions are made on gut, not data. This project tracks inventory via API,
runs a daily check, and uses Amazon Bedrock (Claude) to give AI-powered
restock recommendations.

## What gets built
| Resource | Purpose |
|----------|---------|
| API Gateway | CRUD endpoints for inventory items |
| Lambda | Handles API + AI advice + daily checks |
| DynamoDB | Stores all inventory items and quantities |
| Amazon Bedrock (Claude) | AI-powered restock recommendations |
| EventBridge | Triggers daily stock level check at 7am |
| SNS | Alerts when items fall below threshold |

## Architecture
```
App / Dashboard
        │
        ▼ POST/GET /items  GET /advice
  API Gateway
        │
        ▼
    Lambda
    ├── CRUD: add items, update quantities
    ├── GET /advice:
    │   ├── Scans DynamoDB for low-stock items
    │   └── Calls Bedrock (Claude Haiku)
    │       → "Widget A: 2 days remaining. Restock 50 units. CRITICAL"
    │
EventBridge (7am daily)
        │
        ▼
    Lambda → daily_check()
    ├── Finds all items below threshold
    ├── Gets AI advice
        │
        ▼
    SNS → Email with AI restock plan

## What you learn
- Amazon Bedrock API (LLM inference from Lambda)
- DynamoDB Scan vs Query patterns
- REST API routing in a single Lambda handler
- Decimal type handling in DynamoDB
- Combining scheduled + API-triggered Lambda

## Deploy
```bash
terraform apply -var="alert_email=you@email.com"
```
Enable Bedrock model access first:
AWS Console → Bedrock → Model Access → Enable Claude Haiku

## Test it
```bash
# Add items
curl -X POST <api_endpoint>/items -d '{"name":"Widget A","quantity":8,"daily_sales_avg":3}'
curl -X POST <api_endpoint>/items -d '{"name":"Gadget B","quantity":3,"daily_sales_avg":5}'

# Get AI advice
curl <api_endpoint>/advice
# Returns: "Widget A: ~2 days remaining. Restock 50 units. CRITICAL"
```

## Talking points for interviews
> "Project 5 is an inventory tracking API on AWS. Lambda handles all the
> CRUD, DynamoDB stores inventory, and EventBridge runs a daily check.
> The interesting part is the GET /advice endpoint — it pulls all low-stock
> items and calls Amazon Bedrock with Claude to generate a prioritized
> restock plan. It's a real AI integration, not a demo — it actually reads
> your data and makes specific recommendations."
