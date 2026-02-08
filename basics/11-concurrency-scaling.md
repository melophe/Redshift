# Concurrency Scaling

## What is Concurrency Scaling?

A feature that **automatically launches additional clusters** when queries spike.

```
【Normal】
┌──────────────┐
│ Main Cluster │ ← Handles all queries
└──────────────┘

【Peak (Concurrency Scaling ON)】
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Main Cluster │  │ Scaling      │  │ Scaling      │
│              │  │ Cluster 1    │  │ Cluster 2    │
└──────────────┘  └──────────────┘  └──────────────┘
        ↑                ↑                ↑
        └────────────────┴────────────────┘
              Queries distributed
```

## Why is it Needed?

```
【Problem】
9 AM: 100 users access dashboard
→ Queries queue up
→ Users wait

【Concurrency Scaling Solution】
→ Additional clusters auto-launch
→ Queries processed in parallel
→ No wait time
```

## How it Works

```
1. Queries queue up
2. Redshift detects the load
3. Scaling cluster launches (seconds)
4. Queries distributed
5. Cluster terminates when load drops
```

## Enabling

### Enable on WLM Queue

```
AWS Console → Redshift → Cluster → Workload Management

Queue: dashboard
  - Concurrency Scaling: ON ← Here
```

### Choosing Target Queues

```
【Should Enable】
- Dashboard (users waiting)
- Ad-hoc queries (analysts waiting)

【Should Not Enable】
- ETL batch (runs at night, not urgent)
- Scheduled reports (runs on schedule)
```

## Pricing

```
【Free Credits】
Every 24 hours, you get 1 hour of scaling credits per main cluster

Example: dc2.large 4-node cluster
→ 4 nodes × 1 hour = 4 node-hours free daily

【Beyond Free Tier】
Standard on-demand rates
```

## Limitations

Operations that **cannot** run on scaling clusters:

| Operation | Scaling Cluster |
|-----------|-----------------|
| SELECT (reads) | ✅ Possible |
| COPY | ❌ Not possible |
| INSERT/UPDATE/DELETE | ❌ Not possible |
| VACUUM | ❌ Not possible |
| DDL (CREATE/ALTER/DROP) | ❌ Not possible |

**Only read queries** run on scaling clusters.

## Monitoring

### Current Scaling Status

```sql
SELECT * FROM stv_concurrency_scaling_usage;
```

### Scaling Usage History

```sql
SELECT
    start_time,
    end_time,
    query_count,
    duration_seconds
FROM svcs_concurrency_scaling_usage
ORDER BY start_time DESC;
```

### Which Queries Used Scaling

```sql
SELECT query, queue_name, concurrency_scaling_status
FROM stl_query
WHERE concurrency_scaling_status = 'SCALED';
```

## Concurrency Scaling vs Serverless

| | Concurrency Scaling | Serverless |
|---|---------------------|------------|
| Base | Provisioned cluster | None |
| Scales | Read queries only | All queries |
| Startup time | Seconds | Seconds |
| Pricing | Usage time (free tier) | RPU usage |
| Use case | Peak handling | Always auto-scale |

## Best Practices

1. **Enable for dashboard queues** - Improve user experience
2. **Disable for ETL queues** - Writes not supported, save costs
3. **Use free credits** - Reset daily
4. **Set up monitoring** - Check scaling frequency
5. **If scaling often** - Consider cluster size upgrade

## Configuration Example

```
【Recommended Setup】

Queue 1: dashboard
  - Concurrency Scaling: ON ← Enabled
  - Priority: Highest

Queue 2: adhoc
  - Concurrency Scaling: ON ← Enabled
  - Priority: Normal

Queue 3: etl
  - Concurrency Scaling: OFF ← Disabled (write-heavy)
  - Priority: Low
```
