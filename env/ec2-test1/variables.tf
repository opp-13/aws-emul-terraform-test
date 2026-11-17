variable "region" {
  type    = string
  default = "us-east-1"
}

variable "name" {
  type    = string
  default = "ec2-test1"
}

variable "instance_type" {
  # Avoid T-family types on the emulator: DescribeInstanceCreditSpecifications
  # returns 501 (https://github.com/aws/aws-emulator/issues/422).
  type    = string
  default = "m5.large"
}

variable "ami_id" {
  description = "AMI to use. Empty = latest Amazon Linux 2023 via public SSM parameter."
  type        = string
  default     = ""
}

variable "allowed_http_cidr" {
  description = "CIDR allowed to reach nginx on port 80."
  type        = string
  default     = "0.0.0.0/0"
}
