# Cloud Engineering Portfolio — AWS

Five production-style AWS projects, each provisioned with Terraform and
deployed automatically via GitHub Actions. Every push to `main` triggers a
`terraform apply`; every PR shows the plan as a comment; a manual workflow
button destroys everything cleanly.

## Why these projects?

These aren't hello-world demos. Each one solves a real problem a real
business has. That's what makes them land in interviews.

| # | Project | Problem Solved | Core AWS Services |
|---|---------|---------------|-------------------|
| 1 | [Cost Visibility Dashboard](projects/01-cost-dashboard) | Owners can't read or predict their cloud bill | Cost Explorer · Budgets · Lambda · SNS · CloudWatch |
| 2 | [Automated Backup System](projects/02-backup-system) | Backups depend on someone remembering | S3 Versioning · Lifecycle · Lambda · EventBridge · SNS |
| 3 | [Website Uptime Monitor](projects/03-uptime-monitor) | Site goes down, owner hears from a customer | Lambda · EventBridge · Route53 Health Check · SNS |
| 4 | [Customer Inquiry Manager](projects/04-inquiry-manager) | Leads get buried in the inbox | API Gateway · Lambda · DynamoDB · Comprehend · SES |
| 5 | [AI Inventory Tracker](projects/05-inventory-tracker) | Stock decisions made on gut, not data | Lambda · DynamoDB · Bedrock · API Gateway · SNS |

## How CI/CD works

```
Push to feature branch
        │
        ▼
  GitHub Actions runs terraform plan
  → Posts full plan as PR comment          ← reviewers see EXACTLY what changes
        │
        ▼
  Merge to main
        │
        ▼
  GitHub Actions runs terraform apply
  → Resources created/updated in AWS       ← pipeline proves you built something
        │
        ▼
  Manual workflow: "Destroy"
        │
        ▼
  terraform destroy -auto-approve           ← clean teardown, zero orphaned resources
```

## Prerequisites

1. AWS account
2. GitHub repository (fork or push this repo)
3. Run the bootstrap once to create the S3 state bucket and OIDC role:
   ```bash
   cd bootstrap
   terraform init && terraform apply
   ```
4. Add these to GitHub → Settings → Secrets and Variables:
   - **Secret**: `AWS_ACCOUNT_ID`
   - **Variable**: `AWS_REGION` (e.g. `us-east-1`)

## Deploy a single project manually

```bash
cd projects/01-cost-dashboard
terraform init
terraform plan
terraform apply
terraform destroy   # tear it all down
```

## Learning path

Work through projects in order. Each one adds a new AWS service on top of
what came before. By project 5 you have touched IAM, Lambda, EventBridge,
S3, API Gateway, DynamoDB, SNS, SES, Comprehend, Bedrock, Route53, and
CloudWatch — plus Terraform and GitHub Actions CI/CD.
