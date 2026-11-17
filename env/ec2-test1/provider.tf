# Endpoint, credentials and CA come from env vars (scripts/tf.ps1 or scripts/env.ps1).
provider "aws" {
  region = var.region

  s3_use_path_style = true

  default_tags {
    tags = {
      Project = "aws-emul-terraform-test"
      Env     = "ec2-test1"
    }
  }
}
