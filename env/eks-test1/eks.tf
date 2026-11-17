resource "aws_eks_cluster" "this" {
  count    = var.enable_eks ? 1 : 0
  name     = var.name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster[0].arn

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = aws_subnet.public[*].id
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

resource "aws_eks_node_group" "this" {
  count           = var.enable_eks ? 1 : 0
  cluster_name    = aws_eks_cluster.this[0].name
  node_group_name = "${var.name}-ng"
  node_role_arn   = aws_iam_role.node[0].arn
  subnet_ids      = aws_subnet.public[*].id
  instance_types  = var.node_instance_types

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}
