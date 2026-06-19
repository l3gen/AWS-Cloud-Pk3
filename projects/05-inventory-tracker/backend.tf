terraform {
  backend "s3" {
    bucket = "tfstate-cloud-portfolio-374040432649"
    key    = "05-inventory-tracker/terraform.tfstate"
    region = "us-east-1"
  }
}
