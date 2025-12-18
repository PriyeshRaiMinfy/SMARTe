#=================================================================
# AWS Athena Module Outputs
#=================================================================

output "workgroup_ids" {
  description = "Map of Athena Workgroup IDs"
  value       = { for k, v in aws_athena_workgroup.workgroup : k => v.id }
}

output "workgroup_arns" {
  description = "Map of Athena Workgroup ARNs"
  value       = { for k, v in aws_athena_workgroup.workgroup : k => v.arn }
}

output "workgroup_names" {
  description = "Map of Athena Workgroup names"
  value       = { for k, v in aws_athena_workgroup.workgroup : k => v.name }
}

output "database_names" {
  description = "Map of Athena Database names"
  value       = { for k, v in aws_athena_database.database : k => v.name }
}

output "database_ids" {
  description = "Map of Athena Database IDs"
  value       = { for k, v in aws_athena_database.database : k => v.id }
}

output "s3_output_buckets" {
  description = "Map of S3 bucket names for Athena query results"
  value = {
    for k, v in aws_s3_bucket.athena_results : k => v.id
  }
}

output "kms_key_arns" {
  description = "Map of KMS key ARNs for Athena encryption"
  value = {
    for k, v in aws_kms_key.athena_encryption : k => v.arn
  }
}

output "cloudwatch_log_groups" {
  description = "Map of CloudWatch log group names"
  value       = { for k, v in aws_cloudwatch_log_group.athena_logs : k => v.name }
}
