terraform {
  backend "s3" {
    bucket = "tfstate-cloud-portfolio-${YOUR_ACCOUNT_ID}"
    key    = "05-inventory-tracker/terraform.tfstate"
    region = "us-east-1"
  }
}
