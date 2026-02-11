# 監視・運用

Redshiftの監視と運用について学びます。

## 概要

```
┌─────────────────────────────────────────────────────┐
│                  監視の観点                          │
├─────────────────────────────────────────────────────┤
│  1. パフォーマンス   クエリ実行時間, CPU, メモリ     │
│  2. ストレージ       使用量, 増加傾向                │
│  3. 接続             同時接続数, 接続エラー          │
│  4. クエリ           遅いクエリ, エラークエリ        │
│  5. コスト           RPU使用量, ストレージコスト     │
└─────────────────────────────────────────────────────┘
```

## 1. システムテーブル・ビュー

### よく使うシステムビュー

| ビュー | 用途 |
|--------|------|
| SVV_TABLE_INFO | テーブル情報 |
| SVL_QUERY_SUMMARY | クエリサマリー |
| STL_QUERY | クエリ履歴 |
| STL_WLM_QUERY | WLMキュー情報 |
| SVL_QLOG | クエリログ |

### テーブル情報の確認

```sql
-- テーブルサイズと行数
SELECT
    "table" as table_name,
    size as size_mb,
    tbl_rows as row_count,
    diststyle,
    sortkey1
FROM svv_table_info
ORDER BY size DESC;
```

### クエリ履歴の確認

```sql
-- 最近のクエリ
SELECT
    query,
    substring(querytxt, 1, 100) as query_text,
    starttime,
    endtime,
    DATEDIFF(seconds, starttime, endtime) as duration_sec
FROM stl_query
WHERE userid > 1  -- システムクエリを除外
ORDER BY starttime DESC
LIMIT 20;
```

### 遅いクエリの特定

```sql
-- 実行時間が長いクエリTOP10
SELECT
    query,
    substring(querytxt, 1, 100) as query_text,
    DATEDIFF(seconds, starttime, endtime) as duration_sec,
    aborted
FROM stl_query
WHERE userid > 1
ORDER BY duration_sec DESC
LIMIT 10;
```

## 2. CloudWatch メトリクス

### 主要メトリクス

| メトリクス | 説明 | 注意レベル |
|-----------|------|-----------|
| CPUUtilization | CPU使用率 | > 80% |
| PercentageDiskSpaceUsed | ディスク使用率 | > 75% |
| DatabaseConnections | 接続数 | 上限に注意 |
| ReadIOPS / WriteIOPS | I/O操作数 | 急増に注意 |
| QueryDuration | クエリ実行時間 | ベースラインと比較 |

### Serverless固有のメトリクス

| メトリクス | 説明 |
|-----------|------|
| ComputeSeconds | RPU使用秒数 |
| ComputeCapacity | 現在のRPU |
| QueriesCompletedPerSecond | 秒間完了クエリ数 |

### CloudWatchアラーム設定例

```
アラーム名: Redshift-HighCPU
メトリクス: CPUUtilization
条件: > 80% が 5分間継続
アクション: SNS通知

アラーム名: Redshift-DiskSpace
メトリクス: PercentageDiskSpaceUsed
条件: > 75%
アクション: SNS通知
```

## 3. クエリモニタリング

### 実行中のクエリ確認

```sql
-- 現在実行中のクエリ
SELECT
    query,
    pid,
    userid,
    starttime,
    substring(querytxt, 1, 100) as query_text
FROM stv_recents
WHERE status = 'Running';
```

### クエリのキャンセル

```sql
-- 特定のクエリをキャンセル
CANCEL <query_id>;

-- プロセスを終了
SELECT pg_terminate_backend(<pid>);
```

### クエリキューの確認

```sql
-- WLMキューの状態
SELECT
    service_class,
    num_queued_queries,
    num_executing_queries,
    query_cpu_time,
    query_blocks_read
FROM stv_wlm_service_class_state;
```

## 4. テーブルメンテナンス

### VACUUM状態の確認

```sql
-- VACUUM が必要なテーブル
SELECT
    "table" as table_name,
    unsorted,
    vacuum_sort_benefit
FROM svv_table_info
WHERE unsorted > 5  -- 5%以上ソートされていない
ORDER BY unsorted DESC;
```

### ANALYZE状態の確認

```sql
-- 統計情報が古いテーブル
SELECT
    "table" as table_name,
    stats_off
FROM svv_table_info
WHERE stats_off > 10  -- 10%以上ずれている
ORDER BY stats_off DESC;
```

### メンテナンスの実行

```sql
-- 特定テーブルのVACUUM
VACUUM fact_lesson_completions;

-- 特定テーブルのANALYZE
ANALYZE fact_lesson_completions;

-- 全テーブル（注意: 時間がかかる）
VACUUM;
ANALYZE;
```

## 5. コスト監視（Serverless）

### RPU使用量の確認

```sql
-- 日別のRPU使用量
SELECT
    trunc(start_time) as date,
    SUM(compute_seconds) as total_compute_seconds,
    SUM(compute_seconds) / 3600.0 as compute_hours
FROM sys_serverless_usage
GROUP BY trunc(start_time)
ORDER BY date DESC
LIMIT 30;
```

### コスト推定

```
RPU時間コスト（東京）: $0.494/RPU時間

例: 1日100 RPU時間使用
    100 × $0.494 = $49.4/日
```

## 6. ダッシュボード例

### 日次レポートクエリ

```sql
-- 日次サマリー
SELECT
    'クエリ数' as metric,
    COUNT(*) as value
FROM stl_query
WHERE starttime >= CURRENT_DATE
UNION ALL
SELECT
    '平均実行時間(秒)',
    AVG(DATEDIFF(seconds, starttime, endtime))
FROM stl_query
WHERE starttime >= CURRENT_DATE
  AND userid > 1
UNION ALL
SELECT
    'エラークエリ数',
    COUNT(*)
FROM stl_query
WHERE starttime >= CURRENT_DATE
  AND aborted = 1;
```

### 接続状況の確認

```sql
-- 現在の接続数
SELECT
    COUNT(*) as total_connections,
    COUNT(CASE WHEN query > 0 THEN 1 END) as active_connections
FROM stv_sessions;
```

## 7. トラブルシューティング

### よくある問題と対処

| 問題 | 確認方法 | 対処 |
|------|----------|------|
| クエリが遅い | EXPLAIN + STL_QUERY | インデックス見直し, VACUUM |
| ディスクフル | svv_table_info | 不要データ削除, リサイズ |
| 接続できない | CloudWatch | セキュリティグループ確認 |
| コスト高騰 | sys_serverless_usage | クエリ最適化, ベースRPU見直し |

### ロック確認

```sql
-- ロック待ちの確認
SELECT
    l.query,
    l.table_id,
    l.mode,
    t.name as table_name
FROM stv_locks l
JOIN stv_tbl_perm t ON l.table_id = t.id;
```

### デッドロック確認

```sql
-- ブロックしているクエリ
SELECT
    blocked.query as blocked_query,
    blocking.query as blocking_query,
    blocked.starttime
FROM stv_recents blocked
JOIN stv_recents blocking
  ON blocked.pid != blocking.pid
WHERE blocked.status = 'Waiting';
```

## ベストプラクティス

### 監視チェックリスト

```
□ CloudWatchアラーム設定（CPU, ディスク, 接続数）
□ 日次でクエリパフォーマンス確認
□ 週次でVACUUM/ANALYZEの必要性確認
□ 月次でコスト分析
□ 遅いクエリの定期的なチューニング
```

### 運用スケジュール例

```
毎日:
  - CloudWatchダッシュボード確認
  - 遅いクエリのレビュー

毎週:
  - VACUUM/ANALYZEの実行判断
  - ストレージ使用量確認

毎月:
  - コスト分析
  - パフォーマンストレンド確認
  - 不要オブジェクトの棚卸し
```

## まとめ

| 観点 | ツール | 頻度 |
|------|--------|------|
| パフォーマンス | システムテーブル, CloudWatch | 毎日 |
| ストレージ | svv_table_info | 毎週 |
| コスト | sys_serverless_usage | 毎月 |
| メンテナンス | VACUUM, ANALYZE | 必要時 |
