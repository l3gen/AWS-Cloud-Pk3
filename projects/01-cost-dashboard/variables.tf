variable "aws_region"      { default = "us-east-1" }
variable "alert_email"     { description = "Email to receive daily cost reports" }
variable "monthly_budget"  { default = 50 }
variable "project_name"    { default = "cost-dashboard" }
