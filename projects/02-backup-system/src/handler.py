import boto3, os
from datetime import datetime, timedelta, timezone

s3    = boto3.client("s3")
sns   = boto3.client("sns")

BUCKET = os.environ["BUCKET_NAME"]
TOPIC  = os.environ["SNS_TOPIC_ARN"]
PREFIX = os.environ.get("BACKUP_PREFIX", "")

def lambda_handler(event, context):
    today     = datetime.now(timezone.utc)
    yesterday = today - timedelta(days=1)

    paginator = s3.get_paginator("list_object_versions")
    new_files, total_size = [], 0

    for page in paginator.paginate(Bucket=BUCKET, Prefix=PREFIX):
        for v in page.get("Versions", []):
            if v["IsLatest"] and v["LastModified"] >= yesterday:
                new_files.append(v)
                total_size += v["Size"]

    size_mb = total_size / (1024 * 1024)
    lines = [
        f"Daily Backup Report — {today.date()}",
        f"Bucket: {BUCKET}",
        f"New/updated files in last 24h: {len(new_files)}",
        f"Total size of new data: {size_mb:.2f} MB",
        "",
    ]
    if new_files:
        lines.append("Recent files:")
        for f in sorted(new_files, key=lambda x: x["LastModified"], reverse=True)[:10]:
            lines.append(f"  {f['Key']}  ({f['Size']/1024:.1f} KB)")
    else:
        lines.append("No new files uploaded in the last 24 hours.")

    message = "\n".join(lines)
    print(message)
    sns.publish(
        TopicArn=TOPIC,
        Subject=f"Backup Report {today.date()} — {len(new_files)} files",
        Message=message
    )
    return {"statusCode": 200, "body": message}
