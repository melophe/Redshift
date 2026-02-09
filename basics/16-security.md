# Security

Learn about Redshift security features.

## Overview

```
┌─────────────────────────────────────────────────────┐
│                  Security Layers                    │
├─────────────────────────────────────────────────────┤
│  1. Network       VPC, Security Groups              │
│  2. Authentication IAM, DB Users                    │
│  3. Authorization  GRANT/REVOKE, Roles              │
│  4. Encryption     At Rest, In Transit              │
│  5. Auditing       Audit Logs                       │
└─────────────────────────────────────────────────────┘
```

## 1. Network Security

### VPC Configuration

```
┌─────────────────────────────────────┐
│              VPC                    │
│  ┌─────────────────────────────┐   │
│  │      Private Subnet         │   │
│  │  ┌───────────────────────┐  │   │
│  │  │     Redshift          │  │   │
│  │  └───────────────────────┘  │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

### Security Groups

```sql
-- Recommended production settings
Inbound:
  - Port 5439 from application servers only

Outbound:
  - Minimum required
```

### Public Access

| Environment | publicly_accessible |
|-------------|---------------------|
| Dev/Hands-on | true (convenient but caution) |
| Production | **false** (recommended) |

## 2. Authentication

### IAM Authentication (Recommended)

```sql
-- Get temporary credentials
aws redshift get-cluster-credentials \
  --db-user myuser \
  --cluster-identifier mycluster
```

### Database Users

```sql
-- Create user
CREATE USER analyst PASSWORD 'SecurePassword123!';

-- Change password
ALTER USER analyst PASSWORD 'NewSecurePassword456!';
```

### Secrets Manager Integration

```python
# Application connection example
import boto3

client = boto3.client('secretsmanager')
secret = client.get_secret_value(SecretId='redshift/credentials')
```

## 3. Authorization (Permission Management)

### Basic Permissions

```sql
-- Schema access
GRANT USAGE ON SCHEMA public TO analyst;

-- SELECT permission on table
GRANT SELECT ON TABLE sales TO analyst;

-- Permission on all tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO analyst;
```

### Revoking Permissions

```sql
REVOKE SELECT ON TABLE sales FROM analyst;
```

### Role-Based Access Control

```sql
-- Create role
CREATE ROLE data_reader;

-- Grant permission to role
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ROLE data_reader;

-- Grant role to user
GRANT ROLE data_reader TO analyst;
```

### Row-Level Security (RLS)

```sql
-- Create RLS policy
CREATE RLS POLICY region_policy
WITH (region_id INT)
USING (region_id = current_setting('app.region_id')::INT);

-- Attach to table
ALTER TABLE sales ATTACH RLS POLICY region_policy;
```

## 4. Encryption

### Encryption at Rest

```sql
-- Specify at cluster creation
CREATE CLUSTER ... ENCRYPTED;

-- Using KMS key
CREATE CLUSTER ...
  ENCRYPTED
  KMS_KEY_ID 'arn:aws:kms:...';
```

### Encryption in Transit

```
Client ──── SSL/TLS ──── Redshift
```

```sql
-- Require SSL
ALTER USER analyst SET require_ssl = true;
```

### Verification

```sql
-- Check encryption status
SELECT encrypted FROM svv_table_info WHERE table = 'sales';
```

## 5. Audit Logging

### Enable Audit Logging

```sql
-- Set in parameter group
enable_user_activity_logging = true
```

### Log Types

| Log | Content |
|-----|---------|
| Connection log | Connection/disconnection records |
| User log | User change records |
| User activity log | Query execution records |

### Viewing Logs

```sql
-- Recent queries
SELECT
    starttime,
    userid,
    query
FROM stl_query
ORDER BY starttime DESC
LIMIT 20;

-- Login history
SELECT
    event_time,
    username,
    remotehost
FROM stl_connection_log
ORDER BY event_time DESC;
```

### Export to S3

```sql
-- Save audit logs to S3
-- Configure via AWS Console or CLI
aws redshift modify-cluster \
  --cluster-identifier mycluster \
  --logging-properties '{"BucketName":"my-audit-logs"}'
```

## Best Practices

### Production Checklist

```
□ Place in private subnet within VPC
□ Allow only required ports in security group
□ publicly_accessible = false
□ Enable encryption (KMS recommended)
□ Require SSL connections
□ Enable audit logging
□ Apply least privilege with GRANT
□ Manage passwords with Secrets Manager
□ Regular password rotation
```

### Permission Design Example

```
┌─────────────────────────────────────────┐
│           Role Design                   │
├─────────────────────────────────────────┤
│ admin_role      Full access             │
│ etl_role        INSERT/UPDATE/DELETE    │
│ analyst_role    SELECT only             │
│ viewer_role     SELECT on specific tables│
└─────────────────────────────────────────┘
```

```sql
-- Example: analyst role
CREATE ROLE analyst_role;
GRANT USAGE ON SCHEMA public TO ROLE analyst_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ROLE analyst_role;

-- ETL role
CREATE ROLE etl_role;
GRANT ALL ON SCHEMA staging TO ROLE etl_role;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ROLE etl_role;
```

## Summary

| Layer | Feature | Production Recommendation |
|-------|---------|---------------------------|
| Network | VPC, SG | Private subnet |
| Authentication | IAM, DB User | IAM + Secrets Manager |
| Authorization | GRANT, Role | Least privilege + role-based |
| Encryption | KMS | Required |
| Auditing | Audit Log | Required |
