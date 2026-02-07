# Redshift Spectrum

## Redshift Spectrum とは？

Redshift Spectrumは、**S3上のデータをRedshiftにロードせずに直接クエリ**できる機能。

```
┌─────────────────────────────────────────────────────┐
│                    Redshift Cluster                  │
│  ┌─────────────┐                                    │
│  │ 内部        │  ← 通常のテーブル（ロード済み）     │
│  │ テーブル    │                                    │
│  └─────────────┘                                    │
│         +                                           │
│  ┌─────────────┐      ┌─────────────────────┐      │
│  │ 外部        │ ───→ │   S3 (データレイク)  │      │
│  │ テーブル    │      │   Parquet, CSV等    │      │
│  └─────────────┘      └─────────────────────┘      │
└─────────────────────────────────────────────────────┘
```

## なぜ Spectrum を使う？

| シナリオ | 解決策 |
|----------|--------|
| データが大きすぎてロードできない | S3から直接クエリ |
| アクセス頻度が低いデータ | S3に置いて必要時にクエリ |
| データレイク連携 | S3データとRedshiftテーブルをJOIN |
| コスト最適化 | コールドデータはS3に（安い） |

## セットアップ手順

### 1. 外部スキーマを作成

```sql
CREATE EXTERNAL SCHEMA spectrum_schema
FROM DATA CATALOG
DATABASE 'my_glue_database'
IAM_ROLE 'arn:aws:iam::123456789:role/SpectrumRole'
CREATE EXTERNAL DATABASE IF NOT EXISTS;
```

### 2. 外部テーブルを作成

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

### 3. クエリを実行

```sql
-- 外部テーブルにクエリ（データはS3にそのまま）
SELECT region, SUM(amount)
FROM spectrum_schema.sales
WHERE sale_date >= '2024-01-01'
GROUP BY region;

-- 内部テーブルとJOIN
SELECT s.region, s.amount, c.customer_name
FROM spectrum_schema.sales s
JOIN customers c ON s.customer_id = c.id;
```

## パーティショニング（重要！）

パーティショニングでスキャンするデータ量を大幅に削減できる。

### パーティション構造

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

### パーティション付き外部テーブルの作成

```sql
CREATE EXTERNAL TABLE spectrum_schema.sales_partitioned (
    sale_id      INT,
    amount       DECIMAL(10,2),
    region       VARCHAR(50)
)
PARTITIONED BY (year INT, month INT)
STORED AS PARQUET
LOCATION 's3://my-bucket/sales/';

-- パーティションを追加
ALTER TABLE spectrum_schema.sales_partitioned
ADD PARTITION (year=2024, month=1)
LOCATION 's3://my-bucket/sales/year=2024/month=01/';

-- または Glue Crawler で自動検出
```

### パーティションフィルタ付きクエリ

```sql
-- year=2024 のデータだけスキャン（高速！）
SELECT * FROM spectrum_schema.sales_partitioned
WHERE year = 2024 AND month = 1;
```

## サポートされるファイル形式

| フォーマット | 最適な用途 |
|-------------|-----------|
| Parquet | 分析用（カラムナ、圧縮）- **推奨** |
| ORC | 分析用（カラムナ） |
| CSV | シンプルなデータ |
| JSON | 半構造化データ |
| Avro | スキーマ進化対応 |

## 内部テーブル vs 外部テーブル

| | 内部テーブル | 外部テーブル (Spectrum) |
|---|-------------|------------------------|
| データ保存場所 | Redshiftストレージ | S3 |
| クエリ速度 | 高速 | やや遅い |
| ストレージコスト | 高い | 安い |
| データロード | 必要（COPY） | 不要 |
| 用途 | 頻繁にクエリするデータ | アクセス頻度の低いデータ |

## ベストプラクティス

1. **Parquet形式を使う** - カラムナ、圧縮、効率的
2. **よくフィルタするカラムでパーティション** - year, month, region
3. **WHERE句でパーティションフィルタを使う** - フルスキャンを避ける
4. **ホットデータ（内部）とコールドデータ（外部）をJOIN** - 両方の良いとこ取り
