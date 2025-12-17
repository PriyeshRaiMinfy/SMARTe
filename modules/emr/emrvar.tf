#=================================================================
# EMR Module Variables
#=================================================================

variable "environment" {
  description = "Environment name (dev, stag, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EMR clusters will be deployed"
  type        = string
}

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
}

variable "common_tags" {
  description = "Common tags for all EMR resources"
  type        = map(string)
  default     = {}
}

variable "create_default_roles" {
  description = "Whether to create default IAM roles for EMR"
  type        = bool
  default     = true
}

variable "emr_service_role_name" {
  description = "Name of the EMR service role (if not creating default)"
  type        = string
  default     = ""
}

variable "emr_ec2_role_name" {
  description = "Name of the EMR EC2 instance profile role (if not creating default)"
  type        = string
  default     = ""
}

variable "emr_autoscaling_role_name" {
  description = "Name of the EMR autoscaling role (if not creating default)"
  type        = string
  default     = ""
}
