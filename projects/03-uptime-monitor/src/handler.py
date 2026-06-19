import urllib.request, urllib.error, boto3, json, os, time

sns   = boto3.client("sns")
cw    = boto3.client("cloudwatch")
TOPIC = os.environ["SNS_TOPIC_ARN"]
URLS  = [u.strip() for u in os.environ["URLS_TO_MONITOR"].split(",")]

def check_url(url):
    start = time.time()
    try:
        req  = urllib.request.Request(url, headers={"User-Agent": "UptimeMonitor/1.0"})
        resp = urllib.request.urlopen(req, timeout=10)
        ms   = int((time.time() - start) * 1000)
        return {"url": url, "status": resp.status, "ms": ms, "ok": resp.status < 400}
    except Exception as e:
        ms = int((time.time() - start) * 1000)
        return {"url": url, "status": 0, "ms": ms, "ok": False, "error": str(e)}

def lambda_handler(event, context):
    results = [check_url(u) for u in URLS]
    failed  = [r for r in results if not r["ok"]]

    # Publish custom CloudWatch metrics
    metric_data = []
    for r in results:
        safe_url = r["url"].replace("https://", "").replace("http://", "").replace("/", "_")
        metric_data += [
            {"MetricName": "ResponseTimeMs", "Dimensions": [{"Name": "URL", "Value": r["url"]}],
             "Value": r["ms"], "Unit": "Milliseconds"},
            {"MetricName": "IsUp", "Dimensions": [{"Name": "URL", "Value": r["url"]}],
             "Value": 1 if r["ok"] else 0, "Unit": "Count"},
        ]
    cw.put_metric_data(Namespace="UptimeMonitor", MetricData=metric_data)

    # Alert on failures
    if failed:
        lines = ["ALERT: Website Down\n"]
        for r in failed:
            lines.append(f"URL: {r['url']}")
            lines.append(f"Status: {r['status']}")
            lines.append(f"Error: {r.get('error', 'Non-2xx response')}")
            lines.append(f"Response time: {r['ms']}ms\n")
        sns.publish(TopicArn=TOPIC, Subject="SITE DOWN ALERT",
                    Message="\n".join(lines))

    print(json.dumps(results))
    return {"statusCode": 200, "results": results}
