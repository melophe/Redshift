# 分散キー (Distribution Key)

## 分散キーとは？

分散キーは**データを各コンピュートノードにどのように分散させるか**を決定する。

適切な分散キーの選択はクエリパフォーマンスに大きく影響する。

```
                    テーブルデータ
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
     ┌─────────┐   ┌─────────┐   ┌─────────┐
     │ Node 1  │   │ Node 2  │   │ Node 3  │
     │ user_id │   │ user_id │   │ user_id │
     │ 1, 4, 7 │   │ 2, 5, 8 │   │ 3, 6, 9 │
     └─────────┘   └─────────┘   └─────────┘
```

## 分散スタイルの種類

### 1. KEY 分散

特定のカラムの値に基づいてデータを分散する。

```sql
CREATE TABLE orders (
    order_id    INT,
    customer_id INT,
    amount      DECIMAL(10,2)
)
DISTSTYLE KEY
DISTKEY (customer_id);
```

**使用場面:**
- JOINで頻繁に使われるカラム
- カーディナリティが高い（ユニークな値が多い）カラム

### 2. EVEN 分散

ラウンドロビン方式で均等にデータを分散する。

```sql
CREATE TABLE logs (
    log_id      INT,
    message     VARCHAR(500),
    created_at  TIMESTAMP
)
DISTSTYLE EVEN;
```

**使用場面:**
- 明確なJOINカラムがない
- 他のテーブルとJOINしないテーブル

### 3. ALL 分散

テーブル全体を全ノードにコピーする。

```sql
CREATE TABLE countries (
    country_code CHAR(2),
    country_name VARCHAR(100)
)
DISTSTYLE ALL;
```

**使用場面:**
- 小さなディメンション/マスタテーブル
- 大きなテーブルと頻繁にJOINするテーブル

### 4. AUTO 分散

Redshiftが自動的に最適な分散方法を選択する。

```sql
CREATE TABLE products (
    product_id   INT,
    product_name VARCHAR(200)
)
DISTSTYLE AUTO;
```

## なぜ分散キーが重要か

### 良い分散 (Co-located JOIN)

```
Node 1: orders(customer_id=1) + customers(customer_id=1)
Node 2: orders(customer_id=2) + customers(customer_id=2)
→ JOINが各ノード内でローカルに実行される（高速）
```

### 悪い分散 (データ再分散が必要)

```
Node 1: orders(customer_id=1)     customers(customer_id=2)
Node 2: orders(customer_id=2)     customers(customer_id=1)
→ ノード間でデータを移動する必要がある（低速）
```

## 現在の分散設定を確認する

```sql
SELECT "table", diststyle
FROM svv_table_info
WHERE "table" = 'your_table_name';
```

## ベストプラクティス

| シナリオ | 推奨スタイル |
|----------|-------------|
| 頻繁にJOINする大きなファクトテーブル | KEY（JOINカラムで） |
| 小さなディメンションテーブル（100万行以下） | ALL |
| ステージング/一時テーブル | EVEN または AUTO |
| 迷ったら | AUTO |
