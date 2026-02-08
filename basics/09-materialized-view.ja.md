# マテリアライズドビュー

## マテリアライズドビューとは？

**クエリ結果を物理的に保存**したビュー。

```
【通常のビュー】
SELECT * FROM view → 毎回クエリを実行 → 遅い

【マテリアライズドビュー】
SELECT * FROM mv → 保存済みの結果を返す → 速い
```

## 通常ビュー vs マテリアライズドビュー

| | 通常ビュー | マテリアライズドビュー |
|---|-----------|---------------------|
| データ保存 | なし（定義のみ） | あり（結果を保存） |
| クエリ速度 | 毎回計算（遅い） | 保存済み（速い） |
| ストレージ | 使わない | 使う |
| データ鮮度 | 常に最新 | REFRESH が必要 |

```
通常ビュー:
┌─────────────────┐
│ CREATE VIEW ... │ → 定義だけ保存
└─────────────────┘
          ↓ クエリ時
    毎回計算して返す


マテリアライズドビュー:
┌─────────────────┐      ┌─────────────────┐
│ CREATE MV ...   │  →   │ 計算結果を保存   │
└─────────────────┘      └─────────────────┘
                                  ↓ クエリ時
                          保存済み結果を返す（速い）
```

## 基本構文

### 作成

```sql
CREATE MATERIALIZED VIEW mv_daily_sales AS
SELECT
    sale_date,
    region,
    SUM(amount) AS total_amount,
    COUNT(*) AS order_count
FROM sales
GROUP BY sale_date, region;
```

### クエリ

```sql
-- 通常のテーブルと同じように使える
SELECT * FROM mv_daily_sales
WHERE region = 'Tokyo';
```

### リフレッシュ（更新）

```sql
-- 手動リフレッシュ
REFRESH MATERIALIZED VIEW mv_daily_sales;
```

### 削除

```sql
DROP MATERIALIZED VIEW mv_daily_sales;
```

## 自動リフレッシュ

Redshiftが自動でリフレッシュ。

```sql
CREATE MATERIALIZED VIEW mv_daily_sales
AUTO REFRESH YES
AS
SELECT sale_date, SUM(amount) AS total
FROM sales
GROUP BY sale_date;
```

| 設定 | 説明 |
|------|------|
| AUTO REFRESH YES | 自動リフレッシュ有効 |
| AUTO REFRESH NO | 手動リフレッシュのみ（デフォルト） |

## 増分リフレッシュ

変更分だけを更新（高速）。

```
【フルリフレッシュ】
全データを再計算 → 遅い

【増分リフレッシュ】
変更分だけ計算 → 速い
```

```sql
-- 増分リフレッシュ可能なMVの条件:
-- - 単純なSELECT/JOIN/GROUP BY
-- - 集計関数: SUM, COUNT, MIN, MAX, AVG
-- - ベーステーブルにDELETEがない（INSERTのみ）
```

## ユースケース

### 1. 集計の高速化

```sql
-- 毎回これを実行すると遅い
SELECT region, SUM(amount)
FROM sales
WHERE sale_date >= '2024-01-01'
GROUP BY region;

-- マテリアライズドビューで高速化
CREATE MATERIALIZED VIEW mv_region_sales AS
SELECT region, sale_date, SUM(amount) AS total
FROM sales
GROUP BY region, sale_date;

-- これは速い
SELECT region, SUM(total)
FROM mv_region_sales
WHERE sale_date >= '2024-01-01'
GROUP BY region;
```

### 2. ダッシュボード

```sql
-- ダッシュボード用の事前集計
CREATE MATERIALIZED VIEW mv_dashboard
AUTO REFRESH YES
AS
SELECT
    DATE_TRUNC('day', created_at) AS day,
    COUNT(*) AS daily_users,
    COUNT(DISTINCT user_id) AS unique_users
FROM user_events
GROUP BY DATE_TRUNC('day', created_at);
```

### 3. 複雑なJOINの結果をキャッシュ

```sql
CREATE MATERIALIZED VIEW mv_order_details AS
SELECT
    o.order_id,
    o.order_date,
    c.customer_name,
    p.product_name,
    o.quantity,
    o.amount
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN products p ON o.product_id = p.id;
```

## 自動クエリ書き換え

Redshiftが自動的にMVを使用（ユーザーは意識しなくてOK）。

```sql
-- ユーザーが書くクエリ
SELECT region, SUM(amount)
FROM sales
GROUP BY region;

-- Redshiftが自動的に書き換え
SELECT region, SUM(total)
FROM mv_region_sales  -- MVを使用
GROUP BY region;
```

## 制限事項

- 外部テーブル（Spectrum）はベースにできない
- 一部の関数・構文は使えない
- リフレッシュ中はロックがかかる
- ストレージを消費する

## 状態の確認

```sql
-- MVの一覧と状態
SELECT
    mv_name,
    state,        -- 'Active', 'Stale' など
    autorefresh,
    is_stale
FROM svv_mv_info;

-- リフレッシュ履歴
SELECT * FROM svl_mv_refresh_status
ORDER BY starttime DESC;
```

## ベストプラクティス

1. **重い集計クエリに使う** - GROUP BY, JOIN が多いクエリ
2. **ダッシュボードに使う** - ユーザーを待たせない
3. **AUTO REFRESH を有効化** - 手動リフレッシュ忘れ防止
4. **増分リフレッシュ可能な設計** - シンプルなクエリで作る
5. **使わなくなったらDROP** - ストレージとリフレッシュコスト削減
