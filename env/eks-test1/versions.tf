terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Must stay below 6.23.0: from 6.23.0 aws_s3_bucket reads/writes tags via
      # the S3 Control API, which cannot reach the emulator (account-ID host prefix).
      # https://github.com/aws/aws-emulator/issues/56
      version = "~> 6.22.0"
    }
  }
}
