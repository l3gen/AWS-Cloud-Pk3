# Project 2 — Automated Backup System

## Problem
Backups depend on someone remembering. One missed backup + one bad deploy
= permanent data loss. This project automates S3 versioning, moves old
data to cheaper storage automatically, and sends a daily confirmation email.

## What gets built
| Resource | Purpose |
|----------|---------|
| S3 Bucket (versioned + encrypted) | Stores every version of every file |
| Lifecycle Policy | Moves data: Standard → IA (30d) → Glacier (90d) → Delete (365d) |
| Lambda | Lists yesterday's uploads, formats summary |
| EventBridge | Triggers Lambda every morning |
| SNS Email | Delivers "X files backed up, Y MB" confirmation |

## Architecture
```
Your app uploads files
        │
        ▼
  S3 Bucket (versioned + AES256)
  └── Lifecycle automatically tiers storage by age

EventBridge (daily 9am)
        │
        ▼
    Lambda
    ├── Lists files modified in last 24h
    ├── Calculates total size
        │
        ▼
    SNS ──→ Email: "Backup Report: 47 files, 123 MB"
```

## What you learn
- S3 versioning and what it protects you from
- Lifecycle policies and storage cost tiers (Standard / IA / Glacier)
- How to use the S3 API from Lambda
- EventBridge scheduling patterns

## Deploy
```bash
terraform init
terraform apply -var="alert_email=you@email.com"
```

## Talking points for interviews
> "I built a backup system on S3 with versioning so every file change is
> preserved. Lifecycle rules automatically move old data to Glacier to cut
> storage costs by 80%. A Lambda runs every morning and emails a summary
> of exactly what was backed up — so silence means something is wrong."
