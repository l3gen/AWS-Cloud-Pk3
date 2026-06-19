terraform {
  backend "s3" {
    bucket = "tfstate-cloud-portfolio-${YOUR_ACCOUNT_ID}"
    key    = "03-uptime-monitor/terraform.tfstate"
    region = "us-east-1"
  }
}
