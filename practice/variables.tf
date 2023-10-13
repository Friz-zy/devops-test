variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "vpc_id" {
  description = "ID of target VPC"
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "AWS EKS cluster name"
  type        = string
  default     = "demo"
}

variable "s3_bucket_name" {
  description = "AWS s3 bucket name"
  type        = string
  default     = "demo"
}

variable "admin_iam_roles" {
  description = "List of account roles that should have EKS amdin permissions"
  type    = list(string)
  default = []
}

variable "admin_iam_users" {
  description = "List of account users that should have EKS amdin permissions"
  type    = list(string)
  default = []
}
