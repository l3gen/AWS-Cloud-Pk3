output "sns_topic_arn"      { value = aws_sns_topic.alerts.arn }
output "lambda_function"    { value = aws_lambda_function.uptime_checker.function_name }
output "health_check_id"    { value = aws_route53_health_check.primary.id }
