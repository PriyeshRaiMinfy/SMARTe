#=================================================================
# modules/msk/mskmain.tf
#=================================================================

# KMS Key
resource "aws_kms_key" "msk_encryption_key" {
  for_each = var.msk_clusters
  
  description             = "${var.environment}-${each.value.cluster_name}-msk-encryption-key"
  deletion_window_in_days = each.value.kms_deletion_window
  enable_key_rotation     = true

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.environment}-${each.value.cluster_name}-kms-key"
      Cluster = each.key
    }
  )
}

resource "aws_kms_alias" "msk_encryption_key_alias" {
  for_each = var.msk_clusters
  
  name          = "alias/${var.environment}-${each.value.cluster_name}-msk"
  target_key_id = aws_kms_key.msk_encryption_key[each.key].key_id
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "msk_broker_logs" {
  for_each = var.msk_clusters
  
  name              = "/aws/msk/${var.environment}-${each.value.cluster_name}"
  retention_in_days = each.value.log_retention_days

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.environment}-${each.value.cluster_name}-logs"
      Cluster = each.key
    }
  )
}

# IAM Role
resource "aws_iam_role" "msk_cloudwatch_logs_role" {
  for_each = var.msk_clusters
  
  name = "${var.environment}-${each.value.cluster_name}-msk-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "kafka.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.environment}-${each.value.cluster_name}-cw-role"
      Cluster = each.key
    }
  )
}

resource "aws_iam_role_policy" "msk_cloudwatch_logs_policy" {
  for_each = var.msk_clusters
  
  name = "${var.environment}-${each.value.cluster_name}-cw-policy"
  role = aws_iam_role.msk_cloudwatch_logs_role[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.msk_broker_logs[each.key].arn}:*"
    }]
  })
}

# Security Group
resource "aws_security_group" "msk_cluster_sg" {
  for_each = var.msk_clusters
  
  name        = "${var.environment}-${each.value.cluster_name}-sg"
  description = "Security group for MSK Kafka cluster ${each.value.cluster_name}"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Kafka TLS from application servers"
    from_port       = 9094
    to_port         = 9094
    protocol        = "tcp"
    security_groups = each.value.client_security_group_ids
  }

  ingress {
    description     = "Kafka SASL/SCRAM from application servers"
    from_port       = 9096
    to_port         = 9096
    protocol        = "tcp"
    security_groups = each.value.client_security_group_ids
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.environment}-${each.value.cluster_name}-sg"
      Cluster = each.key
    }
  )
}

# MSK Configuration
resource "aws_msk_configuration" "kafka_config" {
  for_each = var.msk_clusters
  
  name           = "${var.environment}-${each.value.cluster_name}-config"
  kafka_versions = [each.value.kafka_version]

  server_properties = <<PROPERTIES
auto.create.topics.enable = ${each.value.auto_create_topics}
default.replication.factor = ${each.value.default_replication_factor}
min.insync.replicas = ${each.value.min_insync_replicas}
num.io.threads = 8
num.network.threads = 5
num.partitions = ${each.value.default_num_partitions}
num.replica.fetchers = 2
replica.lag.time.max.ms = 30000
socket.receive.buffer.bytes = 102400
socket.request.max.bytes = 104857600
socket.send.buffer.bytes = 102400
unclean.leader.election.enable = false
zookeeper.session.timeout.ms = 18000
log.retention.hours = ${each.value.log_retention_hours}
log.segment.bytes = 1073741824
compression.type = ${each.value.compression_type}
PROPERTIES

  description = "MSK configuration for ${each.value.cluster_name}"
}

# MSK Cluster
resource "aws_msk_cluster" "kafka_cluster" {
  for_each = var.msk_clusters
  
  cluster_name           = "${var.environment}-${each.value.cluster_name}"
  kafka_version          = each.value.kafka_version
  number_of_broker_nodes = each.value.number_of_broker_nodes

  broker_node_group_info {
    instance_type   = each.value.broker_instance_type
    client_subnets  = each.value.private_subnet_ids
    security_groups = [aws_security_group.msk_cluster_sg[each.key].id]

    storage_info {
      ebs_storage_info {
        volume_size = each.value.broker_volume_size
        
        dynamic "provisioned_throughput" {
          for_each = each.value.enable_provisioned_throughput ? [1] : []
          content {
            enabled           = true
            volume_throughput = each.value.volume_throughput
          }
        }
      }
    }

    connectivity_info {
      public_access {
        type = "DISABLED"
      }
    }
  }

  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.msk_encryption_key[each.key].arn

    encryption_in_transit {
      client_broker = each.value.encryption_in_transit_client_broker
      in_cluster    = true
    }
  }

  enhanced_monitoring = each.value.enhanced_monitoring_level

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = each.value.enable_jmx_exporter
      }
      node_exporter {
        enabled_in_broker = each.value.enable_node_exporter
      }
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk_broker_logs[each.key].name
      }
      
      firehose {
        enabled = false
      }
      
      s3 {
        enabled = each.value.enable_s3_logs
        bucket  = each.value.enable_s3_logs ? each.value.s3_logs_bucket : null
        prefix  = each.value.enable_s3_logs ? each.value.s3_logs_prefix : null
      }
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.kafka_config[each.key].arn
    revision = aws_msk_configuration.kafka_config[each.key].latest_revision
  }

  client_authentication {
    sasl {
      scram = each.value.enable_sasl_scram
    }
    unauthenticated = each.value.allow_unauthenticated_access
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.environment}-${each.value.cluster_name}"
      Environment = var.environment
      Cluster     = each.key
    }
  )

  depends_on = [aws_iam_role_policy.msk_cloudwatch_logs_policy]
}

# Secrets Manager
resource "aws_secretsmanager_secret" "msk_scram_credentials" {
  for_each = { for k, v in var.msk_clusters : k => v if v.enable_sasl_scram }
  
  name        = "AmazonMSK_${var.environment}-${each.value.cluster_name}-creds"
  description = "SASL/SCRAM credentials for ${each.value.cluster_name}"
  kms_key_id  = aws_kms_key.msk_encryption_key[each.key].arn

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.environment}-${each.value.cluster_name}-scram-secret"
      Cluster = each.key
    }
  )
}

resource "aws_secretsmanager_secret_version" "msk_scram_credentials_version" {
  for_each = { for k, v in var.msk_clusters : k => v if v.enable_sasl_scram }
  
  secret_id = aws_secretsmanager_secret.msk_scram_credentials[each.key].id
  
  secret_string = jsonencode({
    username = each.value.kafka_admin_username
    password = each.value.kafka_admin_password
  })
}

resource "aws_msk_scram_secret_association" "msk_scram_association" {
  for_each = { for k, v in var.msk_clusters : k => v if v.enable_sasl_scram }
  
  cluster_arn     = aws_msk_cluster.kafka_cluster[each.key].arn
  secret_arn_list = [aws_secretsmanager_secret.msk_scram_credentials[each.key].arn]

  depends_on = [aws_secretsmanager_secret_version.msk_scram_credentials_version]
}
