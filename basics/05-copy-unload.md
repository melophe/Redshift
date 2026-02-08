# COPY and UNLOAD Commands

## Overview

| Command | Direction | Purpose |
|---------|-----------|---------|
| COPY | S3 → Redshift | Load data into Redshift |
| UNLOAD | Redshift → S3 | Export data from Redshift |

```
┌─────────┐   COPY    ┌───────────┐
│   S3    │ ───────→  │  Redshift │
│         │ ←───────  │           │
└─────────┘  UNLOAD   └───────────┘
```

## COPY Command

### Basic Syntax

```sql
COPY table_name
FROM 's3://bucket/path/'
IAM_ROLE 'arn:aws:iam::123456789:role/RedshiftRole'
FORMAT AS CSV;
```

### Common Options

```sql
COPY sales
FROM 's3://my-bucket/data/sales/'
IAM_ROLE 'arn:aws:iam::123456789:role/RedshiftRole'
FORMAT AS CSV
DELIMITER ','
IGNOREHEADER 1           -- Skip header row
DATEFORMAT 'YYYY-MM-DD'
TIMEFORMAT 'auto'
REGION 'ap-northeast-1'
GZIP;                    -- If files are compressed
```

### Supported Formats

| Format | Option |
|--------|--------|
| CSV | `FORMAT AS CSV` or `DELIMITER ','` |
| JSON | `FORMAT AS JSON 'auto'` or `JSON 's3://path/jsonpaths.json'` |
| Parquet | `FORMAT AS PARQUET` |
| ORC | `FORMAT AS ORC` |
| Avro | `FORMAT AS AVRO` |

### Best Practices for COPY

1. **Split files for parallel loading**
   ```
   s3://bucket/data/part-001.csv
   s3://bucket/data/part-002.csv
   s3://bucket/data/part-003.csv
   ...
   → Number of files = multiple of slices (best performance)
   ```

2. **Use compressed files**
   ```sql
   COPY ... GZIP;   -- or BZIP2, LZOP, ZSTD
   ```

3. **Use manifest file for specific files**
   ```sql
   COPY table_name
   FROM 's3://bucket/manifest.json'
   MANIFEST;
   ```

   manifest.json:
   ```json
   {
     "entries": [
       {"url": "s3://bucket/file1.csv", "mandatory": true},
       {"url": "s3://bucket/file2.csv", "mandatory": true}
     ]
   }
   ```

## UNLOAD Command

### Basic Syntax

```sql
UNLOAD ('SELECT * FROM table_name')
TO 's3://bucket/output/'
IAM_ROLE 'arn:aws:iam::123456789:role/RedshiftRole';
```

### Common Options

```sql
UNLOAD ('SELECT * FROM sales WHERE year = 2024')
TO 's3://my-bucket/export/sales_2024_'
IAM_ROLE 'arn:aws:iam::123456789:role/RedshiftRole'
FORMAT AS PARQUET        -- or CSV, JSON
PARTITION BY (region)    -- Create partitioned output
PARALLEL ON              -- Default: parallel output
ALLOWOVERWRITE           -- Overwrite existing files
MAXFILESIZE 256 MB;      -- Control file size
```

### Output Formats

```sql
-- CSV (default)
UNLOAD ('...') TO '...' DELIMITER ',' HEADER;

-- Parquet (recommended for analytics)
UNLOAD ('...') TO '...' FORMAT AS PARQUET;

-- JSON
UNLOAD ('...') TO '...' FORMAT AS JSON;
```

### Partitioned Output

```sql
UNLOAD ('SELECT * FROM sales')
TO 's3://bucket/sales/'
PARTITION BY (year, month)
FORMAT AS PARQUET;

-- Creates:
-- s3://bucket/sales/year=2024/month=01/part-001.parquet
-- s3://bucket/sales/year=2024/month=02/part-001.parquet
```

## COPY vs INSERT

| | COPY | INSERT |
|---|------|--------|
| Speed | Fast (parallel) | Slow (row by row) |
| Source | S3, DynamoDB, EMR | SQL query |
| Use case | Bulk loading | Small inserts |

**Always use COPY for bulk loading!**

## Error Handling

```sql
-- Check COPY errors
SELECT * FROM stl_load_errors
ORDER BY starttime DESC
LIMIT 10;

-- Allow some errors
COPY ...
MAXERROR 100;  -- Continue if < 100 errors
```
