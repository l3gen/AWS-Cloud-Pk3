import boto3, json, os, uuid
from datetime import datetime, timezone
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
sns      = boto3.client("sns")
bedrock  = boto3.client("bedrock-runtime", region_name="us-east-1")

TABLE     = os.environ["TABLE_NAME"]
TOPIC     = os.environ["SNS_TOPIC_ARN"]
THRESHOLD = int(os.environ.get("LOW_STOCK_THRESHOLD", "10"))
table     = dynamodb.Table(TABLE)

def decimal_default(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError

def get_ai_advice(low_stock_items):
    if not low_stock_items:
        return "All inventory levels are healthy."

    item_list = "\n".join(
        f"- {i['name']}: {i['quantity']} units remaining"
        for i in low_stock_items
    )

    prompt = (
        "You are an inventory management advisor.\n"
        "The following items are running low on stock:\n\n"
        f"{item_list}\n\n"
        "For each item provide: recommended restock quantity and urgency level (LOW/MEDIUM/HIGH/CRITICAL).\n"
        "Be concise. Format as a brief bullet list."
    )

    resp = bedrock.invoke_model(
        modelId="anthropic.claude-haiku-20240307-v1:0",
        body=json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 500,
            "messages": [{"role": "user", "content": prompt}]
        }),
        contentType="application/json",
        accept="application/json"
    )
    result = json.loads(resp["body"].read())
    return result["content"][0]["text"]

def lambda_handler(event, context):
    if event.get("action") == "daily_check":
        return daily_stock_check()

    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    path   = event.get("rawPath", "/")

    if path == "/items" and method == "POST":
        return add_item(json.loads(event.get("body", "{}")))
    elif path == "/items" and method == "GET":
        return list_items()
    elif path == "/advice" and method == "GET":
        return get_advice()
    elif path.startswith("/items/") and method == "PUT":
        item_id = path.split("/")[-1]
        return update_stock(item_id, json.loads(event.get("body", "{}")))
    else:
        return {"statusCode": 404, "body": json.dumps({"error": "Not found"})}

def add_item(body):
    item = {
        "item_id":   str(uuid.uuid4()),
        "name":      body.get("name", "Unnamed"),
        "quantity":  Decimal(str(body.get("quantity", 0))),
        "category":  body.get("category", "general"),
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    table.put_item(Item=item)
    return {"statusCode": 201, "body": json.dumps({"item_id": item["item_id"]})}

def list_items():
    resp  = table.scan()
    items = json.loads(json.dumps(resp["Items"], default=decimal_default))
    return {"statusCode": 200, "body": json.dumps(items)}

def update_stock(item_id, body):
    new_qty = Decimal(str(body.get("quantity", 0)))
    table.update_item(
        Key={"item_id": item_id},
        UpdateExpression="SET quantity = :q, updated_at = :u",
        ExpressionAttributeValues={":q": new_qty, ":u": datetime.now(timezone.utc).isoformat()}
    )
    return {"statusCode": 200, "body": json.dumps({"updated": True})}

def get_advice():
    resp      = table.scan()
    all_items = json.loads(json.dumps(resp["Items"], default=decimal_default))
    low_stock = [i for i in all_items if float(i.get("quantity", 0)) <= THRESHOLD]
    advice    = get_ai_advice(low_stock)
    return {"statusCode": 200, "body": json.dumps({"low_stock_count": len(low_stock), "advice": advice})}

def daily_stock_check():
    resp      = table.scan()
    all_items = json.loads(json.dumps(resp["Items"], default=decimal_default))
    low_stock = [i for i in all_items if float(i.get("quantity", 0)) <= THRESHOLD]
    if low_stock:
        advice = get_ai_advice(low_stock)
        msg = f"Daily Inventory Alert\n{len(low_stock)} items below threshold ({THRESHOLD} units)\n\nAI Advice:\n{advice}"
        sns.publish(TopicArn=TOPIC, Subject=f"Inventory Alert: {len(low_stock)} items low", Message=msg)
    return {"statusCode": 200, "body": json.dumps({"checked": len(all_items), "low_stock": len(low_stock)})}
