locals {
  kubernetes_version = "1.36"
}

resource "aws_eks_cluster" "main" {
  name     = "larder-prod"
  version  = local.kubernetes_version
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    subnet_ids              = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.data_c.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }
}

resource "aws_iam_role" "eks" {
  name               = "larder-eks"
  assume_role_policy = file("${path.module}/policies/eks-assume.json")
}

resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "general"
  node_role_arn   = aws_iam_role.eks.arn
  subnet_ids      = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.data_c.id]
  instance_types  = ["m7g.xlarge"]

  scaling_config {
    desired_size = 3
    min_size     = 3
    max_size     = 9
  }
}
