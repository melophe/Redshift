# COPY と UNLOAD コマンド

## 概要

| コマンド | 方向 | 目的 |
|---------|------|------|
| COPY | S3 → Redshift | Redshiftにデータをロード |
| UNLOAD | Redshift → S3 | Redshiftからデータをエクスポート |

```
┌─────────┐   COPY    ┌───────────┐
│   S3    │ ───────→  │  Redshift │
│         │ ←───────  │           │
└─────────┘  UNLOAD   └───────────┘
```

## COPY コマンド

### 基本構文

```sql
COPY table_name
FROM 's3://bucket/path/'
IAM_ROLE 'arn:aws:iam::123456789:role/RedshiftRole'
FORMAT AS CSV;
```

### よく使うオプション

```sql
COPY sales
FROM 's3://my-bucket/data/sales/'
IAM_ROLE 'arn:aws:iam::123456789:role/RedshiftRole'
FORMAT AS CSV
DELIMITER ','
IGNOREHEADER 1           -- ヘッダー行をスキップ
DATEFORMAT 'YYYY-MM-DD'
TIMEFORMAT 'auto'
REGION 'ap-northeast-1'
GZIP;                    -- 圧縮ファイルの場合
```

### サポートされるフォーマット

| フォーマット | オプション |
|-------------|-----------|
| CSV | `FORMAT AS CSV` または `DELIMITER ','` |
| JSON | `FORMAT AS JSON 'auto'` または `JSON 's3://path/jsonpaths.json'` |
| Parquet | `FORMAT AS PARQUET` |
| ORC | `FORMAT AS ORC` |
| Avro | `FORMAT AS AVRO` |

### COPY のベストプラクティス

1. **並列ロードのためにファイルを分割**
   ```
   s3://bucket/data/part-001.csv
   s3://bucket/data/part-002.csv
   s3://bucket/data/part-003.csv
   ...
   → ファイル数 = スライス数の倍数（最高性能）
   ```

2. **圧縮ファイルを使用**
   ```sql
   COPY ... GZIP;   -- または BZIP2, LZOP, ZSTD
   ```

3. **特定ファイルを指定するマニフェストファイル**
   ```sql
   COPY table_name
   FROM 's3://bucket/manifest.json'
   MANIFEST;
   ```

   manifest.json:
   ```json
   {
     "entries": [
       {"url": "s3://bucket/file1.csv", "mandatory": true},
       {"url": "s3://bucket/file2.csv", "mandatory": true}
     ]
   }
   ```

## UNLOAD コマンド

### 基本構文

```sql
UNLOAD ('SELECT * FROM table_name')
TO 's3://bucket/output/'
IAM_ROLE 'arn:aws:iam::123456789:role/RedshiftRole';
```

### よく使うオプション

```sql
UNLOAD ('SELECT * FROM sales WHERE year = 2024')
TO 's3://my-bucket/export/sales_2024_'
IAM_ROLE 'arn:aws:iam::123456789:role/RedshiftRole'
FORMAT AS PARQUET        -- または CSV, JSON
PARTITION BY (region)    -- パーティション分割出力
PARALLEL ON              -- デフォルト: 並列出力
ALLOWOVERWRITE           -- 既存ファイルを上書き
MAXFILESIZE 256 MB;      -- ファイルサイズを制御
```

### 出力フォーマット

```sql
-- CSV（デフォルト）
UNLOAD ('...') TO '...' DELIMITER ',' HEADER;

-- Parquet（分析用に推奨）
UNLOAD ('...') TO '...' FORMAT AS PARQUET;

-- JSON
UNLOAD ('...') TO '...' FORMAT AS JSON;
```

### パーティション分割出力

```sql
UNLOAD ('SELECT * FROM sales')
TO 's3://bucket/sales/'
PARTITION BY (year, month)
FORMAT AS PARQUET;

-- 作成される構造:
-- s3://bucket/sales/year=2024/month=01/part-001.parquet
-- s3://bucket/sales/year=2024/month=02/part-001.parquet
```

## COPY vs INSERT

| | COPY | INSERT |
|---|------|--------|
| 速度 | 高速（並列） | 遅い（行ごと） |
| ソース | S3, DynamoDB, EMR | SQLクエリ |
| 用途 | 大量ロード | 少量の挿入 |

**大量ロードには必ず COPY を使う！**

## エラー処理

```sql
-- COPYエラーを確認
SELECT * FROM stl_load_errors
ORDER BY starttime DESC
LIMIT 10;

-- 一部のエラーを許容
COPY ...
MAXERROR 100;  -- 100件未満のエラーなら続行
```
