variable "aws_region"      { default = "us-east-1" }
variable "alert_email" {
  description = "Email for daily backup confirmations"
  default     = "dw602481@gmail.com"
}
variable "project_name"    { default = "auto-backup" }
variable "backup_prefix"   { default = "uploads/" }
