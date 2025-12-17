#=================================================================
# MSK Module Outputs - Map of Objects Pattern
#=================================================================

output "cluster_arns" {
  description = "Map of MSK Cluster ARNs"
  value       = { for k, v in aws_msk_cluster.kafka_cluster : k => v.arn }
}

output "cluster_names" {
  description = "Map of MSK Cluster Names"
  value       = { for k, v in aws_msk_cluster.kafka_cluster : k => v.cluster_name }
}

output "bootstrap_brokers_tls" {
  description = "Map of TLS bootstrap brokers"
  value       = { for k, v in aws_msk_cluster.kafka_cluster : k => v.bootstrap_brokers_tls }
}

output "bootstrap_brokers_sasl_scram" {
  description = "Map of SASL/SCRAM bootstrap brokers"
  value       = { for k, v in aws_msk_cluster.kafka_cluster : k => v.bootstrap_brokers_sasl_scram }
  sensitive   = true
}

output "zookeeper_connect_strings" {
  description = "Map of Zookeeper connection strings"
  value       = { for k, v in aws_msk_cluster.kafka_cluster : k => v.zookeeper_connect_string }
}

output "security_group_ids" {
  description = "Map of Security Group IDs"
  value       = { for k, v in aws_security_group.msk_cluster_sg : k => v.id }
}

output "kms_key_arns" {
  description = "Map of KMS Key ARNs"
  value       = { for k, v in aws_kms_key.msk_encryption_key : k => v.arn }
}

output "cloudwatch_log_groups" {
  description = "Map of CloudWatch Log Group names"
  value       = { for k, v in aws_cloudwatch_log_group.msk_broker_logs : k => v.name }
}

output "scram_secret_arns" {
  description = "Map of SASL/SCRAM Secret ARNs"
  value       = { for k, v in aws_secretsmanager_secret.msk_scram_credentials : k => v.arn }
  sensitive   = true
}






