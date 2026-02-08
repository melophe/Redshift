# ストアドプロシージャ

## ストアドプロシージャとは？

**複数のSQL文をまとめて保存し、再利用できる機能**。

```
【ストアドプロシージャなし】
毎回同じSQLを何行も実行

【ストアドプロシージャあり】
CALL my_procedure();  ← 1行で実行
```

## なぜ使う？

```
1. 複雑な処理をまとめて再利用
2. ETL処理をデータベース内で完結
3. トランザクション制御
4. 条件分岐やループ処理
```

## 基本構文

### 作成

```sql
CREATE OR REPLACE PROCEDURE procedure_name(parameters)
AS $$
BEGIN
    -- 処理
END;
$$ LANGUAGE plpgsql;
```

### 実行

```sql
CALL procedure_name(arguments);
```

### 削除

```sql
DROP PROCEDURE procedure_name(parameter_types);
```

## 簡単な例

### Hello World

```sql
CREATE OR REPLACE PROCEDURE hello_world()
AS $$
BEGIN
    RAISE INFO 'Hello, World!';
END;
$$ LANGUAGE plpgsql;

-- 実行
CALL hello_world();
```

### パラメータ付き

```sql
CREATE OR REPLACE PROCEDURE greet(name VARCHAR)
AS $$
BEGIN
    RAISE INFO 'Hello, %!', name;
END;
$$ LANGUAGE plpgsql;

-- 実行
CALL greet('Tanaka');
```

## 実用的な例

### 1. 日次集計処理

```sql
CREATE OR REPLACE PROCEDURE daily_aggregation(target_date DATE)
AS $$
BEGIN
    -- 既存データを削除
    DELETE FROM daily_summary
    WHERE summary_date = target_date;

    -- 集計データを挿入
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

-- 実行
CALL daily_aggregation('2024-01-15');
```

### 2. テーブルクリーンアップ

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

-- 90日より古いデータを削除
CALL cleanup_old_data(90);
```

### 3. 条件分岐

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

### 4. ループ処理

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

## 変数

```sql
CREATE OR REPLACE PROCEDURE variable_example()
AS $$
DECLARE
    my_int INT := 0;
    my_text VARCHAR := 'hello';
    my_date DATE := CURRENT_DATE;
    row_count INT;
BEGIN
    -- 変数に値を代入
    my_int := 100;

    -- SELECTの結果を変数に
    SELECT COUNT(*) INTO row_count FROM sales;

    RAISE INFO 'Count: %', row_count;
END;
$$ LANGUAGE plpgsql;
```

## トランザクション制御

```sql
CREATE OR REPLACE PROCEDURE transfer_funds(
    from_account INT,
    to_account INT,
    amount DECIMAL
)
AS $$
BEGIN
    -- 送金元から引く
    UPDATE accounts
    SET balance = balance - amount
    WHERE id = from_account;

    -- 送金先に足す
    UPDATE accounts
    SET balance = balance + amount
    WHERE id = to_account;

    -- 明示的にコミット
    COMMIT;

    RAISE INFO 'Transfer completed';
EXCEPTION
    WHEN OTHERS THEN
        -- エラー時はロールバック
        ROLLBACK;
        RAISE;
END;
$$ LANGUAGE plpgsql;
```

## エラーハンドリング

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

## OUT パラメータ（戻り値）

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

-- 実行
CALL get_order_total(123, NULL);
```

## 動的SQL

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

-- 実行
CALL dynamic_query('sales');
```

## ストアドプロシージャ一覧の確認

```sql
SELECT
    proname AS procedure_name,
    prosrc AS source_code
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND prokind = 'p';
```

## ベストプラクティス

1. **ETL処理に活用** - 複雑な変換ロジックをまとめる
2. **エラーハンドリングを入れる** - 失敗時の挙動を制御
3. **ログを出力** - RAISE INFOでデバッグ
4. **コメントを書く** - 複雑な処理は説明を追加
5. **テストする** - 本番前に検証環境で確認

## 制限事項

- カーソルのサポートは限定的
- 一部のPostgreSQL機能は使用不可
- 大量データ処理はCOPY/UNLOADの方が効率的な場合も
