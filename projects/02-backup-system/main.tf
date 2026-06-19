terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.0" }
  }
}

provider "aws" { region = var.aws_region }

data "aws_caller_identity" "current" {}

# ── Primary backup bucket ───────────────────────────────────────────────────
resource "aws_s3_bucket" "backup" {
  bucket        = "${var.project_name}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket                  = aws_s3_bucket.backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── Lifecycle: move to IA after 30 days, Glacier after 90, delete at 365 ───
resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "backup-lifecycle"
    status = "Enabled"
    filter { prefix = var.backup_prefix }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    expiration { days = 365 }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }
    noncurrent_version_expiration { noncurrent_days = 90 }
  }
}

# ── SNS for daily confirmation ──────────────────────────────────────────────
resource "aws_sns_topic" "backup_alerts" {
  name = "${var.project_name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.backup_alerts.arn
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
      { Effect = "Allow", Action = ["s3:ListBucket", "s3:GetBucketVersioning",
        "s3:ListBucketVersions"], Resource = aws_s3_bucket.backup.arn },
      { Effect = "Allow", Action = "sns:Publish",
        Resource = aws_sns_topic.backup_alerts.arn }
    ]
  })
}

# ── Lambda: daily summary ───────────────────────────────────────────────────
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/handler.py"
  output_path = "${path.module}/src/handler.zip"
}

resource "aws_lambda_function" "backup_notifier" {
  function_name    = "${var.project_name}-notifier"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 60

  environment {
    variables = {
      BUCKET_NAME   = aws_s3_bucket.backup.id
      SNS_TOPIC_ARN = aws_sns_topic.backup_alerts.arn
      BACKUP_PREFIX = var.backup_prefix
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.backup_notifier.function_name}"
  retention_in_days = 14
}

# ── EventBridge: daily 9am UTC ─────────────────────────────────────────────
resource "aws_cloudwatch_event_rule" "daily" {
  name                = "${var.project_name}-daily"
  schedule_expression = "cron(0 9 * * ? *)"
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.daily.name
  arn  = aws_lambda_function.backup_notifier.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backup_notifier.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily.arn
}
