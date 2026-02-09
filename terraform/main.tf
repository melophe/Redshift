terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"  # Tokyo region
}

# Namespace (database container)
resource "aws_redshiftserverless_namespace" "main" {
  namespace_name      = "my-namespace"
  admin_username      = "admin"
  admin_user_password = var.admin_password
  db_name             = "dev"
}

# Workgroup (compute resources)
resource "aws_redshiftserverless_workgroup" "main" {
  namespace_name = aws_redshiftserverless_namespace.main.namespace_name
  workgroup_name = "my-workgroup"
  base_capacity  = 8  # Minimum RPU

  publicly_accessible = true  # For hands-on (set false in production)
}

# Output connection info
output "endpoint" {
  value       = aws_redshiftserverless_workgroup.main.endpoint
  description = "Redshift Serverless endpoint"
}

output "workgroup_name" {
  value = aws_redshiftserverless_workgroup.main.workgroup_name
}
