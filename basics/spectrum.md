# Redshift Spectrum

## What is Redshift Spectrum?

Redshift Spectrum allows you to **query data directly in S3** without loading it into Redshift.

```
┌─────────────────────────────────────────────────────┐
│                    Redshift Cluster                  │
│  ┌─────────────┐                                    │
│  │ Internal    │  ← Regular tables (loaded data)    │
│  │ Tables      │                                    │
│  └─────────────┘                                    │
│         +                                           │
│  ┌─────────────┐      ┌─────────────────────┐      │
│  │ External    │ ───→ │   S3 (Data Lake)    │      │
│  │ Tables      │      │   Parquet, CSV, etc │      │
│  └─────────────┘      └─────────────────────┘      │
└─────────────────────────────────────────────────────┘
```

## Why Use Spectrum?

| Scenario | Solution |
|----------|----------|
| Data too large to load | Query directly from S3 |
| Infrequently accessed data | Keep in S3, query when needed |
| Data lake integration | Join S3 data with Redshift tables |
| Cost optimization | Store cold data in S3 (cheaper) |

## Setup Steps

### 1. Create External Schema

```sql
CREATE EXTERNAL SCHEMA spectrum_schema
FROM DATA CATALOG
DATABASE 'my_glue_database'
IAM_ROLE 'arn:aws:iam::123456789:role/SpectrumRole'
CREATE EXTERNAL DATABASE IF NOT EXISTS;
```

### 2. Create External Table

```sql
CREATE EXTERNAL TABLE spectrum_schema.sales (
    sale_id      INT,
    sale_date    DATE,
    amount       DECIMAL(10,2),
    region       VARCHAR(50)
)
STORED AS PARQUET
LOCATION 's3://my-bucket/sales/';
```

### 3. Query the Data

```sql
-- Query external table (data stays in S3)
SELECT region, SUM(amount)
FROM spectrum_schema.sales
WHERE sale_date >= '2024-01-01'
GROUP BY region;

-- Join with internal table
SELECT s.region, s.amount, c.customer_name
FROM spectrum_schema.sales s
JOIN customers c ON s.customer_id = c.id;
```

## Partitioning (Important!)

Partitioning dramatically reduces the amount of data scanned.

### Partitioned Table Structure

```
s3://bucket/sales/
  ├── year=2023/
  │   ├── month=01/
  │   │   └── data.parquet
  │   └── month=02/
  │       └── data.parquet
  └── year=2024/
      ├── month=01/
      │   └── data.parquet
      └── month=02/
          └── data.parquet
```

### Create Partitioned External Table

```sql
CREATE EXTERNAL TABLE spectrum_schema.sales_partitioned (
    sale_id      INT,
    amount       DECIMAL(10,2),
    region       VARCHAR(50)
)
PARTITIONED BY (year INT, month INT)
STORED AS PARQUET
LOCATION 's3://my-bucket/sales/';

-- Add partitions
ALTER TABLE spectrum_schema.sales_partitioned
ADD PARTITION (year=2024, month=1)
LOCATION 's3://my-bucket/sales/year=2024/month=01/';

-- Or use Glue Crawler to auto-detect partitions
```

### Query with Partition Filter

```sql
-- Only scans year=2024 data (fast!)
SELECT * FROM spectrum_schema.sales_partitioned
WHERE year = 2024 AND month = 1;
```

## Supported File Formats

| Format | Best For |
|--------|----------|
| Parquet | Analytics (columnar, compressed) - **Recommended** |
| ORC | Analytics (columnar) |
| CSV | Simple data |
| JSON | Semi-structured data |
| Avro | Schema evolution |

## Internal vs External Tables

| | Internal Table | External Table (Spectrum) |
|---|----------------|---------------------------|
| Data location | Redshift storage | S3 |
| Query speed | Faster | Slower |
| Storage cost | Higher | Lower |
| Data loading | Required (COPY) | Not required |
| Use case | Frequent queries | Infrequent/cold data |

## Best Practices

1. **Use Parquet format** - Columnar, compressed, efficient
2. **Partition by commonly filtered columns** - year, month, region
3. **Use partition filters in WHERE clause** - Avoid full scans
4. **Join hot data (internal) with cold data (external)** - Best of both worlds
