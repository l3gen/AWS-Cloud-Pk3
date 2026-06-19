output "api_endpoint" {
  value = aws_apigatewayv2_api.inquiry_api.api_endpoint
}

output "inquiries_table" {
  value = aws_dynamodb_table.inquiries.name
}

output "submit_inquiry_example" {
  value = "curl -X POST <api_endpoint>/inquiry with JSON body containing name, email, message fields"
}

output "urgent_alerts_topic" {
  value = aws_sns_topic.urgent_alerts.arn
}
