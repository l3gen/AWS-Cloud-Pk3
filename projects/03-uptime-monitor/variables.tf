variable "aws_region"      { default = "us-east-1" }
variable "alert_email"     { description = "Email for downtime alerts" }
variable "alert_phone"     { description = "Phone number for SMS (e.g. +15551234567)" }
variable "project_name"    { default = "uptime-monitor" }
variable "urls_to_monitor" {
  type    = list(string)
  default = ["https://example.com", "https://example.com/health"]
}
variable "check_interval_minutes" { default = 5 }
