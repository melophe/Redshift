# セキュリティ

Redshiftのセキュリティ機能について学びます。

## 概要

```
┌─────────────────────────────────────────────────────┐
│                  セキュリティ層                      │
├─────────────────────────────────────────────────────┤
│  1. ネットワーク    VPC, セキュリティグループ        │
│  2. 認証           IAM, DBユーザー                  │
│  3. 認可           GRANT/REVOKE, ロール             │
│  4. 暗号化         保存時, 転送時                    │
│  5. 監査           監査ログ                         │
└─────────────────────────────────────────────────────┘
```

## 1. ネットワークセキュリティ

### VPC設定

```
┌─────────────────────────────────────┐
│              VPC                    │
│  ┌─────────────────────────────┐   │
│  │      Private Subnet         │   │
│  │  ┌───────────────────────┐  │   │
│  │  │     Redshift          │  │   │
│  │  └───────────────────────┘  │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

### セキュリティグループ

```sql
-- 本番環境の推奨設定
Inbound:
  - Port 5439 from アプリケーションサーバーのみ

Outbound:
  - 必要最小限
```

### パブリックアクセス

| 環境 | publicly_accessible |
|------|---------------------|
| 開発/ハンズオン | true（便利だが注意） |
| 本番 | **false**（推奨） |

## 2. 認証

### IAM認証（推奨）

```sql
-- 一時的な認証情報を取得
aws redshift get-cluster-credentials \
  --db-user myuser \
  --cluster-identifier mycluster
```

### データベースユーザー

```sql
-- ユーザー作成
CREATE USER analyst PASSWORD 'SecurePassword123!';

-- パスワード変更
ALTER USER analyst PASSWORD 'NewSecurePassword456!';
```

### Secrets Manager連携

```python
# アプリケーションからの接続例
import boto3

client = boto3.client('secretsmanager')
secret = client.get_secret_value(SecretId='redshift/credentials')
```

## 3. 認可（権限管理）

### 基本的な権限

```sql
-- スキーマへのアクセス権
GRANT USAGE ON SCHEMA public TO analyst;

-- テーブルへのSELECT権限
GRANT SELECT ON TABLE sales TO analyst;

-- 全テーブルへの権限
GRANT SELECT ON ALL TABLES IN SCHEMA public TO analyst;
```

### 権限の取り消し

```sql
REVOKE SELECT ON TABLE sales FROM analyst;
```

### ロールベースアクセス制御

```sql
-- ロール作成
CREATE ROLE data_reader;

-- ロールに権限付与
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ROLE data_reader;

-- ユーザーにロール付与
GRANT ROLE data_reader TO analyst;
```

### 行レベルセキュリティ（RLS）

```sql
-- RLSポリシー作成
CREATE RLS POLICY region_policy
WITH (region_id INT)
USING (region_id = current_setting('app.region_id')::INT);

-- テーブルに適用
ALTER TABLE sales ATTACH RLS POLICY region_policy;
```

## 4. 暗号化

### 保存時の暗号化（At Rest）

```sql
-- クラスター作成時に指定
CREATE CLUSTER ... ENCRYPTED;

-- KMSキーを使用
CREATE CLUSTER ...
  ENCRYPTED
  KMS_KEY_ID 'arn:aws:kms:...';
```

### 転送時の暗号化（In Transit）

```
クライアント ──── SSL/TLS ──── Redshift
```

```sql
-- SSL必須設定
ALTER USER analyst SET require_ssl = true;
```

### 確認方法

```sql
-- 暗号化状態の確認
SELECT encrypted FROM svv_table_info WHERE table = 'sales';
```

## 5. 監査ログ

### 監査ログの有効化

```sql
-- パラメータグループで設定
enable_user_activity_logging = true
```

### ログの種類

| ログ | 内容 |
|------|------|
| Connection log | 接続/切断の記録 |
| User log | ユーザー変更の記録 |
| User activity log | 実行クエリの記録 |

### ログの確認

```sql
-- 最近のクエリを確認
SELECT
    starttime,
    userid,
    query
FROM stl_query
ORDER BY starttime DESC
LIMIT 20;

-- ログインの確認
SELECT
    event_time,
    username,
    remotehost
FROM stl_connection_log
ORDER BY event_time DESC;
```

### S3へのエクスポート

```sql
-- 監査ログをS3に保存
-- AWS ConsoleまたはCLIで設定
aws redshift modify-cluster \
  --cluster-identifier mycluster \
  --logging-properties '{"BucketName":"my-audit-logs"}'
```

## ベストプラクティス

### 本番環境チェックリスト

```
□ VPC内のプライベートサブネットに配置
□ セキュリティグループで必要なポートのみ許可
□ publicly_accessible = false
□ 暗号化を有効化（KMS使用推奨）
□ SSL接続を必須化
□ 監査ログを有効化
□ 最小権限の原則でGRANT
□ Secrets Managerでパスワード管理
□ 定期的なパスワードローテーション
```

### 権限設計例

```
┌─────────────────────────────────────────┐
│           ロール設計                     │
├─────────────────────────────────────────┤
│ admin_role      全権限                  │
│ etl_role        INSERT/UPDATE/DELETE    │
│ analyst_role    SELECT only             │
│ viewer_role     特定テーブルのみSELECT   │
└─────────────────────────────────────────┘
```

```sql
-- 例: analyst用ロール
CREATE ROLE analyst_role;
GRANT USAGE ON SCHEMA public TO ROLE analyst_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO ROLE analyst_role;

-- ETL用ロール
CREATE ROLE etl_role;
GRANT ALL ON SCHEMA staging TO ROLE etl_role;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ROLE etl_role;
```

## まとめ

| 層 | 機能 | 本番での推奨 |
|----|------|-------------|
| ネットワーク | VPC, SG | プライベートサブネット |
| 認証 | IAM, DB User | IAM + Secrets Manager |
| 認可 | GRANT, Role | 最小権限 + ロールベース |
| 暗号化 | KMS | 有効化必須 |
| 監査 | Audit Log | 有効化必須 |
