# Redshift ML

## What is Redshift ML?

**Create and run machine learning models using only SQL**.

```
【Traditional ML】
Extract data → Python/R → Train model → Deploy → Predict
(Complex, requires expertise)

【Redshift ML】
CREATE MODEL ... → Done!
Predict with SQL
(Simple, SQL only)
```

## How it Works

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│  Redshift   │ ───→ │  Amazon     │ ───→ │  Redshift   │
│  Data       │      │  SageMaker  │      │  Model      │
└─────────────┘      │  (Auto ML)  │      └─────────────┘
                     └─────────────┘

1. Send Redshift data to SageMaker
2. SageMaker automatically trains model
3. Return model to Redshift
4. Execute predictions with SQL
```

## Basic Usage

### 1. Create Model

```sql
CREATE MODEL customer_churn_model
FROM (
    SELECT
        age,
        tenure,
        monthly_charges,
        total_charges,
        churn  -- Column to predict (target)
    FROM customers
)
TARGET churn
FUNCTION predict_churn
IAM_ROLE 'arn:aws:iam::123456789:role/RedshiftMLRole'
SETTINGS (
    S3_BUCKET 'my-ml-bucket'
);
```

### 2. Make Predictions

```sql
SELECT
    customer_id,
    predict_churn(age, tenure, monthly_charges, total_charges) AS will_churn
FROM new_customers;
```

## Model Types

### 1. AUTO (Auto-select) - Default

SageMaker Autopilot automatically selects the best model.

```sql
CREATE MODEL my_model
FROM training_data
TARGET target_column
FUNCTION predict_fn
IAM_ROLE '...'
SETTINGS (S3_BUCKET '...');
-- AUTO is default
```

### 2. Classification

Predict categories (Yes/No, A/B/C, etc.).

```sql
CREATE MODEL churn_classifier
FROM training_data
TARGET churn  -- 'Yes' or 'No'
FUNCTION predict_churn
IAM_ROLE '...'
SETTINGS (
    S3_BUCKET '...',
    MODEL_TYPE 'BINARY_CLASSIFICATION'  -- or MULTICLASS_CLASSIFICATION
);
```

### 3. Regression

Predict numeric values (sales, prices, etc.).

```sql
CREATE MODEL sales_predictor
FROM training_data
TARGET sales_amount  -- numeric
FUNCTION predict_sales
IAM_ROLE '...'
SETTINGS (
    S3_BUCKET '...',
    MODEL_TYPE 'REGRESSION'
);
```

### 4. XGBoost (Specified)

Use a specific algorithm.

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

## Practical Examples

### 1. Customer Churn Prediction

```sql
-- Create model
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

-- Predict: Identify customers likely to churn
SELECT customer_id, customer_name
FROM customers
WHERE predict_churn(age, tenure, monthly_charges, contract_type) = 'Yes';
```

### 2. Sales Forecast

```sql
-- Create model
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

-- Predict: Forecast next week's sales
SELECT
    date,
    predict_sales(day_of_week, month, promotion, weather) AS predicted_sales
FROM next_week_schedule;
```

### 3. Fraud Detection

```sql
-- Create model
CREATE MODEL fraud_detector
FROM (
    SELECT amount, merchant_category, time_of_day, location, is_fraud
    FROM transaction_history
)
TARGET is_fraud
FUNCTION detect_fraud
IAM_ROLE '...'
SETTINGS (S3_BUCKET '...');

-- Real-time prediction
SELECT
    transaction_id,
    amount,
    detect_fraud(amount, merchant_category, time_of_day, location) AS fraud_risk
FROM incoming_transactions;
```

## Model Management

### List Models

```sql
SHOW MODELS;
```

### Model Details

```sql
SHOW MODEL my_model;
```

### Check Model Accuracy

```sql
SELECT *
FROM stv_ml_model_info
WHERE model_name = 'my_model';
```

### Delete Model

```sql
DROP MODEL my_model;
```

## Required Setup

### 1. IAM Role

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

### 2. S3 Bucket

Bucket needed for training data and model storage.

```sql
SETTINGS (
    S3_BUCKET 'your-ml-bucket'
)
```

## Pricing

```
【Redshift ML Pricing】
1. Standard Redshift costs
2. SageMaker Autopilot training time
3. S3 storage

※ Prediction execution (FUNCTION calls) has no additional cost
```

## Best Practices

1. **Check data quality** - Handle NULL values and outliers beforehand
2. **Sufficient data volume** - Need at least thousands of rows
3. **Select relevant features** - Exclude columns unrelated to prediction
4. **Verify model accuracy** - Test before production deployment
5. **Retrain periodically** - Update when data changes

## Limitations

- Model creation takes time (minutes to hours)
- Some data types not supported
- Limit on concurrent model creation
