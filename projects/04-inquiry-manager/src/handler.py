import boto3, json, os, uuid
from datetime import datetime, timezone, timedelta

dynamodb    = boto3.resource("dynamodb")
sns         = boto3.client("sns")
comprehend  = boto3.client("comprehend")

TABLE  = os.environ["TABLE_NAME"]
TOPIC  = os.environ["SNS_TOPIC_ARN"]
table  = dynamodb.Table(TABLE)

URGENT_KEYWORDS = ["urgent", "emergency", "broken", "down", "error",
                   "cannot", "asap", "immediately", "critical", "failure"]

def categorize(text):
    lower = text.lower()
    if any(k in lower for k in URGENT_KEYWORDS):
        return "URGENT"
    if any(k in lower for k in ["question", "how", "what", "?", "info"]):
        return "GENERAL_INQUIRY"
    if any(k in lower for k in ["buy", "price", "cost", "purchase", "quote"]):
        return "SALES"
    return "SUPPORT"

def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))
    except Exception:
        return {"statusCode": 400, "body": json.dumps({"error": "Invalid JSON"})}

    name    = body.get("name", "Unknown")
    email   = body.get("email", "")
    message = body.get("message", "")

    if not message:
        return {"statusCode": 400, "body": json.dumps({"error": "message is required"})}

    # AI sentiment analysis via Amazon Comprehend
    sentiment_resp = comprehend.detect_sentiment(Text=message[:5000], LanguageCode="en")
    sentiment      = sentiment_resp["Sentiment"]  # POSITIVE / NEGATIVE / NEUTRAL / MIXED

    category = categorize(message)

    # Store in DynamoDB
    inquiry_id = str(uuid.uuid4())
    item = {
        "inquiry_id": inquiry_id,
        "name":       name,
        "email":      email,
        "message":    message,
        "category":   category,
        "sentiment":  sentiment,
        "status":     "OPEN",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "expires_at": int((datetime.now(timezone.utc) + timedelta(days=90)).timestamp()),
    }
    table.put_item(Item=item)

    # Alert immediately for urgent inquiries
    if category == "URGENT" or sentiment == "NEGATIVE":
        sns.publish(
            TopicArn=TOPIC,
            Subject=f"[{category}] New inquiry from {name}",
            Message=f"Category: {category}\nSentiment: {sentiment}\n"
                    f"From: {name} <{email}>\n\n{message}\n\nID: {inquiry_id}"
        )

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "inquiry_id": inquiry_id,
            "category":   category,
            "sentiment":  sentiment,
            "message":    "Inquiry received. We will respond shortly."
        })
    }
