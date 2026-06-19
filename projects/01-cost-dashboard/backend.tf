terraform {
  backend "s3" {
    bucket = "tfstate-cloud-portfolio-${YOUR_ACCOUNT_ID}"
    key    = "01-cost-dashboard/terraform.tfstate"
    region = "us-east-1"
  }
}
