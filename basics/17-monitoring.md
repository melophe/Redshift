# Monitoring & Operations

Learn about Redshift monitoring and operations.

## Overview

```
┌─────────────────────────────────────────────────────┐
│               Monitoring Aspects                    │
├─────────────────────────────────────────────────────┤
│  1. Performance    Query time, CPU, Memory          │
│  2. Storage        Usage, Growth trends             │
│  3. Connections    Concurrent connections, Errors   │
│  4. Queries        Slow queries, Error queries      │
│  5. Cost           RPU usage, Storage cost          │
└─────────────────────────────────────────────────────┘
```

## 1. System Tables & Views

### Commonly Used System Views

| View | Purpose |
|------|---------|
| SVV_TABLE_INFO | Table information |
| SVL_QUERY_SUMMARY | Query summary |
| STL_QUERY | Query history |
| STL_WLM_QUERY | WLM queue info |
| SVL_QLOG | Query log |

### Check Table Information

```sql
-- Table size and row count
SELECT
    "table" as table_name,
    size as size_mb,
    tbl_rows as row_count,
    diststyle,
    sortkey1
FROM svv_table_info
ORDER BY size DESC;
```

### Check Query History

```sql
-- Recent queries
SELECT
    query,
    substring(querytxt, 1, 100) as query_text,
    starttime,
    endtime,
    DATEDIFF(seconds, starttime, endtime) as duration_sec
FROM stl_query
WHERE userid > 1  -- Exclude system queries
ORDER BY starttime DESC
LIMIT 20;
```

### Identify Slow Queries

```sql
-- Top 10 slowest queries
SELECT
    query,
    substring(querytxt, 1, 100) as query_text,
    DATEDIFF(seconds, starttime, endtime) as duration_sec,
    aborted
FROM stl_query
WHERE userid > 1
ORDER BY duration_sec DESC
LIMIT 10;
```

## 2. CloudWatch Metrics

### Key Metrics

| Metric | Description | Alert Level |
|--------|-------------|-------------|
| CPUUtilization | CPU usage | > 80% |
| PercentageDiskSpaceUsed | Disk usage | > 75% |
| DatabaseConnections | Connection count | Watch limits |
| ReadIOPS / WriteIOPS | I/O operations | Watch spikes |
| QueryDuration | Query execution time | Compare to baseline |

### Serverless-Specific Metrics

| Metric | Description |
|--------|-------------|
| ComputeSeconds | RPU seconds used |
| ComputeCapacity | Current RPU |
| QueriesCompletedPerSecond | Queries completed per second |

### CloudWatch Alarm Example

```
Alarm: Redshift-HighCPU
Metric: CPUUtilization
Condition: > 80% for 5 minutes
Action: SNS notification

Alarm: Redshift-DiskSpace
Metric: PercentageDiskSpaceUsed
Condition: > 75%
Action: SNS notification
```

## 3. Query Monitoring

### Check Running Queries

```sql
-- Currently running queries
SELECT
    query,
    pid,
    userid,
    starttime,
    substring(querytxt, 1, 100) as query_text
FROM stv_recents
WHERE status = 'Running';
```

### Cancel Queries

```sql
-- Cancel specific query
CANCEL <query_id>;

-- Terminate process
SELECT pg_terminate_backend(<pid>);
```

### Check Query Queue

```sql
-- WLM queue status
SELECT
    service_class,
    num_queued_queries,
    num_executing_queries,
    query_cpu_time,
    query_blocks_read
FROM stv_wlm_service_class_state;
```

## 4. Table Maintenance

### Check VACUUM Status

```sql
-- Tables needing VACUUM
SELECT
    "table" as table_name,
    unsorted,
    vacuum_sort_benefit
FROM svv_table_info
WHERE unsorted > 5  -- More than 5% unsorted
ORDER BY unsorted DESC;
```

### Check ANALYZE Status

```sql
-- Tables with stale statistics
SELECT
    "table" as table_name,
    stats_off
FROM svv_table_info
WHERE stats_off > 10  -- More than 10% off
ORDER BY stats_off DESC;
```

### Run Maintenance

```sql
-- VACUUM specific table
VACUUM fact_lesson_completions;

-- ANALYZE specific table
ANALYZE fact_lesson_completions;

-- All tables (caution: time-consuming)
VACUUM;
ANALYZE;
```

## 5. Cost Monitoring (Serverless)

### Check RPU Usage

```sql
-- Daily RPU usage
SELECT
    trunc(start_time) as date,
    SUM(compute_seconds) as total_compute_seconds,
    SUM(compute_seconds) / 3600.0 as compute_hours
FROM sys_serverless_usage
GROUP BY trunc(start_time)
ORDER BY date DESC
LIMIT 30;
```

### Cost Estimation

```
RPU hourly cost (Tokyo): $0.494/RPU hour

Example: 100 RPU hours per day
    100 × $0.494 = $49.4/day
```

## 6. Dashboard Examples

### Daily Report Query

```sql
-- Daily summary
SELECT
    'Query Count' as metric,
    COUNT(*) as value
FROM stl_query
WHERE starttime >= CURRENT_DATE
UNION ALL
SELECT
    'Avg Duration (sec)',
    AVG(DATEDIFF(seconds, starttime, endtime))
FROM stl_query
WHERE starttime >= CURRENT_DATE
  AND userid > 1
UNION ALL
SELECT
    'Error Queries',
    COUNT(*)
FROM stl_query
WHERE starttime >= CURRENT_DATE
  AND aborted = 1;
```

### Connection Status

```sql
-- Current connections
SELECT
    COUNT(*) as total_connections,
    COUNT(CASE WHEN query > 0 THEN 1 END) as active_connections
FROM stv_sessions;
```

## 7. Troubleshooting

### Common Issues and Solutions

| Issue | How to Check | Solution |
|-------|--------------|----------|
| Slow queries | EXPLAIN + STL_QUERY | Review keys, VACUUM |
| Disk full | svv_table_info | Delete data, Resize |
| Can't connect | CloudWatch | Check security groups |
| High cost | sys_serverless_usage | Optimize queries, Adjust RPU |

### Check Locks

```sql
-- Check lock waits
SELECT
    l.query,
    l.table_id,
    l.mode,
    t.name as table_name
FROM stv_locks l
JOIN stv_tbl_perm t ON l.table_id = t.id;
```

### Check Deadlocks

```sql
-- Blocking queries
SELECT
    blocked.query as blocked_query,
    blocking.query as blocking_query,
    blocked.starttime
FROM stv_recents blocked
JOIN stv_recents blocking
  ON blocked.pid != blocking.pid
WHERE blocked.status = 'Waiting';
```

## Best Practices

### Monitoring Checklist

```
□ CloudWatch alarms (CPU, Disk, Connections)
□ Daily query performance review
□ Weekly VACUUM/ANALYZE check
□ Monthly cost analysis
□ Regular slow query tuning
```

### Operations Schedule Example

```
Daily:
  - Check CloudWatch dashboard
  - Review slow queries

Weekly:
  - Decide on VACUUM/ANALYZE
  - Check storage usage

Monthly:
  - Cost analysis
  - Performance trend review
  - Cleanup unused objects
```

## Summary

| Aspect | Tool | Frequency |
|--------|------|-----------|
| Performance | System tables, CloudWatch | Daily |
| Storage | svv_table_info | Weekly |
| Cost | sys_serverless_usage | Monthly |
| Maintenance | VACUUM, ANALYZE | As needed |
