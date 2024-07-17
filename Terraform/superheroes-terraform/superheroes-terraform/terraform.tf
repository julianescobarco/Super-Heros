terraform {
  backend "s3" {
    encrypt = true
    bucket = "terraform-provider-versioning"
    key = "superheroes/terraform.tfstate"
    region = "us-east-1"
  }
}
