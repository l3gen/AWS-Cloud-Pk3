terraform {
  backend "s3" {
    bucket = "tfstate-cloud-portfolio-374040432649"
    key    = "02-backup-system/terraform.tfstate"
    region = "us-east-1"
  }
}
