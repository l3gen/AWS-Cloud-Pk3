output "sns_topic_arn"      { value = aws_sns_topic.cost_alerts.arn }
output "lambda_function"    { value = aws_lambda_function.cost_reporter.function_name }
output "dashboard_url" {
  value = "https://console.aws.amazon.com/cloudwatch/home#dashboards:name=${aws_cloudwatch_dashboard.cost.dashboard_name}"
}
