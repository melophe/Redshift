# Query Tuning

## Why Queries Are Slow

```
1. Poor table design (distribution key, sort key)
2. Scanning unnecessary data
3. Data redistribution (moving data between nodes)
4. Stale statistics
5. Inefficient SQL
```

## Investigation Flow

```
1. Identify slow queries
2. Check execution plan with EXPLAIN
3. Check details in system tables
4. Identify the problem
5. Fix it
```

## Using EXPLAIN

### Basic Usage

```sql
EXPLAIN SELECT * FROM sales WHERE region = 'Tokyo';
```

### Output Example

```
XN Seq Scan on sales  (cost=0.00..12.50 rows=1000 width=100)
  Filter: (region = 'Tokyo'::text)
```

| Item | Meaning |
|------|---------|
| Seq Scan | Full table scan (potentially slow) |
| cost | Estimated cost (lower is better) |
| rows | Estimated rows |
| Filter | WHERE condition |

### Keywords to Watch

```
【Potentially Slow】
- DS_BCAST_INNER → Broadcasting small table to all nodes
- DS_DIST_BOTH → Redistributing both tables (slow!)
- DS_DIST_ALL_NONE → JOIN with ALL table (good)

【Good】
- DS_DIST_NONE → No redistribution (good!)
```

## Common Problems and Solutions

### 1. Data Redistribution (DS_DIST_BOTH)

```sql
-- Problem: JOIN on different distribution keys
EXPLAIN
SELECT * FROM orders o
JOIN customers c ON o.customer_id = c.id;

-- DS_DIST_BOTH appears = redistributing both tables (slow)
```

**Solution:**

```sql
-- Use same DISTKEY on both tables
CREATE TABLE orders (...) DISTKEY (customer_id);
CREATE TABLE customers (...) DISTKEY (id);

-- → DS_DIST_NONE appears (fast)
```

### 2. Full Table Scan

```sql
-- Problem: Not using sort key
EXPLAIN
SELECT * FROM logs WHERE user_id = 123;
-- Seq Scan (scanning all rows)

-- Table definition
CREATE TABLE logs (...) SORTKEY (created_at);
-- Sort key is created_at but filtering by user_id
```

**Solution:**

```sql
-- Filter using sort key
SELECT * FROM logs
WHERE created_at >= '2024-01-01'
  AND user_id = 123;

-- Or set sort key to frequently used column
CREATE TABLE logs (...) SORTKEY (user_id, created_at);
```

### 3. SELECT *

```sql
-- Problem: Fetching all columns (loses columnar storage benefit)
SELECT * FROM sales;

-- Solution: Only needed columns
SELECT sale_date, amount FROM sales;
```

### 4. Stale Statistics

```sql
-- Check
SELECT "table", stats_off
FROM svv_table_info
WHERE stats_off > 10;  -- More than 10% changed

-- Solution
ANALYZE sales;
```

### 5. Too Many Unsorted Rows

```sql
-- Check
SELECT "table", unsorted
FROM svv_table_info
WHERE unsorted > 10;  -- More than 10% unsorted

-- Solution
VACUUM SORT ONLY sales;
```

## System Tables for Investigation

### Find Slow Queries

```sql
SELECT
    query,
    TRIM(querytxt) AS query_text,
    starttime,
    endtime,
    DATEDIFF(seconds, starttime, endtime) AS duration_sec
FROM stl_query
WHERE userid > 1
ORDER BY duration_sec DESC
LIMIT 10;
```

### Query Step Timing

```sql
SELECT
    query,
    segment,
    step,
    label,
    rows,
    bytes,
    elapsed_time / 1000000.0 AS elapsed_sec
FROM svl_query_summary
WHERE query = 12345  -- Query ID to investigate
ORDER BY segment, step;
```

### Disk Spill (Out of Memory)

```sql
SELECT
    query,
    segment,
    step,
    rows,
    workmem,
    is_diskbased  -- 'true' = spilled to disk
FROM svl_query_summary
WHERE query = 12345 AND is_diskbased = 't';
```

### Lock Waits

```sql
SELECT
    l.query,
    l.table_id,
    l.lock_owner,
    l.lock_mode
FROM svv_transactions l
WHERE l.lock_mode IS NOT NULL;
```

## Tuning Checklist

### Table Design

```
□ Set DISTKEY on large tables
□ Use same DISTKEY for JOINed tables
□ Use DISTSTYLE ALL for small tables
□ Set SORTKEY on frequently filtered columns
□ Apply appropriate compression encoding
```

### Queries

```
□ Avoid SELECT *
□ Fetch only needed columns
□ Filter using sort key
□ Avoid unnecessary subqueries
□ Consider JOIN order
```

### Maintenance

```
□ Run ANALYZE regularly
□ Run VACUUM regularly
□ Monitor statistics freshness
□ Monitor unsorted rows
```

## Query Improvement Example

### Before (Slow)

```sql
SELECT *
FROM orders o
JOIN products p ON o.product_id = p.id
JOIN customers c ON o.customer_id = c.id
WHERE o.created_at > '2024-01-01';
```

### After (Fast)

```sql
-- Only needed columns
SELECT
    o.order_id,
    o.amount,
    p.product_name,
    c.customer_name
FROM orders o
JOIN products p ON o.product_id = p.id
JOIN customers c ON o.customer_id = c.id
WHERE o.created_at > '2024-01-01'  -- Filter using sort key
  AND o.amount > 0;  -- Exclude unnecessary rows

-- Also review table design
-- orders: DISTKEY(customer_id), SORTKEY(created_at)
-- customers: DISTKEY(id)
-- products: DISTSTYLE ALL (small master)
```

## Best Practices

1. **Make EXPLAIN a habit** - Check after writing queries
2. **Avoid DS_DIST_BOTH** - Use same DISTKEY
3. **Avoid SELECT *** - Only needed columns
4. **Filter by sort key** - Reduce scan volume
5. **ANALYZE regularly** - Keep statistics fresh
6. **Monitor svv_table_info** - Check table health
