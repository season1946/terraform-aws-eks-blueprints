variable "eks_cluster_id" {
  description = "EKS Cluster ID/name"
  type        = string
  default     = "managed-airflow-mwaa"
}

variable "region" {
  description = "region"
  type        = string
  default     = "us-west-2"
}

variable "tags" {
  description = "Default tags"
  default     = {}
  type        = map(string)
}

variable "iam_role_permissions_boundary" {
  description = "ARN of the policy that is used to set the permissions boundary for the IAM role"
  type        = string
  default     = null
}
