output "backup_bucket"     { value = aws_s3_bucket.backup.id }
output "bucket_arn"        { value = aws_s3_bucket.backup.arn }
output "sns_topic_arn"     { value = aws_sns_topic.backup_alerts.arn }
output "lambda_function"   { value = aws_lambda_function.backup_notifier.function_name }
