output "api_endpoint"      { value = aws_apigatewayv2_api.inquiry_api.api_endpoint }
output "inquiries_table"   { value = aws_dynamodb_table.inquiries.name }
output "sns_topic_arn"     { value = aws_sns_topic.urgent_alerts.arn }

output "test_command" {
  value = "curl -X POST ${aws_apigatewayv2_api.inquiry_api.api_endpoint}/inquiry -H 'Content-Type: application/json' -d '{"name":"John","email":"john@example.com","message":"URGENT: your site is down and we cannot process orders!"}'"
}
