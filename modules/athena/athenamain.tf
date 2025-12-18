#=================================================================
# AWS Athena Module - Map of Objects Pattern
# Project: SMARTe Inc. GCP to AWS Migration
# Purpose: Serverless SQL queries for data lake analytics
#=================================================================

#=================================================================
# KMS Key for Athena Encryption (Optional)
#=================================================================
resource "aws_kms_key" "athena_encryption" {
  for_each = {
    for k, v in var.athena_workgroups : k => v
    if v.enable_encryption && v.encryption_option == "SSE_KMS" && v.kms_key_arn == ""
  }
  
  description             = "KMS key for Athena workgroup ${var.environment}-${each.value.name}"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.environment}-${each.value.name}-athena-kms"
      Workgroup = each.key
    }
  )
}

resource "aws_kms_alias" "athena_encryption_alias" {
  for_each = {
    for k, v in var.athena_workgroups : k => v
    if v.enable_encryption && v.encryption_option == "SSE_KMS" && v.kms_key_arn == ""
  }
  
  name          = "alias/${var.environment}-${each.value.name}-athena"
  target_key_id = aws_kms_key.athena_encryption[each.key].key_id
}

#=================================================================
# S3 Bucket for Athena Query Results
#=================================================================
resource "random_id" "bucket_suffix" {
  for_each = {
    for k, v in var.athena_workgroups : k => v
    if v.s3_output_location == ""
  }
  byte_length = 4
}

resource "aws_s3_bucket" "athena_results" {
  for_each = {
    for k, v in var.athena_workgroups : k => v
    if v.s3_output_location == ""
  }
  
  bucket = "${var.environment}-${each.value.name}-athena-results-${random_id.bucket_suffix[each.key].hex}"
  
  tags = merge(
    var.common_tags,
    {
      Name      = "${var.environment}-${each.value.name}-athena-results"
      Workgroup = each.key
    }
  )
}

resource "aws_s3_bucket_versioning" "athena_results" {
  for_each = {
    for k, v in var.athena_workgroups : k => v
    if v.s3_output_location == ""
  }
  
  bucket = aws_s3_bucket.athena_results[each.key].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  for_each = {
    for k, v in var.athena_workgroups : k => v
    if v.s3_output_location == "" && v.enable_encryption
  }
  
  bucket = aws_s3_bucket.athena_results[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = each.value.encryption_option == "SSE_KMS" ? "aws:kms" : "AES256"
      kms_master_key_id = each.value.encryption_option == "SSE_KMS" ? (
        each.value.kms_key_arn != "" ? each.value.kms_key_arn : aws_kms_key.athena_encryption[each.key].arn
      ) : null
    }
  }
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  for_each = {
    for k, v in var.athena_workgroups : k => v
    if v.s3_output_location == ""
  }
  
  bucket = aws_s3_bucket.athena_results[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  for_each = {
    for k, v in var.athena_workgroups : k => v
    if v.s3_output_location == ""
  }
  
  bucket = aws_s3_bucket.athena_results[each.key].id

  rule {
    id     = "delete-old-query-results"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

#=================================================================
# Athena Workgroup
#=================================================================
resource "aws_athena_workgroup" "workgroup" {
  for_each = var.athena_workgroups
  
  name          = "${var.environment}-${each.value.name}"
  description   = each.value.description != "" ? each.value.description : "Athena workgroup for ${each.value.name}"
  state         = each.value.state
  force_destroy = each.value.force_destroy

  configuration {
    bytes_scanned_cutoff_per_query     = each.value.bytes_scanned_cutoff_per_query
    enforce_workgroup_configuration    = each.value.enforce_workgroup_configuration
    publish_cloudwatch_metrics_enabled = each.value.publish_cloudwatch_metrics_enabled
    requester_pays_enabled             = each.value.requester_pays_enabled

    result_configuration {
      output_location = each.value.s3_output_location != "" ? each.value.s3_output_location : "s3://${aws_s3_bucket.athena_results[each.key].id}/"

      dynamic "encryption_configuration" {
        for_each = each.value.enable_encryption ? [1] : []
        content {
          encryption_option = each.value.encryption_option
          kms_key_arn = each.value.encryption_option == "SSE_KMS" ? (
            each.value.kms_key_arn != "" ? each.value.kms_key_arn : aws_kms_key.athena_encryption[each.key].arn
          ) : null
        }
      }
    }

    engine_version {
      selected_engine_version = each.value.selected_engine_version
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.environment}-${each.value.name}"
      Environment = var.environment
      Workgroup   = each.key
    }
  )
}

#=================================================================
# Athena Databases (Glue Catalog)
#=================================================================
locals {
  # Flatten databases from all workgroups
  athena_databases = flatten([
    for wg_key, wg_value in var.athena_workgroups : [
      for db_key, db_value in wg_value.databases : {
        workgroup_key = wg_key
        workgroup_name = wg_value.name
        database_key  = "${wg_key}-${db_key}"
        database_name = db_value.name
        comment       = db_value.comment
        force_destroy = db_value.force_destroy
        use_glue_catalog = db_value.use_glue_catalog
        expected_bucket_owner = db_value.expected_bucket_owner
        properties    = db_value.properties
        s3_output_location = wg_value.s3_output_location != "" ? wg_value.s3_output_location : "s3://${aws_s3_bucket.athena_results[wg_key].id}/"
      }
    ]
  ])

  databases_map = {
    for db in local.athena_databases : db.database_key => db
  }
}

resource "aws_athena_database" "database" {
  for_each = local.databases_map
  
  name          = "${var.environment}_${each.value.database_name}"
  bucket        = split("/", trimprefix(each.value.s3_output_location, "s3://"))[0]
  comment       = each.value.comment
  force_destroy = each.value.force_destroy
  expected_bucket_owner = each.value.expected_bucket_owner
  properties    = each.value.properties
}

#=================================================================
# CloudWatch Log Group for Athena Query Logs (Optional)
#=================================================================
resource "aws_cloudwatch_log_group" "athena_logs" {
  for_each = var.athena_workgroups
  
  name              = "/aws/athena/${var.environment}-${each.value.name}"
  retention_in_days = 30

  tags = merge(
    var.common_tags,
    {
      Name      = "${var.environment}-${each.value.name}-athena-logs"
      Workgroup = each.key
    }
  )
}
