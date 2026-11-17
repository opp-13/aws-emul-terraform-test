# Endpoint, credentials and CA come from env vars set by scripts/env.ps1
# (AWS_ENDPOINT_URL, AWS_SHARED_CREDENTIALS_FILE, AWS_CA_BUNDLE, ...).
provider "aws" {
  region = var.region

  # The emulator rejects virtual-hosted-style S3 requests.
  s3_use_path_style = true

  default_tags {
    tags = {
      Project = "aws-emul-terraform-test"
      Env     = "eks-test1"
    }
  }
}
