# VACUUM and ANALYZE

## Why VACUUM and ANALYZE?

Redshift doesn't automatically clean up deleted rows or update statistics.

```
【Problem】
DELETE/UPDATE → Rows marked as "deleted" but still on disk
INSERT → New rows may not be sorted

→ Wasted space + Slow queries
```

## VACUUM

### What VACUUM Does

1. **Reclaims disk space** from deleted rows
2. **Re-sorts data** according to sort key

```
Before VACUUM:
┌────────────────────────────────────┐
│ Row1  [DEL]  Row3  Row2  [DEL]    │  ← Deleted rows + unsorted
└────────────────────────────────────┘

After VACUUM:
┌────────────────────────────────────┐
│ Row1  Row2  Row3                  │  ← Clean and sorted
└────────────────────────────────────┘
```

### VACUUM Types

```sql
-- Full vacuum (reclaim space + re-sort)
VACUUM FULL table_name;

-- Only reclaim space (faster)
VACUUM DELETE ONLY table_name;

-- Only re-sort (faster)
VACUUM SORT ONLY table_name;

-- Re-index interleaved sort key
VACUUM REINDEX table_name;
```

| Type | Space Reclaim | Re-sort | Use Case |
|------|---------------|---------|----------|
| FULL | ✅ | ✅ | After large DELETE + INSERT |
| DELETE ONLY | ✅ | ❌ | After many DELETEs |
| SORT ONLY | ❌ | ✅ | After many INSERTs |
| REINDEX | ❌ | ✅ | Interleaved sort key maintenance |

### VACUUM Threshold

```sql
-- Only vacuum if > 5% unsorted rows (default)
VACUUM FULL table_name TO 95 PERCENT;

-- Vacuum entire table
VACUUM FULL table_name TO 100 PERCENT;
```

### Automatic VACUUM

Redshift runs automatic VACUUM in the background when cluster is idle.

```sql
-- Check automatic vacuum status
SELECT * FROM svv_vacuum_progress;
SELECT * FROM svv_vacuum_summary;
```

## ANALYZE

### What ANALYZE Does

Updates **table statistics** used by the query planner.

```
Query Planner: "How many rows match WHERE status = 'active'?"

Without statistics: "I don't know... do a full scan"
With statistics: "About 1000 rows, use index scan"
```

### Running ANALYZE

```sql
-- Analyze specific table
ANALYZE table_name;

-- Analyze specific columns
ANALYZE table_name (column1, column2);

-- Analyze all tables in schema
ANALYZE;
```

### When to Run ANALYZE

| Situation | Run ANALYZE? |
|-----------|--------------|
| After COPY (large load) | ✅ Yes |
| After many INSERTs | ✅ Yes |
| After DELETE/UPDATE affecting > 10% | ✅ Yes |
| Data distribution changed | ✅ Yes |

### Automatic ANALYZE

Redshift runs automatic ANALYZE after COPY commands.

```sql
-- Disable auto analyze for COPY
COPY table_name FROM '...'
STATUPDATE OFF;

-- Force auto analyze
COPY table_name FROM '...'
STATUPDATE ON;
```

## Checking Table Health

### Check Unsorted Rows

```sql
SELECT "table", unsorted, vacuum_sort_benefit
FROM svv_table_info
WHERE "table" = 'your_table';
```

### Check Statistics Age

```sql
SELECT "table", stats_off
FROM svv_table_info
WHERE "table" = 'your_table';
-- stats_off: percentage of rows changed since last ANALYZE
```

### Check Deleted Rows

```sql
SELECT "table", tbl_rows, empty AS deleted_rows
FROM svv_table_info
WHERE "table" = 'your_table';
```

## Best Practices

1. **Let automatic VACUUM/ANALYZE run** - Usually sufficient
2. **Manual VACUUM after large batch operations** - Big DELETE or bulk INSERT
3. **VACUUM during off-peak hours** - Uses cluster resources
4. **ANALYZE after data distribution changes** - Helps query planner
5. **Monitor with svv_table_info** - Check unsorted % and stats_off

## Example Maintenance Workflow

```sql
-- After nightly ETL job
VACUUM FULL sales;
ANALYZE sales;

-- Check status
SELECT "table", unsorted, stats_off, vacuum_sort_benefit
FROM svv_table_info
WHERE "table" = 'sales';
```
