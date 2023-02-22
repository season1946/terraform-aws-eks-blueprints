
output "emrcontainers_virtual_cluster_id" {
  description = "EMR Containers Virtual cluster ID"
  value       = aws_emrcontainers_virtual_cluster.this.id
}

# output "emr_on_eks_role_id" {
#   description = "IAM execution role ID for EMR on EKS"
#   value       = module.emr_on_eks.emr_on_eks_role_id
# }

# output "emr_on_eks_role_arn" {
#   description = "IAM execution role arn for EMR on EKS"
#   value       = module.emr_on_eks.emr_on_eks_role_arn
# }
