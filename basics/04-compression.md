# Compression Encoding

## What is Compression Encoding?

Compression encoding determines **how data is compressed in each column**.

Proper compression reduces storage and improves query performance.

```
Without Compression:
┌──────────────────────────────────┐
│ Tokyo Tokyo Tokyo Tokyo Tokyo    │  100 bytes
└──────────────────────────────────┘

With Compression (RLE):
┌──────────────────────────────────┐
│ Tokyo x 5                        │  10 bytes
└──────────────────────────────────┘
```

## Why Columnar Storage Compresses Well

```
Row-based: Different types mixed → Poor compression
┌────┬───────┬─────┬────────┐
│ 1  │ Tokyo │ 25  │ 50000  │  Mixed data types
└────┴───────┴─────┴────────┘

Columnar: Same type together → Great compression
┌───────┬───────┬───────┬───────┐
│ Tokyo │ Tokyo │ Osaka │ Tokyo │  Same type = compresses well
└───────┴───────┴───────┴───────┘
```

## Encoding Types

### 1. RAW (No Compression)

No compression applied.

```sql
column_name VARCHAR(100) ENCODE RAW
```

**Use when:** Data doesn't compress well (random data, already compressed)

### 2. AZ64

Amazon's proprietary algorithm. Best for numeric and date/time types.

```sql
column_name BIGINT ENCODE AZ64
```

**Use when:** Numbers, dates, timestamps - **Recommended default for these types**

### 3. LZO

General-purpose compression.

```sql
column_name VARCHAR(500) ENCODE LZO
```

**Use when:** Long strings, varied text data

### 4. ZSTD

High compression ratio, good performance.

```sql
column_name VARCHAR(1000) ENCODE ZSTD
```

**Use when:** Large text columns - **Recommended for VARCHAR**

### 5. BYTEDICT

Dictionary-based compression. Good for low cardinality.

```sql
column_name VARCHAR(50) ENCODE BYTEDICT
```

**Use when:** Few unique values (country codes, status flags)

### 6. RUNLENGTH (RLE)

Stores value + count for consecutive identical values.

```sql
column_name VARCHAR(50) ENCODE RUNLENGTH
```

**Use when:** Many consecutive repeated values (sorted columns)

### 7. DELTA / DELTA32K

Stores difference from previous value.

```sql
column_name INT ENCODE DELTA
```

**Use when:** Sequential or near-sequential numbers (IDs, timestamps)

### 8. MOSTLY8 / MOSTLY16 / MOSTLY32

Compresses when most values fit in smaller size.

```sql
column_name BIGINT ENCODE MOSTLY16
```

**Use when:** BIGINT column where most values are small

## Encoding Recommendations

| Data Type | Recommended Encoding |
|-----------|---------------------|
| INT, BIGINT | AZ64 |
| DATE, TIMESTAMP | AZ64 |
| DECIMAL | AZ64 |
| BOOLEAN | RAW or ZSTD |
| VARCHAR (short, low cardinality) | BYTEDICT |
| VARCHAR (long text) | ZSTD or LZO |
| CHAR | BYTEDICT or LZO |
| Sorted column with repeats | RUNLENGTH |

## Automatic Compression (ANALYZE COMPRESSION)

Let Redshift recommend encodings:

```sql
ANALYZE COMPRESSION table_name;
```

Output:
```
Column     | Encoding | Est. Reduction
-----------+----------+---------------
user_id    | AZ64     | 75%
name       | ZSTD     | 60%
status     | BYTEDICT | 90%
```

## Setting Compression

### At Table Creation

```sql
CREATE TABLE users (
    user_id     BIGINT       ENCODE AZ64,
    name        VARCHAR(100) ENCODE ZSTD,
    status      VARCHAR(20)  ENCODE BYTEDICT,
    created_at  TIMESTAMP    ENCODE AZ64
);
```

### Using COPY with Auto Compression

```sql
COPY table_name
FROM 's3://...'
COMPUPDATE ON;  -- Automatically apply compression
```

### Changing Compression (Requires Table Rebuild)

```sql
-- Create new table with new encoding
CREATE TABLE users_new (...) ENCODE ...;

-- Copy data
INSERT INTO users_new SELECT * FROM users;

-- Swap tables
DROP TABLE users;
ALTER TABLE users_new RENAME TO users;
```

## Checking Current Compression

```sql
SELECT "column", "encoding"
FROM pg_table_def
WHERE tablename = 'your_table';
```

## Best Practices

1. **Use ANALYZE COMPRESSION** on sample data to get recommendations
2. **Let COPY auto-compress** with `COMPUPDATE ON` for new tables
3. **AZ64 for numbers/dates** - Amazon's optimized algorithm
4. **ZSTD for text** - Good balance of compression and speed
5. **BYTEDICT for low cardinality** - Status, country codes, etc.
