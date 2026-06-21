terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
  backend "s3" {
    bucket = "devopsprojectsgauri"  
    key    = "flaskrestapi/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

resource "aws_vpc" "proj4_vpc" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "proj4" }
}

resource "aws_subnet" "proj4_subnet_1" {
  cidr_block              = "10.0.0.0/24"
  vpc_id                  = aws_vpc.proj4_vpc.id
  availability_zone       = "ap-southeast-2a"
  map_public_ip_on_launch = true
  tags                    = { Name = "proj4_subnet_1" }
}

resource "aws_subnet" "proj4_subnet_2" {
  cidr_block              = "10.0.1.0/24"
  vpc_id                  = aws_vpc.proj4_vpc.id
  availability_zone       = "ap-southeast-2b"
  map_public_ip_on_launch = true
  tags                    = { Name = "proj4_subnet_2" }
}

resource "aws_internet_gateway" "proj4_igw" {
  vpc_id = aws_vpc.proj4_vpc.id
  tags   = { Name = "proj4_igw" }
}

resource "aws_route_table" "proj4_rt" {
  vpc_id = aws_vpc.proj4_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.proj4_igw.id
  }
  tags = { Name = "proj4_rt" }
}

resource "aws_route_table_association" "proj4_rta1" {
  subnet_id      = aws_subnet.proj4_subnet_1.id
  route_table_id = aws_route_table.proj4_rt.id
}

resource "aws_route_table_association" "proj4_rta2" {
  subnet_id      = aws_subnet.proj4_subnet_2.id
  route_table_id = aws_route_table.proj4_rt.id
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "flask-postgres-cluster"
  cluster_version = "1.32"

  vpc_id     = aws_vpc.proj4_vpc.id
  subnet_ids = [aws_subnet.proj4_subnet_1.id, aws_subnet.proj4_subnet_2.id]

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      instance_types = ["c7i-flex.large"]
      ami_type       = "AL2023_x86_64_STANDARD"
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      tags           = { Name = "eks_worker_nodes" }
    }
  }
}

# Names must match the -n flags used in the Jenkinsfile's `helm upgrade --install` calls
resource "kubernetes_namespace" "namespaces" {
  for_each = toset(["staging", "prod"])

  metadata {
    name = each.key
  }

  depends_on = [module.eks]
}

# In your eks.tf or main.tf
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-ebs-csi-driver"

  depends_on = [
    module.eks.eks_managed_node_groups
  ]
}
