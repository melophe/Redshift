# データ共有 (Data Sharing)

## データ共有とは？

**別のRedshiftクラスタ/Serverlessとデータをコピーなしで共有**する機能。

```
【従来】
Cluster A → UNLOAD → S3 → COPY → Cluster B
（データをコピー、時間かかる、データが古くなる）

【データ共有】
Cluster A ────────→ Cluster B
     ↑ 直接参照（コピーなし、常に最新）
```

## なぜ必要？

```
【問題】
- 本番データを分析チームにも見せたい
- でも本番クラスタに負荷をかけたくない
- データをコピーすると古くなる

【データ共有で解決】
- 本番データを直接参照
- 分析は別クラスタで実行（本番に負荷なし）
- 常に最新データ
```

## 用語

```
┌──────────────────┐          ┌──────────────────┐
│   Producer       │ ──────→  │   Consumer       │
│   (提供側)        │  共有    │   (利用側)        │
│                  │          │                  │
│   Datashare      │          │   外部DB参照      │
│   を作成         │          │   でアクセス      │
└──────────────────┘          └──────────────────┘
```

| 用語 | 意味 |
|------|------|
| Producer | データを提供するクラスタ |
| Consumer | データを利用するクラスタ |
| Datashare | 共有するオブジェクトの定義 |

## セットアップ手順

### 1. Producer側: Datashare を作成

```sql
-- Datashare を作成
CREATE DATASHARE sales_share;

-- スキーマを追加
ALTER DATASHARE sales_share ADD SCHEMA public;

-- テーブルを追加
ALTER DATASHARE sales_share ADD TABLE public.sales;
ALTER DATASHARE sales_share ADD TABLE public.customers;

-- 全テーブルを追加する場合
ALTER DATASHARE sales_share ADD ALL TABLES IN SCHEMA public;
```

### 2. Producer側: Consumer に権限を付与

```sql
-- 同じAWSアカウント内のクラスタに共有
GRANT USAGE ON DATASHARE sales_share
TO NAMESPACE 'consumer-namespace-id';

-- 別のAWSアカウントに共有
GRANT USAGE ON DATASHARE sales_share
TO ACCOUNT '123456789012';
```

### 3. Consumer側: Datashare からデータベースを作成

```sql
-- Datashare を確認
SHOW DATASHARES;

-- 外部データベースを作成
CREATE DATABASE sales_db
FROM DATASHARE sales_share
OF NAMESPACE 'producer-namespace-id';
```

### 4. Consumer側: クエリ実行

```sql
-- 共有データにアクセス
SELECT * FROM sales_db.public.sales;

-- ローカルテーブルとJOIN
SELECT s.*, l.local_column
FROM sales_db.public.sales s
JOIN local_schema.local_table l ON s.id = l.id;
```

## 共有できるオブジェクト

| オブジェクト | 共有可能？ |
|-------------|-----------|
| テーブル | ✅ |
| ビュー | ✅ |
| マテリアライズドビュー | ✅ |
| UDF（ユーザー定義関数） | ✅ |
| スキーマ | ✅ |
| 外部テーブル（Spectrum） | ❌ |

## ユースケース

### 1. 本番と分析の分離

```
┌──────────────────┐          ┌──────────────────┐
│   Production     │ ──────→  │   Analytics      │
│   本番クラスタ    │          │   分析クラスタ    │
│                  │          │                  │
│   書き込み処理    │          │   重いクエリ      │
└──────────────────┘          └──────────────────┘

本番に影響なく分析可能
```

### 2. マルチテナント

```
┌──────────────────┐          ┌──────────────────┐
│   Central Data   │ ──────→  │   Tenant A       │
│   中央データ      │          └──────────────────┘
│                  │ ──────→  ┌──────────────────┐
│                  │          │   Tenant B       │
└──────────────────┘          └──────────────────┘

テナントごとに別クラスタでアクセス
```

### 3. 部門間共有

```
┌──────────────────┐          ┌──────────────────┐
│   Sales Dept     │ ──────→  │   Marketing      │
│   営業部門        │          │   マーケティング  │
└──────────────────┘          └──────────────────┘

営業データをマーケティングが参照
```

## 料金

```
【Producer】
- 通常のストレージ料金
- 共有自体は無料

【Consumer】
- ストレージ料金なし（データはProducerにある）
- クエリ実行のコンピュート料金のみ
```

## 制限事項

- Consumer は**読み取り専用**（INSERT/UPDATE/DELETE 不可）
- Producer と Consumer は**同じリージョン**である必要（※クロスリージョンも可能だが追加設定要）
- 外部テーブル（Spectrum）は共有不可

## Datashare の管理

### 共有状況の確認

```sql
-- Producer: 作成したDatashareを確認
SELECT * FROM svv_datashares;

-- Consumer: 利用可能なDatashareを確認
SHOW DATASHARES;

-- Datashareの中身を確認
SELECT * FROM svv_datashare_objects
WHERE share_name = 'sales_share';
```

### Datashare からオブジェクトを削除

```sql
ALTER DATASHARE sales_share REMOVE TABLE public.old_table;
```

### Datashare を削除

```sql
DROP DATASHARE sales_share;
```

## ベストプラクティス

1. **本番と分析を分離** - 重いクエリを別クラスタで実行
2. **必要なテーブルだけ共有** - セキュリティとシンプルさ
3. **権限を最小限に** - 必要なConsumerだけに付与
4. **監視を設定** - 誰がどのデータにアクセスしているか
5. **Serverless と組み合わせ** - Consumer側はServerlessでコスト最適化
