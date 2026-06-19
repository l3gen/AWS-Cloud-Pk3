terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.0" }
  }
}

provider "aws" { region = var.aws_region }

data "aws_caller_identity" "current" {}

# ── SNS Topic for cost alerts ───────────────────────────────────────────────
resource "aws_sns_topic" "cost_alerts" {
  name = "${var.project_name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ── AWS Budget with alert at 80% and 100% ──────────────────────────────────
resource "aws_budgets_budget" "monthly" {
  name         = "${var.project_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_sns_topic_arns  = [aws_sns_topic.cost_alerts.arn]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_sns_topic_arns  = [aws_sns_topic.cost_alerts.arn]
  }
}

# ── IAM Role for Lambda ─────────────────────────────────────────────────────
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
      { Effect = "Allow", Action = ["ce:GetCostAndUsage", "ce:GetCostForecast"],
        Resource = "*" },
      { Effect = "Allow", Action = "sns:Publish",
        Resource = aws_sns_topic.cost_alerts.arn }
    ]
  })
}

# ── Lambda: daily cost report ───────────────────────────────────────────────
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/handler.py"
  output_path = "${path.module}/src/handler.zip"
}

resource "aws_lambda_function" "cost_reporter" {
  function_name    = "${var.project_name}-reporter"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 60

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.cost_alerts.arn
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.cost_reporter.function_name}"
  retention_in_days = 14
}

# ── EventBridge: run every day at 8am UTC ──────────────────────────────────
resource "aws_cloudwatch_event_rule" "daily_report" {
  name                = "${var.project_name}-daily"
  schedule_expression = "cron(0 8 * * ? *)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule = aws_cloudwatch_event_rule.daily_report.name
  arn  = aws_lambda_function.cost_reporter.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_reporter.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_report.arn
}

# ── CloudWatch Dashboard ────────────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "cost" {
  dashboard_name = "${var.project_name}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title   = "Estimated Charges"
          metrics = [["AWS/Billing", "EstimatedCharges", "Currency", "USD"]]
          period  = 86400, stat = "Maximum", region = "us-east-1"
          view    = "timeSeries"
        }
      }
    ]
  })
}
