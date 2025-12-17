#=================================================================
# EMR Module Outputs
#=================================================================

output "cluster_ids" {
  description = "Map of EMR Cluster IDs"
  value       = { for k, v in aws_emr_cluster.cluster : k => v.id }
}

output "cluster_arns" {
  description = "Map of EMR Cluster ARNs"
  value       = { for k, v in aws_emr_cluster.cluster : k => v.arn }
}

output "cluster_names" {
  description = "Map of EMR Cluster Names"
  value       = { for k, v in aws_emr_cluster.cluster : k => v.name }
}

output "master_public_dns" {
  description = "Map of EMR Master Node Public DNS"
  value       = { for k, v in aws_emr_cluster.cluster : k => v.master_public_dns }
}

output "master_security_group_ids" {
  description = "Map of EMR Master Security Group IDs"
  value       = { for k, v in aws_security_group.emr_master_sg : k => v.id }
}

output "worker_security_group_ids" {
  description = "Map of EMR Worker Security Group IDs"
  value       = { for k, v in aws_security_group.emr_worker_sg : k => v.id }
}

output "service_security_group_ids" {
  description = "Map of EMR Service Security Group IDs"
  value       = { for k, v in aws_security_group.emr_service_sg : k => v.id }
}

output "log_bucket_names" {
  description = "Map of S3 log bucket names"
  value       = { for k, v in aws_s3_bucket.emr_logs : k => v.id }
}

output "cloudwatch_log_groups" {
  description = "Map of CloudWatch log group names"
  value       = { for k, v in aws_cloudwatch_log_group.emr_logs : k => v.name }
}

output "service_role_arns" {
  description = "Map of EMR Service Role ARNs"
  value       = { for k, v in aws_iam_role.emr_service_role : k => v.arn }
}

output "ec2_instance_profile_arns" {
  description = "Map of EMR EC2 Instance Profile ARNs"
  value       = { for k, v in aws_iam_instance_profile.emr_ec2_profile : k => v.arn }
}







output "cluster_applications" {
  description = "Map of EMR Cluster Applications"
  value       = { for k, v in aws_emr_cluster.cluster : k => v.applications }
}