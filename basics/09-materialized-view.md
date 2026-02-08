# Materialized Views

## What is a Materialized View?

A view that **physically stores query results**.

```
【Regular View】
SELECT * FROM view → Executes query every time → Slow

【Materialized View】
SELECT * FROM mv → Returns stored results → Fast
```

## Regular View vs Materialized View

| | Regular View | Materialized View |
|---|-------------|-------------------|
| Data Storage | None (definition only) | Yes (stores results) |
| Query Speed | Computed each time (slow) | Pre-computed (fast) |
| Storage | None | Uses storage |
| Data Freshness | Always current | Requires REFRESH |

```
Regular View:
┌─────────────────┐
│ CREATE VIEW ... │ → Only stores definition
└─────────────────┘
          ↓ On query
    Computes and returns


Materialized View:
┌─────────────────┐      ┌─────────────────┐
│ CREATE MV ...   │  →   │ Stores results  │
└─────────────────┘      └─────────────────┘
                                  ↓ On query
                          Returns stored results (fast)
```

## Basic Syntax

### Create

```sql
CREATE MATERIALIZED VIEW mv_daily_sales AS
SELECT
    sale_date,
    region,
    SUM(amount) AS total_amount,
    COUNT(*) AS order_count
FROM sales
GROUP BY sale_date, region;
```

### Query

```sql
-- Use like a regular table
SELECT * FROM mv_daily_sales
WHERE region = 'Tokyo';
```

### Refresh (Update)

```sql
-- Manual refresh
REFRESH MATERIALIZED VIEW mv_daily_sales;
```

### Drop

```sql
DROP MATERIALIZED VIEW mv_daily_sales;
```

## Auto Refresh

Redshift automatically refreshes the MV.

```sql
CREATE MATERIALIZED VIEW mv_daily_sales
AUTO REFRESH YES
AS
SELECT sale_date, SUM(amount) AS total
FROM sales
GROUP BY sale_date;
```

| Setting | Description |
|---------|-------------|
| AUTO REFRESH YES | Enable auto refresh |
| AUTO REFRESH NO | Manual refresh only (default) |

## Incremental Refresh

Updates only changed data (fast).

```
【Full Refresh】
Recomputes all data → Slow

【Incremental Refresh】
Computes only changes → Fast
```

```sql
-- Conditions for incremental refresh:
-- - Simple SELECT/JOIN/GROUP BY
-- - Aggregate functions: SUM, COUNT, MIN, MAX, AVG
-- - No DELETEs on base table (INSERT only)
```

## Use Cases

### 1. Speed Up Aggregations

```sql
-- Running this every time is slow
SELECT region, SUM(amount)
FROM sales
WHERE sale_date >= '2024-01-01'
GROUP BY region;

-- Speed up with materialized view
CREATE MATERIALIZED VIEW mv_region_sales AS
SELECT region, sale_date, SUM(amount) AS total
FROM sales
GROUP BY region, sale_date;

-- This is fast
SELECT region, SUM(total)
FROM mv_region_sales
WHERE sale_date >= '2024-01-01'
GROUP BY region;
```

### 2. Dashboards

```sql
-- Pre-aggregated data for dashboards
CREATE MATERIALIZED VIEW mv_dashboard
AUTO REFRESH YES
AS
SELECT
    DATE_TRUNC('day', created_at) AS day,
    COUNT(*) AS daily_users,
    COUNT(DISTINCT user_id) AS unique_users
FROM user_events
GROUP BY DATE_TRUNC('day', created_at);
```

### 3. Cache Complex JOIN Results

```sql
CREATE MATERIALIZED VIEW mv_order_details AS
SELECT
    o.order_id,
    o.order_date,
    c.customer_name,
    p.product_name,
    o.quantity,
    o.amount
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN products p ON o.product_id = p.id;
```

## Automatic Query Rewriting

Redshift automatically uses MVs (user doesn't need to know).

```sql
-- User writes this query
SELECT region, SUM(amount)
FROM sales
GROUP BY region;

-- Redshift automatically rewrites to
SELECT region, SUM(total)
FROM mv_region_sales  -- Uses MV
GROUP BY region;
```

## Limitations

- Cannot use external tables (Spectrum) as base
- Some functions/syntax not supported
- Lock acquired during refresh
- Consumes storage

## Check Status

```sql
-- List MVs and their status
SELECT
    mv_name,
    state,        -- 'Active', 'Stale', etc.
    autorefresh,
    is_stale
FROM svv_mv_info;

-- Refresh history
SELECT * FROM svl_mv_refresh_status
ORDER BY starttime DESC;
```

## Best Practices

1. **Use for heavy aggregation queries** - Queries with many GROUP BY, JOINs
2. **Use for dashboards** - Don't make users wait
3. **Enable AUTO REFRESH** - Avoid forgetting to refresh
4. **Design for incremental refresh** - Keep queries simple
5. **DROP when not needed** - Save storage and refresh costs
