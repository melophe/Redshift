# Workload Management (WLM)

## What is WLM?

WLM (Workload Management) is a mechanism to **manage query priority and resource allocation**.

```
【Problem】
Heavy batch queries consume all resources
→ Light dashboard queries are blocked

【WLM Solution】
Queue 1: For dashboards (high priority, light queries)
Queue 2: For batch jobs (low priority, heavy queries)
→ Light queries are not blocked
```

## How WLM Works

```
┌─────────────────────────────────────────────────┐
│                  Query Received                  │
└─────────────────────┬───────────────────────────┘
                      │
         ┌────────────┴────────────┐
         ▼                         ▼
┌─────────────────┐      ┌─────────────────┐
│   Queue 1       │      │   Queue 2       │
│   dashboard     │      │   etl           │
│                 │      │                 │
│   Memory: 50%   │      │   Memory: 30%   │
│   Concurrency:10│      │   Concurrency: 3│
└─────────────────┘      └─────────────────┘
         │                         │
         └────────────┬────────────┘
                      ▼
              ┌───────────────┐
              │ Compute Nodes │
              └───────────────┘
```

## Auto WLM vs Manual WLM

| | Auto WLM | Manual WLM |
|---|---------|---------|
| Memory allocation | Automatic | Manual |
| Concurrency | Auto-adjusted | Fixed |
| Configuration complexity | Simple | Complex |
| Recommended | **Most cases** | Special requirements only |

## Queues

### Queue Configuration Options

| Option | Description |
|--------|-------------|
| Name | Queue identifier |
| Concurrency | Max simultaneous queries |
| Memory % | Memory allocated to queue |
| Timeout | Max query execution time |
| User Groups | Which users use this queue |
| Query Groups | Which query groups use this queue |

### Routing to Queues

```sql
-- Route by user group
CREATE USER dashboard_user IN GROUP dashboard_group;
-- → Automatically routed to dashboard_group queue

-- Route by query group
SET query_group TO 'etl';
SELECT * FROM large_table;  -- → Routed to etl queue
RESET query_group;
```

## Auto WLM Configuration

### Configure in AWS Console

1. Redshift Console → Cluster → Workload Management
2. Edit Parameter Group
3. Add/Edit Queues

### Auto WLM Queue Example

```
Queue 1: "dashboard"
  - User Group: dashboard_users
  - Priority: Highest
  - Concurrency Scaling: ON

Queue 2: "etl"
  - Query Group: etl
  - Priority: Low
  - Timeout: 3600 seconds

Queue 3: "default"
  - Queries not matching above
  - Priority: Normal
```

## Priority Levels

Auto WLM supports priority settings:

| Priority | Description |
|----------|-------------|
| Highest | Execute first |
| High | High priority |
| Normal | Default |
| Low | Low priority |
| Lowest | Execute last |

```
Highest priority queries → Get resources first
Lowest priority queries → Wait for others to finish
```

## Concurrency Scaling

Automatically adds clusters when query load is high.

```
Normal:
┌──────────────┐
│ Main Cluster │ ← 3 concurrent queries
└──────────────┘

Peak (Concurrency Scaling ON):
┌──────────────┐  ┌──────────────┐
│ Main Cluster │  │ Scaling      │ ← Additional cluster
└──────────────┘  │ Cluster      │
                  └──────────────┘
```

## Query Monitoring

### Currently Running Queries

```sql
SELECT query, pid, user_name, starttime, query_text
FROM stv_recents
WHERE status = 'Running';
```

### Queue Status

```sql
SELECT * FROM stv_wlm_query_state;
```

### Queued Queries

```sql
SELECT * FROM stv_wlm_query_queue_state;
```

## Short Query Acceleration (SQA)

Automatically prioritizes short-running queries.

```
【Without SQA】
Short query → Normal queue → Waits behind heavy queries

【With SQA】
Short query → Fast lane → Executes immediately
```

```sql
-- Check short query threshold (seconds)
SHOW max_execution_time;
```

## Best Practices

1. **Use Auto WLM** - Manual only when necessary
2. **Classify workloads** - Dashboard, ETL, Ad-hoc
3. **Set priorities** - Dashboard > ETL
4. **Enable SQA** - Improve perceived speed for short queries
5. **Concurrency Scaling** - Handle peak loads
6. **Set timeouts** - Prevent runaway queries

## Configuration Example

```
【Typical 3-Queue Setup】

1. Dashboard Queue
   - Priority: Highest
   - User Group: bi_users
   - Concurrency Scaling: ON

2. ETL Queue
   - Priority: Low
   - Query Group: etl
   - Timeout: 3600 seconds

3. Default Queue
   - Priority: Normal
   - All other queries
```
