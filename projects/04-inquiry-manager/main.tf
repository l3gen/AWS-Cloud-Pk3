terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.0" }
  }
}

provider "aws" { region = var.aws_region }

data "aws_caller_identity" "current" {}

# ── DynamoDB table for inquiries ────────────────────────────────────────────
resource "aws_dynamodb_table" "inquiries" {
  name         = "${var.project_name}-inquiries"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "inquiry_id"

  attribute { name = "inquiry_id", type = "S" }

  ttl { attribute_name = "expires_at", enabled = true }

  tags = { Project = var.project_name }
}

# ── SNS for urgent alerts ───────────────────────────────────────────────────
resource "aws_sns_topic" "urgent_alerts" {
  name = "${var.project_name}-urgent"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.urgent_alerts.arn
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
        "dynamodb:Scan", "dynamodb:UpdateItem"],
        Resource = aws_dynamodb_table.inquiries.arn },
      { Effect = "Allow", Action = "sns:Publish",
        Resource = aws_sns_topic.urgent_alerts.arn },
      { Effect = "Allow", Action = ["comprehend:DetectSentiment",
        "comprehend:DetectKeyPhrases"], Resource = "*" }
    ]
  })
}

# ── Lambda: inquiry processor ───────────────────────────────────────────────
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/handler.py"
  output_path = "${path.module}/src/handler.zip"
}

resource "aws_lambda_function" "inquiry_processor" {
  function_name    = "${var.project_name}-processor"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 30

  environment {
    variables = {
      TABLE_NAME    = aws_dynamodb_table.inquiries.name
      SNS_TOPIC_ARN = aws_sns_topic.urgent_alerts.arn
      AWS_REGION_   = var.aws_region
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.inquiry_processor.function_name}"
  retention_in_days = 14
}

# ── API Gateway: POST /inquiry ──────────────────────────────────────────────
resource "aws_apigatewayv2_api" "inquiry_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.inquiry_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.inquiry_processor.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_inquiry" {
  api_id    = aws_apigatewayv2_api.inquiry_api.id
  route_key = "POST /inquiry"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.inquiry_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inquiry_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.inquiry_api.execution_arn}/*/*"
}
