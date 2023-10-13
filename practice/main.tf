provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  # This requires the awscli to be installed locally where Terraform is executed
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

locals {
  vpc_id = coalesce(var.vpc_id, data.aws_vpc.default.id)

  aws_auth_users = [
    for u in var.admin_iam_users : {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${u}"
      username = u
      groups   = ["system:masters"]
    }
  ]

  aws_auth_roles = [
    for u in var.admin_iam_roles : {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${u}"
      username = u
      groups   = ["system:masters"]
    }
  ]

  role_name = "s3-${var.s3_bucket_name}-rw-access"
  role_namespace = "default"

}

data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_vpc" "target" {
  id = local.vpc_id
}

data "aws_subnets" "vpc_subnets" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

################################################################################
# EKS
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.28"

  cluster_endpoint_public_access  = true
  enable_irsa = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  vpc_id                   = local.vpc_id
  subnet_ids               = data.aws_subnets.vpc_subnets.ids
  # control_plane_subnet_ids = data.aws_subnets.vpc_subnets.ids

  eks_managed_node_groups = {
    eks_default_group = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      # https://instances.vantage.sh/
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      disk_size = 50

      # Needed by the aws-ebs-csi-driver
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }

  # aws-auth configmap
  manage_aws_auth_configmap = false
  create_aws_auth_configmap = false

  aws_auth_roles = local.aws_auth_roles

  aws_auth_users = local.aws_auth_users

  aws_auth_accounts = [
    data.aws_caller_identity.current.account_id
  ]

  tags = {
    Environment = "demo"
    Terraform   = "true"
  }
}

resource "kubernetes_service_account" "s3_rw_demo_access" {
  metadata {
    name      = local.role_name
    namespace = local.role_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam_eks_role.iam_role_arn
    }
  }
  automount_service_account_token = true
}

module "iam_eks_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = local.role_name

  role_policy_arns = {
    policy = aws_iam_policy.s3_rw_demo_policy.arn
  }

  oidc_providers = {
    default = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.role_namespace}:${local.role_name}"]
    }
  }
}

resource "null_resource" "kubectl" {
    provisioner "local-exec" {
        command = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name} --kubeconfig ~/.kube/eks-${var.region}-${module.eks.cluster_name}"
    }
}

################################################################################
# S3
################################################################################

resource "aws_s3_bucket" "demo" {
  bucket_prefix = "${var.s3_bucket_name}-"

  tags = {
    Name        = var.s3_bucket_name
    Terraform   = "true"
    Environment = "demo"
  }
}

################################################################################
# IAM
################################################################################

resource "aws_iam_policy" "s3_rw_demo_policy" {
  name        = "s3_rw_demo_policy"
  description = "S3 RW Access to ${aws_s3_bucket.demo.arn} Bucket Policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Effect = "Allow",
        Resource = [
          aws_s3_bucket.demo.arn,
          "${aws_s3_bucket.demo.arn}/*"
        ],
      },
      {
        "Effect": "Allow",
        "Action": "s3:ListAllMyBuckets",
        "Resource": "*"
      },
    ],
  })
}
