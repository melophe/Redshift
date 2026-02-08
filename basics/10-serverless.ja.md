# Redshift Serverless

## Redshift Serverless とは？

**クラスタ管理なしで使える Redshift**。

```
【Provisioned（従来型）】
クラスタを作成 → ノード数を決める → 管理が必要

【Serverless】
使うだけ → 自動スケーリング → 管理不要
```

## Provisioned vs Serverless

| | Provisioned | Serverless |
|---|-------------|------------|
| クラスタ管理 | 必要（ノード数、タイプ） | 不要 |
| スケーリング | 手動またはスケジュール | 自動 |
| 料金 | ノード単位の時間課金 | 使用した計算量（RPU）課金 |
| アイドル時 | 課金される | 課金されない |
| 適したワークロード | 予測可能、常時稼働 | 変動が大きい、断続的 |

## 基本概念

### 1. Workgroup（ワークグループ）

計算リソースの単位。

```
┌─────────────────────────────────────┐
│          Workgroup                   │
│                                      │
│   ┌──────────────────────────────┐  │
│   │  Compute Resources (RPU)      │  │
│   │  32 - 512 RPU                 │  │
│   └──────────────────────────────┘  │
│                                      │
│   設定: Base RPU, Max RPU           │
└─────────────────────────────────────┘
```

### 2. Namespace（ネームスペース）

データベースオブジェクトの格納場所。

```
┌─────────────────────────────────────┐
│          Namespace                   │
│                                      │
│   - データベース                      │
│   - スキーマ                         │
│   - テーブル                         │
│   - ユーザー                         │
│   - IAMロール                        │
└─────────────────────────────────────┘
```

### 関係性

```
┌─────────────┐      ┌─────────────┐
│  Workgroup  │ ───→ │  Namespace  │
│  (計算)     │      │  (データ)   │
└─────────────┘      └─────────────┘

1つの Namespace に複数の Workgroup を接続可能
→ 開発用と本番用で別の Workgroup
```

## RPU（Redshift Processing Unit）

計算能力の単位。

```
【RPU設定】
Base RPU: 32   ← 最小（アイドル時はゼロ）
Max RPU: 256   ← 最大（自動スケール上限）

クエリが来る → RPUが自動で増える → 終わったら減る
```

| RPU | 用途 |
|-----|------|
| 32 | 小規模、開発環境 |
| 128 | 中規模ワークロード |
| 256+ | 大規模、高負荷 |

## 料金モデル

```
【Provisioned】
ノード × 時間 = 料金
→ 使ってなくても課金

【Serverless】
RPU × 秒 = 料金
→ 使った分だけ課金
→ アイドル時は無料！
```

### 料金例

```
Serverless:
- Base: 32 RPU
- 1日8時間クエリ実行
- 料金 = 32 RPU × 8時間 × $0.36/RPU時間 = $92.16/日

Provisioned (dc2.large 4ノード):
- 24時間稼働
- 料金 = 4 × 24時間 × $0.25/時間 = $24/日

→ 常時稼働ならProvisioned
→ 断続的ならServerless
```

## セットアップ

### 1. Namespace 作成

```
AWS Console → Redshift → Serverless → Create namespace

- Namespace name: my-namespace
- Database name: dev
- Admin username/password
- IAM role
```

### 2. Workgroup 作成

```
AWS Console → Redshift → Serverless → Create workgroup

- Workgroup name: my-workgroup
- Base capacity: 32 RPU
- Namespace: my-namespace
- VPC設定
```

### 3. 接続

```sql
-- エンドポイント例
my-workgroup.123456789.ap-northeast-1.redshift-serverless.amazonaws.com:5439

-- psql
psql -h my-workgroup.123456789.ap-northeast-1.redshift-serverless.amazonaws.com \
     -p 5439 -U admin -d dev
```

## Serverless の機能

### 自動スケーリング

```
クエリ少 → 32 RPU
    ↓
クエリ増 → 64 RPU → 128 RPU → 256 RPU
    ↓
クエリ減 → 128 RPU → 64 RPU → 32 RPU → 0（アイドル）
```

### 使用量上限

```sql
-- 1日の最大RPU時間を設定（コスト管理）
-- AWS Consoleで設定: Usage limit
```

### スナップショット

```
Provisioned と同様にスナップショット可能
→ バックアップ、リストア、クロスリージョンコピー
```

## Provisioned から Serverless への移行

```
1. Provisioned クラスタのスナップショットを作成
2. Serverless の Namespace を作成
3. スナップショットから Namespace にリストア
4. アプリの接続先を変更
```

## いつ Serverless を使う？

| シナリオ | 推奨 |
|----------|------|
| 24時間ダッシュボード | Provisioned |
| 夜間バッチのみ | **Serverless** |
| 開発・テスト環境 | **Serverless** |
| ワークロードが変動 | **Serverless** |
| 予測可能な高負荷 | Provisioned |
| コスト最適化が重要 | 比較して選択 |

## ベストプラクティス

1. **開発環境は Serverless** - コスト削減
2. **Base RPU は小さく始める** - 32から開始
3. **Usage Limit を設定** - 予算超過を防ぐ
4. **VPC 設定を確認** - セキュリティグループ、サブネット
5. **監視を設定** - CloudWatch でRPU使用量を監視
