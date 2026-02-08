# Data Sharing

## What is Data Sharing?

**Share data with other Redshift clusters/Serverless without copying**.

```
【Traditional】
Cluster A → UNLOAD → S3 → COPY → Cluster B
(Copy data, takes time, data gets stale)

【Data Sharing】
Cluster A ────────→ Cluster B
     ↑ Direct reference (no copy, always fresh)
```

## Why is it Needed?

```
【Problem】
- Want analytics team to see production data
- But don't want to load production cluster
- Copied data becomes stale

【Data Sharing Solution】
- Directly reference production data
- Run analytics on separate cluster (no production load)
- Always latest data
```

## Terminology

```
┌──────────────────┐          ┌──────────────────┐
│   Producer       │ ──────→  │   Consumer       │
│   (Provider)     │  Share   │   (User)         │
│                  │          │                  │
│   Creates        │          │   Accesses via   │
│   Datashare      │          │   external DB    │
└──────────────────┘          └──────────────────┘
```

| Term | Meaning |
|------|---------|
| Producer | Cluster that provides data |
| Consumer | Cluster that uses data |
| Datashare | Definition of shared objects |

## Setup Steps

### 1. Producer: Create Datashare

```sql
-- Create Datashare
CREATE DATASHARE sales_share;

-- Add schema
ALTER DATASHARE sales_share ADD SCHEMA public;

-- Add tables
ALTER DATASHARE sales_share ADD TABLE public.sales;
ALTER DATASHARE sales_share ADD TABLE public.customers;

-- Add all tables in schema
ALTER DATASHARE sales_share ADD ALL TABLES IN SCHEMA public;
```

### 2. Producer: Grant Access to Consumer

```sql
-- Share with cluster in same AWS account
GRANT USAGE ON DATASHARE sales_share
TO NAMESPACE 'consumer-namespace-id';

-- Share with different AWS account
GRANT USAGE ON DATASHARE sales_share
TO ACCOUNT '123456789012';
```

### 3. Consumer: Create Database from Datashare

```sql
-- Check available Datashares
SHOW DATASHARES;

-- Create external database
CREATE DATABASE sales_db
FROM DATASHARE sales_share
OF NAMESPACE 'producer-namespace-id';
```

### 4. Consumer: Query Data

```sql
-- Access shared data
SELECT * FROM sales_db.public.sales;

-- JOIN with local table
SELECT s.*, l.local_column
FROM sales_db.public.sales s
JOIN local_schema.local_table l ON s.id = l.id;
```

## Shareable Objects

| Object | Shareable? |
|--------|-----------|
| Tables | ✅ |
| Views | ✅ |
| Materialized Views | ✅ |
| UDFs | ✅ |
| Schemas | ✅ |
| External Tables (Spectrum) | ❌ |

## Use Cases

### 1. Separate Production and Analytics

```
┌──────────────────┐          ┌──────────────────┐
│   Production     │ ──────→  │   Analytics      │
│   Cluster        │          │   Cluster        │
│                  │          │                  │
│   Write ops      │          │   Heavy queries  │
└──────────────────┘          └──────────────────┘

Analyze without affecting production
```

### 2. Multi-tenant

```
┌──────────────────┐          ┌──────────────────┐
│   Central Data   │ ──────→  │   Tenant A       │
│                  │          └──────────────────┘
│                  │ ──────→  ┌──────────────────┐
│                  │          │   Tenant B       │
└──────────────────┘          └──────────────────┘

Each tenant accesses via separate cluster
```

### 3. Cross-department Sharing

```
┌──────────────────┐          ┌──────────────────┐
│   Sales Dept     │ ──────→  │   Marketing      │
│                  │          │                  │
└──────────────────┘          └──────────────────┘

Marketing accesses sales data
```

## Pricing

```
【Producer】
- Normal storage costs
- Sharing itself is free

【Consumer】
- No storage costs (data is at Producer)
- Only compute costs for queries
```

## Limitations

- Consumer is **read-only** (no INSERT/UPDATE/DELETE)
- Producer and Consumer must be in **same region** (cross-region possible with extra config)
- External tables (Spectrum) cannot be shared

## Managing Datashares

### Check Sharing Status

```sql
-- Producer: Check created Datashares
SELECT * FROM svv_datashares;

-- Consumer: Check available Datashares
SHOW DATASHARES;

-- Check Datashare contents
SELECT * FROM svv_datashare_objects
WHERE share_name = 'sales_share';
```

### Remove Objects from Datashare

```sql
ALTER DATASHARE sales_share REMOVE TABLE public.old_table;
```

### Delete Datashare

```sql
DROP DATASHARE sales_share;
```

## Best Practices

1. **Separate production and analytics** - Run heavy queries on separate cluster
2. **Share only needed tables** - Security and simplicity
3. **Minimize permissions** - Grant only to necessary Consumers
4. **Set up monitoring** - Track who accesses what data
5. **Combine with Serverless** - Use Serverless for Consumer to optimize costs
