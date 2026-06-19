terraform {
  backend "s3" {
    bucket = "tfstate-cloud-portfolio-${YOUR_ACCOUNT_ID}"
    key    = "02-backup-system/terraform.tfstate"
    region = "us-east-1"
  }
}
