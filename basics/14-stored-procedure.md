# Stored Procedures

## What is a Stored Procedure?

**A feature to save and reuse multiple SQL statements**.

```
【Without Stored Procedure】
Execute same SQL lines every time

【With Stored Procedure】
CALL my_procedure();  ← Execute with 1 line
```

## Why Use Them?

```
1. Bundle complex logic for reuse
2. Complete ETL processing within database
3. Transaction control
4. Conditional branching and loops
```

## Basic Syntax

### Create

```sql
CREATE OR REPLACE PROCEDURE procedure_name(parameters)
AS $$
BEGIN
    -- logic
END;
$$ LANGUAGE plpgsql;
```

### Execute

```sql
CALL procedure_name(arguments);
```

### Drop

```sql
DROP PROCEDURE procedure_name(parameter_types);
```

## Simple Examples

### Hello World

```sql
CREATE OR REPLACE PROCEDURE hello_world()
AS $$
BEGIN
    RAISE INFO 'Hello, World!';
END;
$$ LANGUAGE plpgsql;

-- Execute
CALL hello_world();
```

### With Parameters

```sql
CREATE OR REPLACE PROCEDURE greet(name VARCHAR)
AS $$
BEGIN
    RAISE INFO 'Hello, %!', name;
END;
$$ LANGUAGE plpgsql;

-- Execute
CALL greet('Tanaka');
```

## Practical Examples

### 1. Daily Aggregation

```sql
CREATE OR REPLACE PROCEDURE daily_aggregation(target_date DATE)
AS $$
BEGIN
    -- Delete existing data
    DELETE FROM daily_summary
    WHERE summary_date = target_date;

    -- Insert aggregated data
    INSERT INTO daily_summary (summary_date, region, total_amount, order_count)
    SELECT
        target_date,
        region,
        SUM(amount),
        COUNT(*)
    FROM orders
    WHERE order_date = target_date
    GROUP BY region;

    RAISE INFO 'Aggregation completed for %', target_date;
END;
$$ LANGUAGE plpgsql;

-- Execute
CALL daily_aggregation('2024-01-15');
```

### 2. Table Cleanup

```sql
CREATE OR REPLACE PROCEDURE cleanup_old_data(days_to_keep INT)
AS $$
DECLARE
    cutoff_date DATE;
    deleted_count INT;
BEGIN
    cutoff_date := CURRENT_DATE - days_to_keep;

    DELETE FROM logs
    WHERE created_at < cutoff_date;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    RAISE INFO 'Deleted % rows older than %', deleted_count, cutoff_date;
END;
$$ LANGUAGE plpgsql;

-- Delete data older than 90 days
CALL cleanup_old_data(90);
```

### 3. Conditional Branching

```sql
CREATE OR REPLACE PROCEDURE process_order(order_id INT)
AS $$
DECLARE
    order_status VARCHAR;
BEGIN
    SELECT status INTO order_status
    FROM orders
    WHERE id = order_id;

    IF order_status = 'pending' THEN
        UPDATE orders SET status = 'processing' WHERE id = order_id;
        RAISE INFO 'Order % is now processing', order_id;
    ELSIF order_status = 'processing' THEN
        UPDATE orders SET status = 'completed' WHERE id = order_id;
        RAISE INFO 'Order % is now completed', order_id;
    ELSE
        RAISE INFO 'Order % has status: %', order_id, order_status;
    END IF;
END;
$$ LANGUAGE plpgsql;
```

### 4. Loop Processing

```sql
CREATE OR REPLACE PROCEDURE process_all_pending_orders()
AS $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN SELECT id FROM orders WHERE status = 'pending'
    LOOP
        UPDATE orders SET status = 'processing' WHERE id = rec.id;
        RAISE INFO 'Processing order %', rec.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
```

## Variables

```sql
CREATE OR REPLACE PROCEDURE variable_example()
AS $$
DECLARE
    my_int INT := 0;
    my_text VARCHAR := 'hello';
    my_date DATE := CURRENT_DATE;
    row_count INT;
BEGIN
    -- Assign value to variable
    my_int := 100;

    -- Store SELECT result in variable
    SELECT COUNT(*) INTO row_count FROM sales;

    RAISE INFO 'Count: %', row_count;
END;
$$ LANGUAGE plpgsql;
```

## Transaction Control

```sql
CREATE OR REPLACE PROCEDURE transfer_funds(
    from_account INT,
    to_account INT,
    amount DECIMAL
)
AS $$
BEGIN
    -- Subtract from source
    UPDATE accounts
    SET balance = balance - amount
    WHERE id = from_account;

    -- Add to destination
    UPDATE accounts
    SET balance = balance + amount
    WHERE id = to_account;

    -- Explicit commit
    COMMIT;

    RAISE INFO 'Transfer completed';
EXCEPTION
    WHEN OTHERS THEN
        -- Rollback on error
        ROLLBACK;
        RAISE;
END;
$$ LANGUAGE plpgsql;
```

## Error Handling

```sql
CREATE OR REPLACE PROCEDURE safe_insert(val INT)
AS $$
BEGIN
    INSERT INTO my_table (value) VALUES (val);
EXCEPTION
    WHEN unique_violation THEN
        RAISE INFO 'Value % already exists', val;
    WHEN OTHERS THEN
        RAISE INFO 'Error: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;
```

## OUT Parameters (Return Values)

```sql
CREATE OR REPLACE PROCEDURE get_order_total(
    IN order_id INT,
    OUT total DECIMAL
)
AS $$
BEGIN
    SELECT SUM(amount) INTO total
    FROM order_items
    WHERE order_id = get_order_total.order_id;
END;
$$ LANGUAGE plpgsql;

-- Execute
CALL get_order_total(123, NULL);
```

## Dynamic SQL

```sql
CREATE OR REPLACE PROCEDURE dynamic_query(table_name VARCHAR)
AS $$
DECLARE
    row_count INT;
BEGIN
    EXECUTE 'SELECT COUNT(*) FROM ' || table_name INTO row_count;
    RAISE INFO 'Table % has % rows', table_name, row_count;
END;
$$ LANGUAGE plpgsql;

-- Execute
CALL dynamic_query('sales');
```

## List Stored Procedures

```sql
SELECT
    proname AS procedure_name,
    prosrc AS source_code
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND prokind = 'p';
```

## Best Practices

1. **Use for ETL** - Bundle complex transformation logic
2. **Include error handling** - Control failure behavior
3. **Output logs** - Debug with RAISE INFO
4. **Write comments** - Explain complex logic
5. **Test first** - Verify in test environment before production

## Limitations

- Cursor support is limited
- Some PostgreSQL features unavailable
- For large data processing, COPY/UNLOAD may be more efficient
