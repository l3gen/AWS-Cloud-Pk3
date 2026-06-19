terraform {
  backend "s3" {
    bucket = "tfstate-cloud-portfolio-374040432649"
    key    = "04-inquiry-manager/terraform.tfstate"
    region = "us-east-1"
  }
}
