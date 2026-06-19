terraform {
  backend "s3" {
    bucket = "tfstate-cloud-portfolio-${YOUR_ACCOUNT_ID}"
    key    = "04-inquiry-manager/terraform.tfstate"
    region = "us-east-1"
  }
}
