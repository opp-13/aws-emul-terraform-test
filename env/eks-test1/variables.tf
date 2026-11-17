variable "region" {
  type    = string
  default = "us-east-1"
}

variable "name" {
  type    = string
  default = "eks-test1"
}

variable "enable_eks" {
  description = "Create the EKS cluster and node group."
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "node_instance_types" {
  # Avoid T-family types: DescribeInstanceCreditSpecifications returns 501
  # (https://github.com/aws/aws-emulator/issues/422).
  type    = list(string)
  default = ["m5.large"]
}
