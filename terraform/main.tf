# Short-lived demo cluster: apply, run the load test, destroy.
# One NAT gateway and public API endpoint keep it cheap and simple; tighten both for anything long-lived.

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.1"

  name            = var.name
  cidr            = "10.40.0.0/16"
  azs             = local.azs
  private_subnets = ["10.40.0.0/20", "10.40.16.0/20"]
  public_subnets  = ["10.40.128.0/24", "10.40.129.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.28.1"

  name               = var.name
  kubernetes_version = var.kubernetes_version

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = { before_compute = true }
    eks-pod-identity-agent = { before_compute = true }
  }

  eks_managed_node_groups = {
    inference = {
      instance_types = [var.node_instance_type]
      min_size       = 1
      max_size       = var.node_max_size
      desired_size   = 1
      labels         = { workload = "llm" }
    }
  }
}
