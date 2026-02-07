# Sort Key (ソートキー)

## What is Sort Key?

Sort Key determines **how data is physically ordered on disk**.

Proper sort key selection can dramatically reduce the amount of data scanned.

## How Sort Key Works

```
Without Sort Key:
┌─────────────────────────────────────┐
│ 2024-01  2024-03  2024-01  2024-02  │  ← Unsorted
│ 2024-02  2024-01  2024-03  2024-01  │
└─────────────────────────────────────┘
Query: WHERE date = '2024-01' → Must scan ALL blocks

With Sort Key (date):
┌─────────────────────────────────────┐
│ 2024-01  2024-01  2024-01  2024-01  │  ← Block 1
│ 2024-02  2024-02  2024-02  2024-02  │  ← Block 2
│ 2024-03  2024-03  2024-03  2024-03  │  ← Block 3
└─────────────────────────────────────┘
Query: WHERE date = '2024-01' → Only scan Block 1!
```

## Zone Maps

Redshift stores min/max values for each block (Zone Map).

```
Block 1: min=2024-01-01, max=2024-01-31
Block 2: min=2024-02-01, max=2024-02-28
Block 3: min=2024-03-01, max=2024-03-31

Query: WHERE date = '2024-02-15'
→ Skip Block 1 (max < 2024-02-15)
→ Scan Block 2 (contains the date)
→ Skip Block 3 (min > 2024-02-15)
```

## Sort Key Types

### 1. Compound Sort Key

Data is sorted by columns in order (like ORDER BY col1, col2, col3).

```sql
CREATE TABLE sales (
    sale_date   DATE,
    region      VARCHAR(50),
    product_id  INT,
    amount      DECIMAL(10,2)
)
COMPOUND SORTKEY (sale_date, region);
```

**Effective queries:**
```sql
-- Uses sort key (starts with sale_date)
WHERE sale_date = '2024-01-15'
WHERE sale_date = '2024-01-15' AND region = 'Tokyo'

-- Does NOT use sort key (skips sale_date)
WHERE region = 'Tokyo'  -- NG: first column missing
```

### 2. Interleaved Sort Key

All columns are treated equally (no order dependency).

```sql
CREATE TABLE events (
    event_date  DATE,
    user_id     INT,
    event_type  VARCHAR(50)
)
INTERLEAVED SORTKEY (event_date, user_id);
```

**Effective queries:**
```sql
-- All of these use sort key
WHERE event_date = '2024-01-15'
WHERE user_id = 12345
WHERE event_date = '2024-01-15' AND user_id = 12345
```

**Tradeoffs:**
- More flexible filtering
- Slower VACUUM (re-sorting)
- Higher maintenance cost

## Compound vs Interleaved

| | Compound | Interleaved |
|---|----------|-------------|
| Query flexibility | Must use leading columns | Any column works |
| VACUUM speed | Fast | Slow |
| Best for | Known, consistent query patterns | Ad-hoc, variable queries |
| Recommendation | **Use this by default** | Only when needed |

## Syntax Examples

```sql
-- Compound (default if not specified)
CREATE TABLE t1 (...) SORTKEY (col1, col2);
CREATE TABLE t2 (...) COMPOUND SORTKEY (col1, col2);

-- Interleaved
CREATE TABLE t3 (...) INTERLEAVED SORTKEY (col1, col2);

-- No sort key
CREATE TABLE t4 (...) SORTKEY ();
```

## Best Practices

| Scenario | Recommended Sort Key |
|----------|---------------------|
| Time-series data (logs, events) | Date/timestamp column |
| Queries always filter by date first | COMPOUND (date, ...) |
| Queries filter by various columns | INTERLEAVED |
| Frequently used in WHERE clause | Include in sort key |
| Frequently used in JOIN | Consider as sort key |

## Checking Sort Key Effectiveness

```sql
-- Check if sort key is being used
EXPLAIN SELECT * FROM sales WHERE sale_date = '2024-01-15';

-- Look for "Filter" vs "Seq Scan" in the output
```
