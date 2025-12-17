#=================================================================
# AWS EMR (Elastic MapReduce) Module - Map of Objects Pattern
# Project: SMARTe Inc. GCP to AWS Migration
# Purpose: Big data processing clusters (Spark, Hadoop, Hive, Presto)
#=================================================================

#=================================================================
# KMS Key for EMR Encryption (Optional)
#=================================================================
resource "aws_kms_key" "emr_encryption" {
  for_each = { for k, v in var.emr_clusters : k => v if v.kms_key_id == "" }
  
  description             = "KMS key for EMR cluster ${var.environment}-${each.value.cluster_name}"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.environment}-${each.value.cluster_name}-emr-kms"
      Cluster = each.key
    }
  )
}

resource "aws_kms_alias" "emr_encryption_alias" {
  for_each = { for k, v in var.emr_clusters : k => v if v.kms_key_id == "" }
  
  name          = "alias/${var.environment}-${each.value.cluster_name}-emr"
  target_key_id = aws_kms_key.emr_encryption[each.key].key_id
}

#=================================================================
# IAM Role for EMR Service
#=================================================================
resource "aws_iam_role" "emr_service_role" {
  for_each = var.emr_clusters
  
  name = "${var.environment}-${each.value.cluster_name}-emr-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "elasticmapreduce.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.environment}-${each.value.cluster_name}-emr-service-role"
      Cluster = each.key
    }
  )
}

resource "aws_iam_role_policy_attachment" "emr_service_policy" {
  for_each = var.emr_clusters
  
  role       = aws_iam_role.emr_service_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

#=================================================================
# IAM Role for EMR EC2 Instances
#=================================================================
resource "aws_iam_role" "emr_ec2_role" {
  for_each = var.emr_clusters
  
  name = "${var.environment}-${each.value.cluster_name}-emr-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.environment}-${each.value.cluster_name}-emr-ec2-role"
      Cluster = each.key
    }
  )
}

resource "aws_iam_role_policy_attachment" "emr_ec2_policy" {
  for_each = var.emr_clusters
  
  role       = aws_iam_role.emr_ec2_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

# Additional policy for Glue Catalog access
resource "aws_iam_role_policy" "emr_glue_policy" {
  for_each = { for k, v in var.emr_clusters : k => v if v.enable_glue_catalog }
  
  name = "${var.environment}-${each.value.cluster_name}-glue-policy"
  role = aws_iam_role.emr_ec2_role[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:*",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListAllMyBuckets",
          "s3:GetBucketAcl",
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribeRouteTables",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcAttribute",
          "iam:ListRolePolicies",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::aws-glue-*/*",
          "arn:aws:s3:::*/*aws-glue-*/*"
        ]
      }
    ]
  })
}

# S3 access policy for data bucket
resource "aws_iam_role_policy" "emr_s3_policy" {
  for_each = { for k, v in var.emr_clusters : k => v if v.s3_data_bucket != "" }
  
  name = "${var.environment}-${each.value.cluster_name}-s3-policy"
  role = aws_iam_role.emr_ec2_role[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${each.value.s3_data_bucket}",
          "arn:aws:s3:::${each.value.s3_data_bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "emr_ec2_profile" {
  for_each = var.emr_clusters
  
  name = "${var.environment}-${each.value.cluster_name}-emr-ec2-profile"
  role = aws_iam_role.emr_ec2_role[each.key].name

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.environment}-${each.value.cluster_name}-emr-ec2-profile"
      Cluster = each.key
    }
  )
}

#=================================================================
# IAM Role for EMR Auto Scaling
#=================================================================
resource "aws_iam_role" "emr_autoscaling_role" {
  for_each = { for k, v in var.emr_clusters : k => v if v.enable_autoscaling }
  
  name = "${var.environment}-${each.value.cluster_name}-emr-autoscaling-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = ["elasticmapreduce.amazonaws.com", "application-autoscaling.amazonaws.com"]
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.environment}-${each.value.cluster_name}-emr-autoscaling-role"
      Cluster = each.key
    }
  )
}

resource "aws_iam_role_policy_attachment" "emr_autoscaling_policy" {
  for_each = { for k, v in var.emr_clusters : k => v if v.enable_autoscaling }
  
  role       = aws_iam_role.emr_autoscaling_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforAutoScalingRole"
}

#=================================================================
# Security Group for EMR Master Node (No inline rules)
#=================================================================
resource "aws_security_group" "emr_master_sg" {
  for_each = var.emr_clusters
  
  name        = "${var.environment}-${each.value.cluster_name}-emr-master-sg"
  description = "Security group for EMR master node - ${each.value.cluster_name}"
  vpc_id      = var.vpc_id

  # Only egress rule inline (no dependencies)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.environment}-${each.value.cluster_name}-emr-master-sg"
      Cluster = each.key
    }
  )
}

#=================================================================
# Security Group for EMR Worker Nodes (No inline rules)
#=================================================================
resource "aws_security_group" "emr_worker_sg" {
  for_each = var.emr_clusters
  
  name        = "${var.environment}-${each.value.cluster_name}-emr-worker-sg"
  description = "Security group for EMR worker nodes - ${each.value.cluster_name}"
  vpc_id      = var.vpc_id

  # Only egress rule inline (no dependencies)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.environment}-${each.value.cluster_name}-emr-worker-sg"
      Cluster = each.key
    }
  )
}

#=================================================================
# Security Group for EMR Service Access (Required for private subnets)
#=================================================================
resource "aws_security_group" "emr_service_sg" {
  for_each = var.emr_clusters
  
  name        = "${var.environment}-${each.value.cluster_name}-emr-service-sg"
  description = "Security group for EMR service access - ${each.value.cluster_name}"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.environment}-${each.value.cluster_name}-emr-service-sg"
      Cluster = each.key
    }
  )
}

#=================================================================
# Security Group Rules for Master (Separate Resources)
#=================================================================

# SSH access to master
resource "aws_security_group_rule" "master_ssh" {
  for_each = { for k, v in var.emr_clusters : k => v if length(v.allow_ssh_from_cidr) > 0 }
  
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = each.value.allow_ssh_from_cidr
  security_group_id = aws_security_group.emr_master_sg[each.key].id
  description       = "SSH access"
}

# Master accepts traffic from workers
resource "aws_security_group_rule" "master_from_workers" {
  for_each = var.emr_clusters
  
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.emr_worker_sg[each.key].id
  security_group_id        = aws_security_group.emr_master_sg[each.key].id
  description              = "All traffic from worker nodes"
}

# Master self-reference (for multi-master HA)
resource "aws_security_group_rule" "master_self" {
  for_each = var.emr_clusters
  
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.emr_master_sg[each.key].id
  description       = "Master to master communication"
}

# Hive Metastore access
resource "aws_security_group_rule" "master_hive" {
  for_each = { 
    for k, v in var.emr_clusters : k => v 
    if contains(v.applications, "Hive") && length(v.allow_hive_from_cidr) > 0 
  }
  
  type              = "ingress"
  from_port         = 9083
  to_port           = 9083
  protocol          = "tcp"
  cidr_blocks       = each.value.allow_hive_from_cidr
  security_group_id = aws_security_group.emr_master_sg[each.key].id
  description       = "Hive Metastore access"
}

# Spark History Server
resource "aws_security_group_rule" "master_spark_ui" {
  for_each = { 
    for k, v in var.emr_clusters : k => v 
    if contains(v.applications, "Spark") && length(v.allow_web_ui_from_cidr) > 0 
  }
  
  type              = "ingress"
  from_port         = 18080
  to_port           = 18080
  protocol          = "tcp"
  cidr_blocks       = each.value.allow_web_ui_from_cidr
  security_group_id = aws_security_group.emr_master_sg[each.key].id
  description       = "Spark History Server"
}

# YARN Resource Manager UI
resource "aws_security_group_rule" "master_yarn_ui" {
  for_each = { 
    for k, v in var.emr_clusters : k => v 
    if length(v.allow_web_ui_from_cidr) > 0 
  }
  
  type              = "ingress"
  from_port         = 8088
  to_port           = 8088
  protocol          = "tcp"
  cidr_blocks       = each.value.allow_web_ui_from_cidr
  security_group_id = aws_security_group.emr_master_sg[each.key].id
  description       = "YARN Resource Manager UI"
}

# Ganglia monitoring
resource "aws_security_group_rule" "master_ganglia" {
  for_each = { 
    for k, v in var.emr_clusters : k => v 
    if length(v.allow_web_ui_from_cidr) > 0 
  }
  
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = each.value.allow_web_ui_from_cidr
  security_group_id = aws_security_group.emr_master_sg[each.key].id
  description       = "Ganglia monitoring UI"
}

#=================================================================
# Security Group Rules for Service Access (Required for EMR)
#=================================================================

# Service SG accepts traffic from master on port 9443 (EMR service communication)
resource "aws_security_group_rule" "service_from_master" {
  for_each = var.emr_clusters
  
  type                     = "ingress"
  from_port                = 9443
  to_port                  = 9443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.emr_master_sg[each.key].id
  security_group_id        = aws_security_group.emr_service_sg[each.key].id
  description              = "EMR service communication from master"
}

#=================================================================
# Security Group Rules for Workers (Separate Resources)
#=================================================================

# Workers accept traffic from master
resource "aws_security_group_rule" "worker_from_master" {
  for_each = var.emr_clusters
  
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.emr_master_sg[each.key].id
  security_group_id        = aws_security_group.emr_worker_sg[each.key].id
  description              = "All traffic from master node"
}

# Worker self-reference (worker-to-worker communication)
resource "aws_security_group_rule" "worker_self" {
  for_each = var.emr_clusters
  
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.emr_worker_sg[each.key].id
  description       = "Worker to worker communication"
}

#=================================================================
# CloudWatch Log Group for EMR
#=================================================================
resource "aws_cloudwatch_log_group" "emr_logs" {
  for_each = var.emr_clusters
  
  name              = "/aws/emr/${var.environment}-${each.value.cluster_name}"
  retention_in_days = each.value.log_retention_days

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.environment}-${each.value.cluster_name}-emr-logs"
      Cluster = each.key
    }
  )
}

#=================================================================
# S3 Bucket for EMR Logs
#=================================================================
resource "aws_s3_bucket" "emr_logs" {
  for_each = { for k, v in var.emr_clusters : k => v if v.enable_s3_logging }
  
  bucket = "${var.environment}-${each.value.cluster_name}-emr-logs"

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.environment}-${each.value.cluster_name}-emr-logs"
      Cluster = each.key
    }
  )
}

resource "aws_s3_bucket_versioning" "emr_logs" {
  for_each = { for k, v in var.emr_clusters : k => v if v.enable_s3_logging }
  
  bucket = aws_s3_bucket.emr_logs[each.key].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "emr_logs" {
  for_each = { for k, v in var.emr_clusters : k => v if v.enable_s3_logging }
  
  bucket = aws_s3_bucket.emr_logs[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = each.value.kms_key_id != "" ? "aws:kms" : "AES256"
      kms_master_key_id = each.value.kms_key_id != "" ? each.value.kms_key_id : null
    }
  }
}

resource "aws_s3_bucket_public_access_block" "emr_logs" {
  for_each = { for k, v in var.emr_clusters : k => v if v.enable_s3_logging }
  
  bucket = aws_s3_bucket.emr_logs[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#=================================================================
# EMR Cluster
#=================================================================
resource "aws_emr_cluster" "cluster" {
  for_each = var.emr_clusters
  
  name          = "${var.environment}-${each.value.cluster_name}"
  release_label = each.value.emr_release_label
  applications  = each.value.applications

  service_role = aws_iam_role.emr_service_role[each.key].arn
  autoscaling_role = each.value.enable_autoscaling ? aws_iam_role.emr_autoscaling_role[each.key].arn : null

  termination_protection            = each.value.termination_protection
  keep_job_flow_alive_when_no_steps = each.value.keep_alive_when_no_steps
  log_uri                           = each.value.enable_s3_logging ? "s3://${aws_s3_bucket.emr_logs[each.key].id}/logs/" : null

  #=================================================================
  # EC2 Configuration
  #=================================================================
  ec2_attributes {
    subnet_id                         = each.value.subnet_id
    emr_managed_master_security_group = aws_security_group.emr_master_sg[each.key].id
    emr_managed_slave_security_group  = aws_security_group.emr_worker_sg[each.key].id
    service_access_security_group     = aws_security_group.emr_service_sg[each.key].id
    instance_profile                  = aws_iam_instance_profile.emr_ec2_profile[each.key].arn
    key_name                          = each.value.key_name != "" ? each.value.key_name : null
  }

  #=================================================================
  # Master Node Configuration
  #=================================================================
  master_instance_group {
    instance_type  = each.value.master_instance_type
    instance_count = 1
    name           = "Master"

    ebs_config {
      size                 = each.value.master_ebs_size
      type                 = each.value.master_ebs_type
      volumes_per_instance = 1
    }
  }

  #=================================================================
  # Core Nodes Configuration
  #=================================================================
  core_instance_group {
    instance_type  = each.value.core_instance_type
    instance_count = each.value.core_instance_count
    name           = "Core"

    ebs_config {
      size                 = each.value.core_ebs_size
      type                 = each.value.core_ebs_type
      volumes_per_instance = 1
    }
  }

  #=================================================================
  # Bootstrap Actions
  #=================================================================
  dynamic "bootstrap_action" {
    for_each = each.value.bootstrap_actions
    content {
      name = bootstrap_action.value.name
      path = bootstrap_action.value.path
      args = bootstrap_action.value.args
    }
  }

  #=================================================================
  # Steps (for transient clusters)
  #=================================================================
  dynamic "step" {
    for_each = each.value.steps
    content {
      name              = step.value.name
      action_on_failure = step.value.action_on_failure

      hadoop_jar_step {
        jar  = step.value.hadoop_jar_step.jar
        args = step.value.hadoop_jar_step.args
      }
    }
  }

  #=================================================================
  # Configurations (Spark, Hadoop, Hive, etc.)
  #=================================================================
  configurations_json = jsonencode(each.value.configurations)

  #=================================================================
  # Tags
  #=================================================================
  tags = merge(
    var.common_tags,
    {
      Name        = "${var.environment}-${each.value.cluster_name}"
      Environment = var.environment
      Cluster     = each.key
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.emr_service_policy,
    aws_iam_role_policy_attachment.emr_ec2_policy
  ]
}

#=================================================================
# EMR Managed Scaling Policy (for Auto-Scaling)
#=================================================================
resource "aws_emr_managed_scaling_policy" "cluster_scaling" {
  for_each = { for k, v in var.emr_clusters : k => v if v.enable_autoscaling }
  
  cluster_id = aws_emr_cluster.cluster[each.key].id

  compute_limits {
    unit_type                       = "Instances"
    minimum_capacity_units          = each.value.core_autoscaling_min
    maximum_capacity_units          = each.value.core_autoscaling_max
    maximum_ondemand_capacity_units = each.value.core_autoscaling_max
    maximum_core_capacity_units     = each.value.core_autoscaling_max
  }
}
