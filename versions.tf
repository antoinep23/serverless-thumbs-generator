terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-west-3"
  default_tags {
    tags = {
      App = "thumbs-generator-app"
    }
  }
}