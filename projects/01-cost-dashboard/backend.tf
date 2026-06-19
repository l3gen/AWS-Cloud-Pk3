terraform {
  backend "s3" {
    bucket = "tfstate-cloud-portfolio-374040432649"
    key    = "01-cost-dashboard/terraform.tfstate"
    region = "us-east-1"
  }
}
