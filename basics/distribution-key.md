# Distribution Key (分散キー)

## What is Distribution Key?

Distribution Key determines **how data is distributed across compute nodes**.

Choosing the right distribution key is critical for query performance.

```
                    Table Data
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
     ┌─────────┐   ┌─────────┐   ┌─────────┐
     │ Node 1  │   │ Node 2  │   │ Node 3  │
     │ user_id │   │ user_id │   │ user_id │
     │ 1, 4, 7 │   │ 2, 5, 8 │   │ 3, 6, 9 │
     └─────────┘   └─────────┘   └─────────┘
```

## Distribution Styles

### 1. KEY Distribution

Data is distributed based on a specific column value.

```sql
CREATE TABLE orders (
    order_id    INT,
    customer_id INT,
    amount      DECIMAL(10,2)
)
DISTSTYLE KEY
DISTKEY (customer_id);
```

**Use when:**
- Column is frequently used in JOIN conditions
- Column has high cardinality (many unique values)

### 2. EVEN Distribution

Data is distributed evenly in round-robin fashion.

```sql
CREATE TABLE logs (
    log_id      INT,
    message     VARCHAR(500),
    created_at  TIMESTAMP
)
DISTSTYLE EVEN;
```

**Use when:**
- No clear join column
- Table is not joined with other tables

### 3. ALL Distribution

Entire table is copied to every node.

```sql
CREATE TABLE countries (
    country_code CHAR(2),
    country_name VARCHAR(100)
)
DISTSTYLE ALL;
```

**Use when:**
- Small dimension/lookup tables
- Table is frequently joined with large tables

### 4. AUTO Distribution

Redshift automatically chooses the best distribution.

```sql
CREATE TABLE products (
    product_id   INT,
    product_name VARCHAR(200)
)
DISTSTYLE AUTO;
```

## Why Distribution Key Matters

### Good Distribution (Co-located JOIN)

```
Node 1: orders(customer_id=1) + customers(customer_id=1)
Node 2: orders(customer_id=2) + customers(customer_id=2)
→ JOIN happens locally on each node (FAST)
```

### Bad Distribution (Data Redistribution)

```
Node 1: orders(customer_id=1)     customers(customer_id=2)
Node 2: orders(customer_id=2)     customers(customer_id=1)
→ Data must be shuffled between nodes (SLOW)
```

## Checking Current Distribution

```sql
SELECT "table", diststyle
FROM svv_table_info
WHERE "table" = 'your_table_name';
```

## Best Practices

| Scenario | Recommended Style |
|----------|-------------------|
| Large fact table with frequent JOINs | KEY (on join column) |
| Small dimension table (< 1M rows) | ALL |
| Staging/temp tables | EVEN or AUTO |
| Not sure | AUTO |
