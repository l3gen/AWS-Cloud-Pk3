terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.0" }
  }
}

provider "aws" { region = var.aws_region }

data "aws_caller_identity" "current" {}

# ── DynamoDB: inventory table ───────────────────────────────────────────────
resource "aws_dynamodb_table" "inventory" {
  name         = "${var.project_name}-items"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "item_id"

  attribute { name = "item_id", type = "S" }

  tags = { Project = var.project_name }
}

# ── SNS for restock alerts ──────────────────────────────────────────────────
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
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
      { Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:GetItem",
        "dynamodb:Scan", "dynamodb:UpdateItem", "dynamodb:DeleteItem"],
        Resource = aws_dynamodb_table.inventory.arn },
      { Effect = "Allow", Action = "sns:Publish",
        Resource = aws_sns_topic.alerts.arn },
      { Effect = "Allow", Action = "bedrock:InvokeModel",
        Resource = "arn:aws:bedrock:*::foundation-model/anthropic.claude-haiku-*" }
    ]
  })
}

# ── Lambda: inventory tracker + AI restock advisor ─────────────────────────
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/handler.py"
  output_path = "${path.module}/src/handler.zip"
}

resource "aws_lambda_function" "tracker" {
  function_name    = "${var.project_name}-tracker"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      TABLE_NAME      = aws_dynamodb_table.inventory.name
      SNS_TOPIC_ARN   = aws_sns_topic.alerts.arn
      LOW_STOCK_THRESHOLD = tostring(var.low_stock_threshold)
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.tracker.function_name}"
  retention_in_days = 14
}

# ── API Gateway for inventory CRUD + AI advice ─────────────────────────────
resource "aws_apigatewayv2_api" "inventory_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.inventory_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.tracker.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "any" {
  api_id    = aws_apigatewayv2_api.inventory_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.inventory_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tracker.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.inventory_api.execution_arn}/*/*"
}

# ── EventBridge: daily stock check ─────────────────────────────────────────
resource "aws_cloudwatch_event_rule" "daily_check" {
  name                = "${var.project_name}-daily-check"
  schedule_expression = "cron(0 7 * * ? *)"
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule  = aws_cloudwatch_event_rule.daily_check.name
  arn   = aws_lambda_function.tracker.arn
  input = jsonencode({ "action": "daily_check" })
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tracker.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_check.arn
}
