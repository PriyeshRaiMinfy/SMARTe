#=================================================================
# SMARTe Inc. AWS Infrastructure - Main Configuration
# Project: GCP to AWS Migration
#=================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "SMARTe-Migration"
      ManagedBy   = "Terraform"
      Environment = var.environment
      Owner       = "DevOps-Team"
    }
  }
}
