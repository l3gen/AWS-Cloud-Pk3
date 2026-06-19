variable "aws_region"    { default = "us-east-1" }
variable "alert_email" {
  description = "Email for low-stock alerts"
  default     = "dw602481@gmail.com"
}
variable "project_name"  { default = "inventory-tracker" }
variable "low_stock_threshold" { default = 10 }
