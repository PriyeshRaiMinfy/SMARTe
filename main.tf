#=================================================================
# AWS MSK Kafka Clusters Module (Map of Objects Pattern)
#=================================================================
module "msk_clusters" {
  source = "./modules/msk"

  environment             = var.environment
  vpc_id                  = var.vpc_id
  msk_clusters            = var.msk_clusters
  common_tags             = var.common_tags
}


#=================================================================
# AWS EMR Clusters Module (Map of Objects Pattern)
#=================================================================
module "emr_clusters" {
  source = "./modules/emr"

  environment             = var.environment
  vpc_id                  = var.vpc_id
  emr_clusters            = var.emr_clusters
  common_tags             = var.common_tags
  
  # IAM Role Configuration
  # create_default_roles    = var.create_emr_default_roles
  # emr_service_role_name   = var.emr_service_role_name
  # emr_ec2_role_name       = var.emr_ec2_role_name
  # emr_autoscaling_role_name = var.emr_autoscaling_role_name
}




#===============================================================
# Athena Configuration
#===============================================================
module "athena" {
  source            = "./modules/athena"
  environment       = var.environment
  common_tags       = var.common_tags
  athena_workgroups = var.athena_workgroups
}




#=================================================================
# MSK Outputs
#=================================================================
output "msk_cluster_arns" {
  description = "Map of MSK Cluster ARNs"
  value       = module.msk_clusters.cluster_arns
}

output "kafka_bootstrap_brokers_tls" {
  description = "Map of Kafka TLS connection strings"
  value       = module.msk_clusters.bootstrap_brokers_tls
}

output "kafka_bootstrap_brokers_sasl" {
  description = "Map of Kafka SASL/SCRAM connection strings"
  value       = module.msk_clusters.bootstrap_brokers_sasl_scram
  sensitive   = true
}

output "msk_security_group_ids" {
  description = "Map of MSK Security Group IDs"
  value       = module.msk_clusters.security_group_ids
}

output "msk_zookeeper_connect_string" {
  description = "Map of Zookeeper connection strings"
  value       = module.msk_clusters.zookeeper_connect_strings
}





#=================================================================
# EMR Outputs (Fixed to match actual module outputs)
#=================================================================
output "emr_cluster_ids" {
  description = "Map of EMR Cluster IDs"
  value       = module.emr_clusters.cluster_ids
}

output "emr_cluster_arns" {
  description = "Map of EMR Cluster ARNs"
  value       = module.emr_clusters.cluster_arns
}

output "emr_master_public_dns" {
  description = "Map of EMR Master Node Public DNS"
  value       = module.emr_clusters.master_public_dns
}

output "emr_master_security_group_ids" {
  description = "Map of EMR Master Security Group IDs"
  value       = module.emr_clusters.master_security_group_ids
}

output "emr_worker_security_group_ids" {
  description = "Map of EMR Worker Security Group IDs"
  value       = module.emr_clusters.worker_security_group_ids
}

output "emr_log_bucket_names" {
  description = "Map of EMR S3 log bucket names"
  value       = module.emr_clusters.log_bucket_names
}

output "emr_cloudwatch_log_groups" {
  description = "Map of EMR CloudWatch log group names"
  value       = module.emr_clusters.cloudwatch_log_groups
}

output "emr_service_role_arns" {
  description = "Map of EMR Service Role ARNs"
  value       = module.emr_clusters.service_role_arns
}

output "emr_ec2_instance_profile_arns" {
  description = "Map of EMR EC2 Instance Profile ARNs"
  value       = module.emr_clusters.ec2_instance_profile_arns
}












# #=================================================================
# # EMR Outputs (Corrected to match module outputs)
# #=================================================================
# output "emr_cluster_ids" {
#   description = "Map of EMR Cluster IDs"
#   value       = module.emr_clusters.cluster_ids
# }

# output "emr_cluster_arns" {
#   description = "Map of EMR Cluster ARNs"
#   value       = module.emr_clusters.cluster_arns
# }

# output "emr_cluster_master_public_dns" {
#   description = "Map of EMR Master Node Public DNS"
#   value       = module.emr_clusters.cluster_master_public_dns
# }

# output "emr_cluster_states" {
#   description = "Map of EMR Cluster States"
#   value       = module.emr_clusters.cluster_states
# }

# output "emr_master_security_group_ids" {
#   description = "Map of EMR Master Security Group IDs"
#   value       = module.emr_clusters.master_security_group_ids
# }

# output "emr_slave_security_group_ids" {
#   description = "Map of EMR Slave (Core/Task) Security Group IDs"
#   value       = module.emr_clusters.slave_security_group_ids
# }

# output "emr_service_security_group_ids" {
#   description = "Map of EMR Service Security Group IDs"
#   value       = module.emr_clusters.service_security_group_ids
# }

# output "emr_kms_key_arns" {
#   description = "Map of EMR KMS Key ARNs"
#   value       = module.emr_clusters.kms_key_arns
# }

# output "emr_security_configuration_names" {
#   description = "Map of EMR Security Configuration names"
#   value       = module.emr_clusters.security_configuration_names
# }

# output "emr_cloudwatch_log_groups" {
#   description = "Map of EMR CloudWatch log group names"
#   value       = module.emr_clusters.log_group_names
# }

# #=================================================================
# # IAM Role Outputs
# #=================================================================
# output "emr_service_role_arn" {
#   description = "EMR Service Role ARN"
#   value       = module.emr_clusters.emr_service_role_arn
# }

# output "emr_ec2_instance_profile_arn" {
#   description = "EMR EC2 Instance Profile ARN"
#   value       = module.emr_clusters.emr_ec2_instance_profile_arn
# }

# output "emr_autoscaling_role_arn" {
#   description = "EMR AutoScaling Role ARN"
#   value       = module.emr_clusters.emr_autoscaling_role_arn
# }






#=================================================================
# Combined Outputs (Useful for Integration)
#=================================================================
output "all_cluster_info" {
  description = "Summary of all deployed clusters"
  value = {
    msk_clusters = {
      arns              = module.msk_clusters.cluster_arns
      security_groups   = module.msk_clusters.security_group_ids
      bootstrap_brokers = module.msk_clusters.bootstrap_brokers_tls
      zookeeper         = module.msk_clusters.zookeeper_connect_strings
    }
    emr_clusters = {
      ids              = module.emr_clusters.cluster_ids
      arns             = module.emr_clusters.cluster_arns
      master_dns       = module.emr_clusters.master_public_dns
      master_sgs       = module.emr_clusters.master_security_group_ids
      worker_sgs       = module.emr_clusters.worker_security_group_ids
    }
  }
}









