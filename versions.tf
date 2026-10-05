terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 6.39.0 added aws_organizations_aws_service_access.
      version = ">= 6.39.0"
    }
  }
}
