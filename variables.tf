#=================================================================
# Root Variables - SMARTe Infrastructure (MSK + EMR)
#=================================================================

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment name (dev, stag, prod)"
  type        = string
  validation {
    condition     = can(regex("^(dev|stag|prod)$", var.environment))
    error_message = "Environment must be dev, stag, or prod."
  }
}

variable "vpc_id" {
  description = "Existing VPC ID where resources will be deployed"
  type        = string
}

#=================================================================
# MSK Clusters Configuration (Map of Objects)
#=================================================================
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
    
    # Security Settings
    encryption_in_transit_client_broker = string
    enable_sasl_scram                   = bool
    allow_unauthenticated_access        = bool
    kafka_admin_username                = string
    kafka_admin_password                = string
    
    # Monitoring
    enhanced_monitoring_level           = string
    enable_jmx_exporter                 = bool
    enable_node_exporter                = bool
    log_retention_days                  = number
    
    # Kafka Settings
    auto_create_topics                  = bool
    default_replication_factor          = number
    min_insync_replicas                 = number
    default_num_partitions              = number
    log_retention_hours                 = number
    compression_type                    = string
    
    # Optional Settings
    enable_provisioned_throughput       = optional(bool, false)
    volume_throughput                   = optional(number, 250)
    enable_s3_logs                      = optional(bool, false)
    s3_logs_bucket                      = optional(string, "")
    s3_logs_prefix                      = optional(string, "msk-logs/")
    kms_deletion_window                 = optional(number, 10)
  }))
  default = {}
}

#=================================================================
# EMR Clusters Configuration (Map of Objects) - SIMPLIFIED
#=================================================================
variable "emr_clusters" {
  description = "Map of EMR cluster configurations"
  type = map(object({
    cluster_name                        = string
    emr_release_label                   = string
    applications                        = list(string)
    subnet_id                           = string
    
    # Master Node Configuration
    master_instance_type                = string
    master_ebs_size                     = number
    master_ebs_type                     = string
    
    # Core Nodes Configuration
    core_instance_type                  = string
    core_instance_count                 = number
    core_ebs_size                       = number
    core_ebs_type                       = string
    
    # Auto-Scaling Configuration
    enable_autoscaling                  = bool
    core_autoscaling_min                = number
    core_autoscaling_max                = number
    
    # Cluster Behavior
    termination_protection              = bool
    keep_alive_when_no_steps            = bool
    
    # Security
    allow_ssh_from_cidr                 = list(string)
    allow_web_ui_from_cidr              = list(string)
    allow_hive_from_cidr                = list(string)
    
    # Logging
    enable_s3_logging                   = bool
    log_retention_days                  = number
    
    # Configurations (JSON)
    configurations                      = any
    
    # Optional Settings
    key_name                            = string
    kms_key_id                          = string
    enable_glue_catalog                 = bool
    s3_data_bucket                      = string
    
    # Bootstrap Actions
    bootstrap_actions                   = list(object({
      name = string
      path = string
      args = list(string)
    }))
    
    # Step Configuration (for transient clusters)
    steps                               = list(object({
      name              = string
      action_on_failure = string
      hadoop_jar_step = object({
        jar  = string
        args = list(string)
      })
    }))
  }))
  default = {}
}

#=================================================================
# Athena Configuration (Map of Objects)
#=================================================================
variable "athena_workgroups" {
  description = "Map of Athena workgroups to create"
  type = map(object({
    name                                = string
    description                         = optional(string, "")
    state                               = optional(string, "ENABLED")
    enforce_workgroup_configuration     = optional(bool, true)
    publish_cloudwatch_metrics_enabled  = optional(bool, true)
    bytes_scanned_cutoff_per_query      = optional(number, 0)
    enable_encryption                   = optional(bool, true)
    encryption_option                   = optional(string, "SSE_KMS")
    
    databases = optional(map(object({
      name          = string
      comment       = optional(string, "")
      force_destroy = optional(bool, false)
    })), {})
  }))
  default = {}
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project   = "SMARTe-Migration"
    ManagedBy = "Terraform"
  }
}
