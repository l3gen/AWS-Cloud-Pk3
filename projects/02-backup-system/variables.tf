variable "aws_region"      { default = "us-east-1" }
variable "alert_email"     { description = "Email for daily backup confirmations" }
variable "project_name"    { default = "auto-backup" }
variable "backup_prefix"   { default = "uploads/" }
