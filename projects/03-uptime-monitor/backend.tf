terraform {
  backend "s3" {
    bucket = "tfstate-cloud-portfolio-374040432649"
    key    = "03-uptime-monitor/terraform.tfstate"
    region = "us-east-1"
  }
}
