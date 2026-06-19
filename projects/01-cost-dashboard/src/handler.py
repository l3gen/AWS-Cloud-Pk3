import boto3, json, os
from datetime import datetime, timedelta

ce     = boto3.client("ce",  region_name="us-east-1")
sns    = boto3.client("sns")
TOPIC  = os.environ["SNS_TOPIC_ARN"]

def lambda_handler(event, context):
    today  = datetime.utcnow().date()
    start  = today.replace(day=1).isoformat()
    end    = today.isoformat()

    resp = ce.get_cost_and_usage(
        TimePeriod={"Start": start, "End": end},
        Granularity="MONTHLY",
        Metrics=["UnblendedCost"],
        GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}]
    )

    results   = resp["ResultsByTime"][0]
    total     = float(results["Total"]["UnblendedCost"]["Amount"])
    currency  = results["Total"]["UnblendedCost"]["Unit"]
    services  = sorted(
        [(g["Keys"][0], float(g["Metrics"]["UnblendedCost"]["Amount"]))
         for g in results["Groups"]],
        key=lambda x: x[1], reverse=True
    )

    lines = [
        f"Daily Cost Report — {today}",
        f"Month-to-date spend: {total:.2f} {currency}",
        "",
        "Top services:",
    ]
    for svc, cost in services[:8]:
        lines.append(f"  {svc:<40} ${cost:.4f}")

    message = "\n".join(lines)
    print(message)

    sns.publish(
        TopicArn=TOPIC,
        Subject=f"AWS Cost Report {today} — ${total:.2f}",
        Message=message
    )
    return {"statusCode": 200, "body": message}
