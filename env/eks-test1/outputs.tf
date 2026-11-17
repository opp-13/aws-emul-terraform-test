output "bucket" {
  value = aws_s3_bucket.this.bucket
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "eks_cluster_name" {
  value = try(aws_eks_cluster.this[0].name, null)
}

output "eks_endpoint" {
  value = try(aws_eks_cluster.this[0].endpoint, null)
}

output "eks_ca_data" {
  value     = try(aws_eks_cluster.this[0].certificate_authority[0].data, null)
  sensitive = true
}

output "eks_node_group_status" {
  value = try(aws_eks_node_group.this[0].status, null)
}
