# The problem

You've joined a new and growing startup.

The company wants to build its initial Kubernetes infrastructure on AWS.

They have asked you if you can help create the following:
- Terraform code that deploys an EKS cluster (whatever latest version is currently available) into an existing VPC
- The terraform code should also prepare anything needed for a pod to be able to assume an IAM role
- Include a short readme that explains how to use the Terraform repo and that also demonstrates how an end-user (a developer from the company) can run a pod on this new EKS cluster and also have an IAM role assigned that allows that pod to access an S3 bucket.

# The solution

For this particular case, we will use a [terraform](https://www.terraform.io/) setup with the [terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks) module since [HashiCorp themselves recommend its usage](https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks). Alternatives could be [eksctl](https://eksctl.io/#) or terraform with the [aws_eks_cluster resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster). Examples for further configuring the EKS cluster can be found in [eks blueprints](https://github.com/aws-ia/terraform-aws-eks-blueprints/tree/main), [tEKS](https://github.com/particuleio/teks) and [eks demo](https://github.com/awslabs/eksdemo) repos.

Prerequisites:
- The [terraform](https://developer.hashicorp.com/terraform/downloads?product_intent=terraform) utility version from 1.3. You can check your current version with `terraform -version`.
- The kubectl command line tool is installed on your device. This setup uses EKS 1.28 version so you can use kubectl version 1.27 or 1.28 with it. To install or upgrade kubectl, see [Installing or updating kubectl](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html).
- Version 2.12.3 or later or 1.27.160 or later of the AWS CLI installed and configured on your device. You can check your current version with `aws --version | cut -d / -f2 | cut -d ' ' -f1`. To install the latest version, see [Installing, updating, and uninstalling the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) and [Quick configuration with `aws configure`](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html#cli-configure-quickstart-config) in the AWS Command Line Interface User Guide.
- An IAM principal with permissions to `create` and `describe` an Amazon EKS cluster, IAM policy, IAM role and s3 bucket, and also `describe` VPC and subnets.

List of config files:
- `main.tf` contain main logic of this setup
- `outputs.tf` configure terraform outputs that we'll use later
- `terraform.tf` configure terraform providers
- `variables.tf` contain all variables with defaults that necessary for this setup
- `test-s3.yaml` will be used for test `kubectl` and access to our demo s3 bucket

You can configure this setup via passing variables to `terraform apply` command like `-var "vpc_id=vpc-0aa2e4d08571d2ad5"` or via `terraform.tfvars` file. You can find more info [here](https://developer.hashicorp.com/terraform/language/values/variables#variable-definition-precedence).

List of variables:
```
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
```

By default, only the creator of the cluster will have administrative access to it. In this setup, the root user of the organization should also have cluster administrator rights. You can grant cluster administrator rights to roles or users using the admin_iam_roles and admin_iam_users variables. You can find more information [here](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html).

> When you create an Amazon EKS cluster, the [IAM principal](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_terms-and-concepts.html) that creates the cluster is automatically granted `system:masters` permissions in the cluster's role-based access control (RBAC) configuration in the Amazon EKS control plane. This principal doesn't appear in any visible configuration, so make sure to keep track of which principal originally created the cluster.


Once you have configured all the utilities, your AWS account, and filled in the necessary variables, you can create this setup with three simple commands:
```
terraform init
terraform plan
terraform apply
```

You can verify everything with the `terraform plan` command, and `terraform apply` will prompt you to type `yes` to apply this setup. After applying and waiting for 10-15 minutes, you'll see an output similar to this one, and your `~/.kube/` home directory will contain a new kubeconfig file with a name like `aws-us-east-2-demo`.
```
Outputs:

account = "s3-demo-rw-access"
cluster = "demo"
region = "us-east-2"
vpc_id = "vpc-0dcdfb64543d10526"

```

Now you can apply a test job:
```
export KUBECONFIG=~/.kube/eks-$(terraform output -raw region)-$(terraform output -raw cluster)
kubectl apply -f test-s3.yaml
kubectl get job -l app=eks-iam-test-s3
kubectl logs -l app=eks-iam-test-s3
```

`kubectl get job` should produce output like this:
```
NAME              COMPLETIONS   DURATION   AGE
eks-iam-test-s3   1/1           5s         79s
```

`kubectl logs` should produce output like this:
```
2023-10-13 15:14:31 demo-20231013151428645400000002
```

To provide access to an S3 bucket from EKS pods, you should launch them with the `serviceAccountName` parameter set to the value provided by terraform using the `terraform output account` command. You can refer to the example in the `test-s3.yaml` file.

That's all. Don't forget to clean up everything after use!
```
terraform destroy
```

In my case, terraform couldn't delete the security group because it remained associated with a network interface that was left behind after deleting the EKS cluster. To fully clean up the account, you need to manually remove the network interface and then run `terraform destroy` again.
