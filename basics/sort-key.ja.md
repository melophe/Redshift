# ソートキー (Sort Key)

## ソートキーとは？

ソートキーは**データがディスク上でどのように物理的に並べられるか**を決定する。

適切なソートキーを選択することで、スキャンするデータ量を大幅に削減できる。

## ソートキーの仕組み

```
ソートキーなし:
┌─────────────────────────────────────┐
│ 2024-01  2024-03  2024-01  2024-02  │  ← 未ソート
│ 2024-02  2024-01  2024-03  2024-01  │
└─────────────────────────────────────┘
クエリ: WHERE date = '2024-01' → 全ブロックをスキャン

ソートキーあり (date):
┌─────────────────────────────────────┐
│ 2024-01  2024-01  2024-01  2024-01  │  ← Block 1
│ 2024-02  2024-02  2024-02  2024-02  │  ← Block 2
│ 2024-03  2024-03  2024-03  2024-03  │  ← Block 3
└─────────────────────────────────────┘
クエリ: WHERE date = '2024-01' → Block 1だけスキャン！
```

## ゾーンマップ

Redshiftは各ブロックの最小値/最大値を記録している（ゾーンマップ）。

```
Block 1: min=2024-01-01, max=2024-01-31
Block 2: min=2024-02-01, max=2024-02-28
Block 3: min=2024-03-01, max=2024-03-31

クエリ: WHERE date = '2024-02-15'
→ Block 1をスキップ (max < 2024-02-15)
→ Block 2をスキャン (該当日が含まれる)
→ Block 3をスキップ (min > 2024-02-15)
```

## ソートキーの種類

### 1. Compound Sort Key（複合ソートキー）

カラムの順番通りにソートされる（ORDER BY col1, col2, col3 と同じ）。

```sql
CREATE TABLE sales (
    sale_date   DATE,
    region      VARCHAR(50),
    product_id  INT,
    amount      DECIMAL(10,2)
)
COMPOUND SORTKEY (sale_date, region);
```

**効果があるクエリ:**
```sql
-- ソートキーを使う（sale_dateから始まる）
WHERE sale_date = '2024-01-15'
WHERE sale_date = '2024-01-15' AND region = 'Tokyo'

-- ソートキーを使わない（sale_dateをスキップ）
WHERE region = 'Tokyo'  -- NG: 先頭カラムがない
```

### 2. Interleaved Sort Key（インターリーブソートキー）

すべてのカラムが平等に扱われる（順序の依存がない）。

```sql
CREATE TABLE events (
    event_date  DATE,
    user_id     INT,
    event_type  VARCHAR(50)
)
INTERLEAVED SORTKEY (event_date, user_id);
```

**効果があるクエリ:**
```sql
-- すべてソートキーを使う
WHERE event_date = '2024-01-15'
WHERE user_id = 12345
WHERE event_date = '2024-01-15' AND user_id = 12345
```

**トレードオフ:**
- フィルタリングの柔軟性が高い
- VACUUMが遅い（再ソートが必要）
- メンテナンスコストが高い

## Compound vs Interleaved

| | Compound | Interleaved |
|---|----------|-------------|
| クエリの柔軟性 | 先頭カラムから使う必要あり | どのカラムでもOK |
| VACUUMの速度 | 速い | 遅い |
| 適したケース | 決まったクエリパターン | アドホックなクエリ |
| 推奨 | **デフォルトでこれを使う** | 必要な場合のみ |

## 構文の例

```sql
-- Compound（指定しない場合のデフォルト）
CREATE TABLE t1 (...) SORTKEY (col1, col2);
CREATE TABLE t2 (...) COMPOUND SORTKEY (col1, col2);

-- Interleaved
CREATE TABLE t3 (...) INTERLEAVED SORTKEY (col1, col2);

-- ソートキーなし
CREATE TABLE t4 (...) SORTKEY ();
```

## ベストプラクティス

| シナリオ | 推奨ソートキー |
|----------|---------------|
| 時系列データ（ログ、イベント） | 日付/タイムスタンプカラム |
| 常に日付でフィルタするクエリ | COMPOUND (date, ...) |
| 様々なカラムでフィルタするクエリ | INTERLEAVED |
| WHERE句で頻繁に使うカラム | ソートキーに含める |
| JOINで頻繁に使うカラム | ソートキー候補として検討 |

## ソートキーの効果を確認する

```sql
-- ソートキーが使われているか確認
EXPLAIN SELECT * FROM sales WHERE sale_date = '2024-01-15';

-- 出力で "Filter" vs "Seq Scan" を確認する
```
