#=================================================================
# MSK Module Variables - Map of Objects Pattern
#=================================================================

variable "environment" {
  description = "Environment name (dev, stag, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where MSK clusters will be deployed"
  type        = string
}

variable "msk_clusters" {
  description = "Map of MSK cluster configurations"
  type = map(object({
    cluster_name                        = string
    kafka_version                       = string
    number_of_broker_nodes              = number
    broker_instance_type                = string
    broker_volume_size                  = number
    private_subnet_ids                  = list(string)
    client_security_group_ids           = list(string)
    
    encryption_in_transit_client_broker = string
    enable_sasl_scram                   = bool
    allow_unauthenticated_access        = bool
    kafka_admin_username                = string
    kafka_admin_password                = string
    
    enhanced_monitoring_level           = string
    enable_jmx_exporter                 = bool
    enable_node_exporter                = bool
    log_retention_days                  = number
    
    auto_create_topics                  = bool
    default_replication_factor          = number
    min_insync_replicas                 = number
    default_num_partitions              = number
    log_retention_hours                 = number
    compression_type                    = string
    
    enable_provisioned_throughput       = optional(bool, false)
    volume_throughput                   = optional(number, 250)
    enable_s3_logs                      = optional(bool, false)
    s3_logs_bucket                      = optional(string, "")
    s3_logs_prefix                      = optional(string, "msk-logs/")
    kms_deletion_window                 = optional(number, 10)
  }))
}

variable "common_tags" {
  description = "Common tags to apply to all MSK resources"
  type        = map(string)
  default     = {}
}
