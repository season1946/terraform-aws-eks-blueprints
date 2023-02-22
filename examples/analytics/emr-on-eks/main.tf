provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

data "aws_eks_cluster_auth" "this" {
  name = var.eks_cluster_id
}

data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_id
}

data "aws_availability_zones" "available" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {

  region = var.region
  
  emr_on_eks_teams = {
    emr-data-team-a = {
      namespace               = "emr-data-team-a"
      job_execution_role      = "emr-eks-data-team-a"
      additional_iam_policies = [aws_iam_policy.emr_on_eks.arn]
    },
    emr-data-team-b = {
      namespace               = "emr-data-team-b"
      job_execution_role      = "emr-eks-data-team-b"
      additional_iam_policies = [aws_iam_policy.emr_on_eks.arn]
    }
  }


}

#---------------------------------------------------------------
# EKS Blueprints addons
#---------------------------------------------------------------

module "eks_blueprints_kubernetes_addons" {
  #source = "../../../modules/kubernetes-addons"
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.19.0"

  eks_cluster_id       = var.eks_cluster_id
  eks_cluster_endpoint = data.aws_eks_cluster.cluster.endpoint
  eks_oidc_provider    = replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")
  eks_cluster_version  = data.aws_eks_cluster.cluster.version

  #---------------------------------------
  # Amazon EKS Managed Add-ons
  #---------------------------------------
  enable_amazon_eks_vpc_cni            = true
  enable_amazon_eks_coredns            = true
  enable_amazon_eks_kube_proxy         = true
  enable_amazon_eks_aws_ebs_csi_driver = true


  #---------------------------------------
  # Metrics Server
  #---------------------------------------
  enable_metrics_server = true
  metrics_server_helm_config = {
    name       = "metrics-server"
    repository = "https://kubernetes-sigs.github.io/metrics-server/" # (Optional) Repository URL where to locate the requested chart.
    chart      = "metrics-server"
    version    = "3.8.2"
    namespace  = "kube-system"
    timeout    = "300"
    values = [templatefile("${path.module}/helm-values/metrics-server-values.yaml", {
      operating_system = "linux"
    })]
  }

  #---------------------------------------
  # Cluster Autoscaler
  #---------------------------------------
  enable_cluster_autoscaler = true
  cluster_autoscaler_helm_config = {
    name       = "cluster-autoscaler"
    repository = "https://kubernetes.github.io/autoscaler" # (Optional) Repository URL where to locate the requested chart.
    chart      = "cluster-autoscaler"
    version    = "9.15.0"
    namespace  = "kube-system"
    timeout    = "300"
    values = [templatefile("${path.module}/helm-values/cluster-autoscaler-values.yaml", {
      aws_region       = var.region,
      eks_cluster_id   = var.eks_cluster_id,
      operating_system = "linux"
    })]
  }

  #---------------------------------------
  # Amazon Managed Prometheus
  #---------------------------------------
  enable_amazon_prometheus             = true
  amazon_prometheus_workspace_endpoint = aws_prometheus_workspace.amp.prometheus_endpoint

  #---------------------------------------
  # Prometheus Server Add-on
  #---------------------------------------
  enable_prometheus = true
  prometheus_helm_config = {
    name       = "prometheus"
    repository = "https://prometheus-community.github.io/helm-charts"
    chart      = "prometheus"
    version    = "15.10.1"
    namespace  = "prometheus"
    timeout    = "300"
    values = [templatefile("${path.module}/helm-values/prometheus-values.yaml", {
      operating_system = "linux"
    })]
  }

  #---------------------------------------
  # Vertical Pod Autoscaling
  #---------------------------------------
  enable_vpa = true
  vpa_helm_config = {
    name       = "vpa"
    repository = "https://charts.fairwinds.com/stable" # (Optional) Repository URL where to locate the requested chart.
    chart      = "vpa"
    version    = "1.4.0"
    namespace  = "vpa"
    timeout    = "300"
    values = [templatefile("${path.module}/helm-values/vpa-values.yaml", {
      operating_system = "linux"
    })]
  }

  tags = var.tags
}


#---------------------------------------------------------------
# Example IAM policies for EMR job execution
#---------------------------------------------------------------
data "aws_iam_policy_document" "emr_on_eks" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:${data.aws_partition.current.partition}:s3:::*"]

    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
    ]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:*"]

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
  }
}

resource "aws_iam_policy" "emr_on_eks" {
  name        = format("%s-%s", var.eks_cluster_id, "emr-job-iam-policies")
  description = "IAM policy for EMR on EKS Job execution"
  path        = "/"
  policy      = data.aws_iam_policy_document.emr_on_eks.json
}

#---------------------------------------------------------------
# Amazon Prometheus Workspace
#---------------------------------------------------------------
resource "aws_prometheus_workspace" "amp" {
  alias = format("%s-%s", "amp-ws", var.eks_cluster_id)

  tags = var.tags
}

#---------------------------------------------------------------
# Create EMR on EKS Virtual Cluster
#---------------------------------------------------------------
#  emr-containers user and AWSServiceRoleForAmazonEMRContainers role should be in AWS_AUTH config map
# if not, follow step3 in https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/setting-up-cluster-access.html
resource "aws_emrcontainers_virtual_cluster" "this" {
  name = format("%s-%s", var.eks_cluster_id, "emr-data-team-a")

  container_provider {
    id   = var.eks_cluster_id
    type = "EKS"

    info {
      eks_info {
        namespace = "emr-data-team-a"
      }
    }
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# Amazon EMR on EKS setup
# ---------------------------------------------------------------------------------------------------------------------

module "emr_on_eks" {
  #source = "../../../modules/emr-on-eks"
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/emr-on-eks?ref=v4.19.0"

  for_each = { for key, value in local.emr_on_eks_teams : key => value
    if length(local.emr_on_eks_teams) > 0
  }

  emr_on_eks_teams              = each.value
  eks_cluster_id                = var.eks_cluster_id
  iam_role_permissions_boundary = var.iam_role_permissions_boundary
  tags                          = var.tags

}