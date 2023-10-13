output "region" {
  value       = var.region
  description = "The AWS region"
}

output "vpc_id" {
  value       = data.aws_vpc.target.id
  description = "The ID of the target VPC"
}

output "cluster" {
  value       = var.cluster_name
  description = "The name of the EKS"
}

output "account" {
  value       = "${local.role_name}"
  description = "The name of the kubernetes service account"
}
