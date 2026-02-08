# Redshift ML

## Redshift ML とは？

**SQLだけで機械学習モデルを作成・実行**できる機能。

```
【従来の機械学習】
データ抽出 → Python/R → モデル学習 → デプロイ → 予測
（複雑、専門知識が必要）

【Redshift ML】
CREATE MODEL ... → 完了！
SQLで予測
（シンプル、SQLだけでOK）
```

## 仕組み

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│  Redshift   │ ───→ │  Amazon     │ ───→ │  Redshift   │
│  データ     │      │  SageMaker  │      │  モデル     │
└─────────────┘      │  (自動学習) │      └─────────────┘
                     └─────────────┘

1. RedshiftのデータをSageMakerに送る
2. SageMakerが自動でモデルを学習
3. モデルをRedshiftに戻す
4. SQLで予測実行
```

## 基本的な使い方

### 1. モデルを作成

```sql
CREATE MODEL customer_churn_model
FROM (
    SELECT
        age,
        tenure,
        monthly_charges,
        total_charges,
        churn  -- 予測したい列（ターゲット）
    FROM customers
)
TARGET churn
FUNCTION predict_churn
IAM_ROLE 'arn:aws:iam::123456789:role/RedshiftMLRole'
SETTINGS (
    S3_BUCKET 'my-ml-bucket'
);
```

### 2. 予測を実行

```sql
SELECT
    customer_id,
    predict_churn(age, tenure, monthly_charges, total_charges) AS will_churn
FROM new_customers;
```

## モデルの種類

### 1. AUTO（自動選択）- デフォルト

SageMaker Autopilotが最適なモデルを自動選択。

```sql
CREATE MODEL my_model
FROM training_data
TARGET target_column
FUNCTION predict_fn
IAM_ROLE '...'
SETTINGS (S3_BUCKET '...');
-- AUTO がデフォルト
```

### 2. 分類（Classification）

カテゴリを予測（Yes/No、A/B/C など）。

```sql
CREATE MODEL churn_classifier
FROM training_data
TARGET churn  -- 'Yes' or 'No'
FUNCTION predict_churn
IAM_ROLE '...'
SETTINGS (
    S3_BUCKET '...',
    MODEL_TYPE 'BINARY_CLASSIFICATION'  -- または MULTICLASS_CLASSIFICATION
);
```

### 3. 回帰（Regression）

数値を予測（売上、価格など）。

```sql
CREATE MODEL sales_predictor
FROM training_data
TARGET sales_amount  -- 数値
FUNCTION predict_sales
IAM_ROLE '...'
SETTINGS (
    S3_BUCKET '...',
    MODEL_TYPE 'REGRESSION'
);
```

### 4. XGBoost（指定）

特定のアルゴリズムを使用。

```sql
CREATE MODEL xgboost_model
FROM training_data
TARGET target_column
FUNCTION predict_fn
IAM_ROLE '...'
SETTINGS (
    S3_BUCKET '...',
    MODEL_TYPE 'XGBOOST'
);
```

## 実用例

### 1. 顧客離脱予測

```sql
-- モデル作成
CREATE MODEL churn_model
FROM (
    SELECT age, tenure, monthly_charges, contract_type, churn
    FROM customer_history
    WHERE churn IS NOT NULL
)
TARGET churn
FUNCTION predict_churn
IAM_ROLE 'arn:aws:iam::123456789:role/RedshiftMLRole'
SETTINGS (S3_BUCKET 'my-bucket');

-- 予測：離脱しそうな顧客を特定
SELECT customer_id, customer_name
FROM customers
WHERE predict_churn(age, tenure, monthly_charges, contract_type) = 'Yes';
```

### 2. 売上予測

```sql
-- モデル作成
CREATE MODEL sales_model
FROM (
    SELECT day_of_week, month, promotion, weather, sales
    FROM historical_sales
)
TARGET sales
FUNCTION predict_sales
IAM_ROLE '...'
SETTINGS (
    S3_BUCKET '...',
    MODEL_TYPE 'REGRESSION'
);

-- 予測：来週の売上予測
SELECT
    date,
    predict_sales(day_of_week, month, promotion, weather) AS predicted_sales
FROM next_week_schedule;
```

### 3. 不正検知

```sql
-- モデル作成
CREATE MODEL fraud_detector
FROM (
    SELECT amount, merchant_category, time_of_day, location, is_fraud
    FROM transaction_history
)
TARGET is_fraud
FUNCTION detect_fraud
IAM_ROLE '...'
SETTINGS (S3_BUCKET '...');

-- リアルタイム予測
SELECT
    transaction_id,
    amount,
    detect_fraud(amount, merchant_category, time_of_day, location) AS fraud_risk
FROM incoming_transactions;
```

## モデルの管理

### モデル一覧

```sql
SHOW MODELS;
```

### モデルの詳細

```sql
SHOW MODEL my_model;
```

### モデルの精度確認

```sql
SELECT *
FROM stv_ml_model_info
WHERE model_name = 'my_model';
```

### モデル削除

```sql
DROP MODEL my_model;
```

## 必要な設定

### 1. IAMロール

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sagemaker:*",
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket"
            ],
            "Resource": "*"
        }
    ]
}
```

### 2. S3バケット

学習データとモデルを保存するバケットが必要。

```sql
SETTINGS (
    S3_BUCKET 'your-ml-bucket'
)
```

## 料金

```
【Redshift ML の料金】
1. Redshift の通常料金
2. SageMaker Autopilot の学習時間
3. S3 のストレージ

※ 予測実行（FUNCTION呼び出し）は追加料金なし
```

## ベストプラクティス

1. **データ品質を確認** - NULL値や異常値を事前に処理
2. **十分なデータ量** - 最低でも数千行は必要
3. **関連する特徴量を選ぶ** - 予測に関係ない列は除外
4. **モデルの精度を確認** - 本番投入前にテスト
5. **定期的に再学習** - データが変わったら更新

## 制限事項

- モデル作成には時間がかかる（数分〜数時間）
- 一部のデータ型は使用不可
- 同時に作成できるモデル数に制限あり
