terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Must stay below 6.23.0 for the emulator (S3 Control host prefix):
      # https://github.com/aws/aws-emulator/issues/56
      version = "~> 6.22.0"
    }
  }
}
