variable "aws_region"      { default = "us-east-1" }
variable "alert_email" {
  description = "Email for downtime alerts"
  default     = "dw602481@gmail.com"
}
variable "alert_phone" {
  description = "Phone number for SMS"
  default     = ""
}
variable "project_name"    { default = "uptime-monitor" }
variable "urls_to_monitor" {
  type    = list(string)
  default = ["https://example.com", "https://example.com/health"]
}
variable "check_interval_minutes" { default = 5 }
