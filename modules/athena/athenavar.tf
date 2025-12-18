#=================================================================
# AWS Athena Module Variables (Map of Objects Pattern)
# Project: SMARTe Inc. GCP to AWS Migration
# Purpose: Serverless query service for S3 data lake analytics
#=================================================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

variable "athena_workgroups" {
  description = "Map of Athena workgroups to create"
  type = map(object({
    name                                = string
    description                         = optional(string, "")
    state                               = optional(string, "ENABLED")
    force_destroy                       = optional(bool, false)
    
    # Result Configuration
    s3_output_location                  = optional(string, "")
    enable_encryption                   = optional(bool, true)
    encryption_option                   = optional(string, "SSE_KMS") # SSE_S3, SSE_KMS, CSE_KMS
    kms_key_arn                         = optional(string, "")
    
    # Workgroup Configuration
    bytes_scanned_cutoff_per_query      = optional(number, 0) # 0 = no limit, in bytes
    enforce_workgroup_configuration     = optional(bool, true)
    publish_cloudwatch_metrics_enabled  = optional(bool, true)
    requester_pays_enabled              = optional(bool, false)
    
    # Engine Version
    selected_engine_version             = optional(string, "AUTO")
    
    # Databases to create in this workgroup
    databases = optional(map(object({
      name                = string
      comment             = optional(string, "")
      force_destroy       = optional(bool, false)
      use_glue_catalog    = optional(bool, true)
      expected_bucket_owner = optional(string, "")
      properties          = optional(map(string), {})
    })), {})
  }))
}
