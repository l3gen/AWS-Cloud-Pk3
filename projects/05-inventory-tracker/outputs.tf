output "api_endpoint"     { value = aws_apigatewayv2_api.inventory_api.api_endpoint }
output "inventory_table"  { value = aws_dynamodb_table.inventory.name }

output "add_item_example" {
  value = "curl -X POST ${aws_apigatewayv2_api.inventory_api.api_endpoint}/items -H 'Content-Type: application/json' -d '{"name":"Widget A","quantity":8,"category":"electronics","daily_sales_avg":3}'"
}

output "get_ai_advice_example" {
  value = "curl ${aws_apigatewayv2_api.inventory_api.api_endpoint}/advice"
}
