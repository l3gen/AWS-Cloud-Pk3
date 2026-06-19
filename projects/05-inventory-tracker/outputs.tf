output "api_endpoint" {
  value = aws_apigatewayv2_api.inventory_api.api_endpoint
}

output "inventory_table" {
  value = aws_dynamodb_table.inventory.name
}

output "add_item_example" {
  value = "curl -X POST <api_endpoint>/items with JSON body"
}

output "get_ai_advice_example" {
  value = "curl <api_endpoint>/advice"
}
