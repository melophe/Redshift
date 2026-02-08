# Redshift Serverless

## What is Redshift Serverless?

**Redshift without cluster management**.

```
【Provisioned (Traditional)】
Create cluster → Decide node count → Manage it

【Serverless】
Just use it → Auto-scaling → No management
```

## Provisioned vs Serverless

| | Provisioned | Serverless |
|---|-------------|------------|
| Cluster management | Required (nodes, types) | Not required |
| Scaling | Manual or scheduled | Automatic |
| Pricing | Per node per hour | Per compute used (RPU) |
| When idle | Still charged | Not charged |
| Best for | Predictable, always-on | Variable, intermittent |

## Core Concepts

### 1. Workgroup

Unit of compute resources.

```
┌─────────────────────────────────────┐
│          Workgroup                   │
│                                      │
│   ┌──────────────────────────────┐  │
│   │  Compute Resources (RPU)      │  │
│   │  32 - 512 RPU                 │  │
│   └──────────────────────────────┘  │
│                                      │
│   Settings: Base RPU, Max RPU       │
└─────────────────────────────────────┘
```

### 2. Namespace

Storage for database objects.

```
┌─────────────────────────────────────┐
│          Namespace                   │
│                                      │
│   - Databases                        │
│   - Schemas                          │
│   - Tables                           │
│   - Users                            │
│   - IAM Roles                        │
└─────────────────────────────────────┘
```

### Relationship

```
┌─────────────┐      ┌─────────────┐
│  Workgroup  │ ───→ │  Namespace  │
│  (Compute)  │      │  (Data)     │
└─────────────┘      └─────────────┘

One Namespace can have multiple Workgroups
→ Separate Workgroups for dev and prod
```

## RPU (Redshift Processing Unit)

Unit of compute capacity.

```
【RPU Settings】
Base RPU: 32   ← Minimum (zero when idle)
Max RPU: 256   ← Maximum (auto-scale limit)

Query arrives → RPU automatically increases → Decreases when done
```

| RPU | Use Case |
|-----|----------|
| 32 | Small, development |
| 128 | Medium workloads |
| 256+ | Large, high load |

## Pricing Model

```
【Provisioned】
Nodes × Hours = Cost
→ Charged even when not in use

【Serverless】
RPU × Seconds = Cost
→ Pay only for what you use
→ Free when idle!
```

### Pricing Example

```
Serverless:
- Base: 32 RPU
- 8 hours of queries per day
- Cost = 32 RPU × 8 hours × $0.36/RPU-hour = $92.16/day

Provisioned (dc2.large 4 nodes):
- 24 hours running
- Cost = 4 × 24 hours × $0.25/hour = $24/day

→ Always-on: Provisioned
→ Intermittent: Serverless
```

## Setup

### 1. Create Namespace

```
AWS Console → Redshift → Serverless → Create namespace

- Namespace name: my-namespace
- Database name: dev
- Admin username/password
- IAM role
```

### 2. Create Workgroup

```
AWS Console → Redshift → Serverless → Create workgroup

- Workgroup name: my-workgroup
- Base capacity: 32 RPU
- Namespace: my-namespace
- VPC settings
```

### 3. Connect

```sql
-- Endpoint example
my-workgroup.123456789.ap-northeast-1.redshift-serverless.amazonaws.com:5439

-- psql
psql -h my-workgroup.123456789.ap-northeast-1.redshift-serverless.amazonaws.com \
     -p 5439 -U admin -d dev
```

## Serverless Features

### Auto Scaling

```
Low queries → 32 RPU
    ↓
More queries → 64 RPU → 128 RPU → 256 RPU
    ↓
Less queries → 128 RPU → 64 RPU → 32 RPU → 0 (idle)
```

### Usage Limits

```sql
-- Set max RPU-hours per day (cost control)
-- Configure in AWS Console: Usage limit
```

### Snapshots

```
Same snapshot capability as Provisioned
→ Backup, restore, cross-region copy
```

## Migration from Provisioned to Serverless

```
1. Create snapshot of Provisioned cluster
2. Create Serverless Namespace
3. Restore snapshot to Namespace
4. Update application connection
```

## When to Use Serverless?

| Scenario | Recommendation |
|----------|----------------|
| 24/7 dashboard | Provisioned |
| Nightly batch only | **Serverless** |
| Dev/test environment | **Serverless** |
| Variable workloads | **Serverless** |
| Predictable high load | Provisioned |
| Cost optimization | Compare both |

## Best Practices

1. **Use Serverless for dev** - Cost savings
2. **Start with low Base RPU** - Start at 32
3. **Set Usage Limits** - Prevent budget overruns
4. **Check VPC settings** - Security groups, subnets
5. **Set up monitoring** - CloudWatch for RPU usage
