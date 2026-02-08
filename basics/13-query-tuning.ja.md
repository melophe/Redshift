# クエリチューニング

## クエリが遅い原因

```
1. 悪いテーブル設計（分散キー、ソートキー）
2. 不要なデータをスキャン
3. データ再分散（ノード間のデータ移動）
4. 統計情報が古い
5. 非効率なSQL
```

## 調査の流れ

```
1. 遅いクエリを特定
2. EXPLAIN で実行計画を確認
3. システムテーブルで詳細を確認
4. 問題を特定
5. 修正
```

## EXPLAIN で実行計画を見る

### 基本的な使い方

```sql
EXPLAIN SELECT * FROM sales WHERE region = 'Tokyo';
```

### 出力例

```
XN Seq Scan on sales  (cost=0.00..12.50 rows=1000 width=100)
  Filter: (region = 'Tokyo'::text)
```

| 項目 | 意味 |
|------|------|
| Seq Scan | フルテーブルスキャン（遅い可能性） |
| cost | 推定コスト（小さいほど良い） |
| rows | 推定行数 |
| Filter | WHERE条件 |

### 注意すべきキーワード

```
【遅い可能性がある】
- DS_BCAST_INNER → 小さいテーブルを全ノードにコピー
- DS_DIST_BOTH → 両テーブルを再分散（遅い！）
- DS_DIST_ALL_NONE → ALLテーブルとのJOIN（良い）

【良い】
- DS_DIST_NONE → 再分散なし（良い！）
```

## よくある問題と解決策

### 1. データ再分散（DS_DIST_BOTH）

```sql
-- 問題: 異なる分散キーでJOIN
EXPLAIN
SELECT * FROM orders o
JOIN customers c ON o.customer_id = c.id;

-- DS_DIST_BOTH が出る = 両テーブルを再分散（遅い）
```

**解決策:**

```sql
-- 両テーブルで同じDISTKEYを使う
CREATE TABLE orders (...) DISTKEY (customer_id);
CREATE TABLE customers (...) DISTKEY (id);

-- → DS_DIST_NONE になる（速い）
```

### 2. フルテーブルスキャン

```sql
-- 問題: ソートキーを使っていない
EXPLAIN
SELECT * FROM logs WHERE user_id = 123;
-- Seq Scan（全行スキャン）

-- テーブル定義
CREATE TABLE logs (...) SORTKEY (created_at);
-- ソートキーがcreated_atなのにuser_idでフィルタ
```

**解決策:**

```sql
-- ソートキーでフィルタする
SELECT * FROM logs
WHERE created_at >= '2024-01-01'
  AND user_id = 123;

-- または、よく使うカラムをソートキーに
CREATE TABLE logs (...) SORTKEY (user_id, created_at);
```

### 3. SELECT *

```sql
-- 問題: 全カラム取得（カラムナストレージの利点が消える）
SELECT * FROM sales;

-- 解決策: 必要なカラムだけ
SELECT sale_date, amount FROM sales;
```

### 4. 統計情報が古い

```sql
-- 確認
SELECT "table", stats_off
FROM svv_table_info
WHERE stats_off > 10;  -- 10%以上変更あり

-- 解決策
ANALYZE sales;
```

### 5. 未ソートデータが多い

```sql
-- 確認
SELECT "table", unsorted
FROM svv_table_info
WHERE unsorted > 10;  -- 10%以上未ソート

-- 解決策
VACUUM SORT ONLY sales;
```

## システムテーブルで調査

### 遅いクエリを見つける

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

### クエリのステップ別時間

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
WHERE query = 12345  -- 調査したいクエリID
ORDER BY segment, step;
```

### ディスクスピル（メモリ不足）

```sql
SELECT
    query,
    segment,
    step,
    rows,
    workmem,
    is_diskbased  -- 'true' = ディスクに溢れた
FROM svl_query_summary
WHERE query = 12345 AND is_diskbased = 't';
```

### ロック待ち

```sql
SELECT
    l.query,
    l.table_id,
    l.lock_owner,
    l.lock_mode
FROM svv_transactions l
WHERE l.lock_mode IS NOT NULL;
```

## チューニングチェックリスト

### テーブル設計

```
□ 大きいテーブルにDISTKEYを設定
□ JOINするテーブルは同じDISTKEYを使用
□ 小さいテーブルはDISTSTYLE ALL
□ よくフィルタするカラムにSORTKEY
□ 適切な圧縮エンコーディング
```

### クエリ

```
□ SELECT * を避ける
□ 必要なカラムだけ取得
□ ソートキーでフィルタ
□ 不要なサブクエリを避ける
□ JOINの順序を意識
```

### メンテナンス

```
□ ANALYZE を定期実行
□ VACUUM を定期実行
□ 統計情報の鮮度を監視
□ 未ソート行を監視
```

## クエリ改善の例

### Before（遅い）

```sql
SELECT *
FROM orders o
JOIN products p ON o.product_id = p.id
JOIN customers c ON o.customer_id = c.id
WHERE o.created_at > '2024-01-01';
```

### After（速い）

```sql
-- 必要なカラムだけ
SELECT
    o.order_id,
    o.amount,
    p.product_name,
    c.customer_name
FROM orders o
JOIN products p ON o.product_id = p.id
JOIN customers c ON o.customer_id = c.id
WHERE o.created_at > '2024-01-01'  -- ソートキーでフィルタ
  AND o.amount > 0;  -- 不要な行を除外

-- テーブル設計も見直し
-- orders: DISTKEY(customer_id), SORTKEY(created_at)
-- customers: DISTKEY(id)
-- products: DISTSTYLE ALL（小さいマスタ）
```

## ベストプラクティス

1. **EXPLAIN を習慣に** - クエリを書いたら確認
2. **DS_DIST_BOTH を避ける** - 同じDISTKEYを使う
3. **SELECT * を避ける** - 必要なカラムだけ
4. **ソートキーでフィルタ** - スキャン量を減らす
5. **定期的にANALYZE** - 統計情報を最新に
6. **svv_table_info を監視** - テーブルの健全性確認
