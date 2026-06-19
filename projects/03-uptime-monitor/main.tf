terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.0" }
  }
}

provider "aws" { region = var.aws_region }

# ── SNS for alerts (email + SMS) ────────────────────────────────────────────
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "sms" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "sms"
  endpoint  = var.alert_phone
}

# ── IAM Role ────────────────────────────────────────────────────────────────
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream",
        "logs:PutLogEvents"], Resource = "arn:aws:logs:*:*:*" },
      { Effect = "Allow", Action = "sns:Publish",
        Resource = aws_sns_topic.alerts.arn },
      { Effect = "Allow", Action = ["cloudwatch:PutMetricData"],
        Resource = "*" }
    ]
  })
}

# ── Lambda: uptime checker ──────────────────────────────────────────────────
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/handler.py"
  output_path = "${path.module}/src/handler.zip"
}

resource "aws_lambda_function" "uptime_checker" {
  function_name    = "${var.project_name}-checker"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 30

  environment {
    variables = {
      URLS_TO_MONITOR = join(",", var.urls_to_monitor)
      SNS_TOPIC_ARN   = aws_sns_topic.alerts.arn
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.uptime_checker.function_name}"
  retention_in_days = 14
}

# ── EventBridge: every N minutes ───────────────────────────────────────────
resource "aws_cloudwatch_event_rule" "check_interval" {
  name                = "${var.project_name}-check"
  schedule_expression = "rate(${var.check_interval_minutes} minutes)"
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.check_interval.name
  arn  = aws_lambda_function.uptime_checker.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.uptime_checker.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.check_interval.arn
}

# ── Route53 Health Check (AWS-managed, global) ──────────────────────────────
resource "aws_route53_health_check" "primary" {
  fqdn              = replace(replace(var.urls_to_monitor[0], "https://", ""), "http://", "")
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30
  tags = { Name = "${var.project_name}-healthcheck" }
}

# ── CloudWatch Alarm on health check ───────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "site_down" {
  provider            = aws.us_east_1
  alarm_name          = "${var.project_name}-site-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Website health check failed"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary.id
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
