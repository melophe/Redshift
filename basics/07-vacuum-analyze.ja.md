# VACUUM と ANALYZE

## なぜ VACUUM と ANALYZE が必要？

Redshiftは削除された行の自動クリーンアップや統計情報の更新を自動で行わない。

```
【問題】
DELETE/UPDATE → 行は「削除済み」マークだけ、ディスクに残る
INSERT → 新しい行がソートされていない可能性

→ 無駄なスペース + クエリが遅くなる
```

## VACUUM

### VACUUM がやること

1. **削除された行のディスク領域を回収**
2. **ソートキーに従ってデータを再ソート**

```
VACUUM前:
┌────────────────────────────────────┐
│ Row1  [DEL]  Row3  Row2  [DEL]    │  ← 削除行 + 未ソート
└────────────────────────────────────┘

VACUUM後:
┌────────────────────────────────────┐
│ Row1  Row2  Row3                  │  ← クリーン & ソート済み
└────────────────────────────────────┘
```

### VACUUM の種類

```sql
-- フルバキューム（領域回収 + 再ソート）
VACUUM FULL table_name;

-- 領域回収のみ（高速）
VACUUM DELETE ONLY table_name;

-- 再ソートのみ（高速）
VACUUM SORT ONLY table_name;

-- インターリーブソートキーの再インデックス
VACUUM REINDEX table_name;
```

| 種類 | 領域回収 | 再ソート | 使用場面 |
|------|---------|---------|----------|
| FULL | ✅ | ✅ | 大量DELETE + INSERT後 |
| DELETE ONLY | ✅ | ❌ | 多くのDELETE後 |
| SORT ONLY | ❌ | ✅ | 多くのINSERT後 |
| REINDEX | ❌ | ✅ | インターリーブソートキーのメンテナンス |

### VACUUM しきい値

```sql
-- 未ソート行が5%を超えたらVACUUM（デフォルト）
VACUUM FULL table_name TO 95 PERCENT;

-- テーブル全体をVACUUM
VACUUM FULL table_name TO 100 PERCENT;
```

### 自動 VACUUM

Redshiftはクラスタがアイドル時にバックグラウンドで自動VACUUMを実行。

```sql
-- 自動VACUUMの状態を確認
SELECT * FROM svv_vacuum_progress;
SELECT * FROM svv_vacuum_summary;
```

## ANALYZE

### ANALYZE がやること

クエリプランナーが使う**テーブル統計情報**を更新。

```
クエリプランナー: "WHERE status = 'active' に何行マッチする？"

統計なし: "わからない...フルスキャンしよう"
統計あり: "約1000行だな、インデックススキャンを使おう"
```

### ANALYZE の実行

```sql
-- 特定テーブルを分析
ANALYZE table_name;

-- 特定カラムを分析
ANALYZE table_name (column1, column2);

-- スキーマ内の全テーブルを分析
ANALYZE;
```

### ANALYZE を実行すべきタイミング

| 状況 | ANALYZE実行？ |
|------|--------------|
| COPY（大量ロード）後 | ✅ はい |
| 多くのINSERT後 | ✅ はい |
| 10%以上に影響するDELETE/UPDATE後 | ✅ はい |
| データ分布が変わった時 | ✅ はい |

### 自動 ANALYZE

RedshiftはCOPYコマンド後に自動でANALYZEを実行。

```sql
-- COPYで自動ANALYZEを無効化
COPY table_name FROM '...'
STATUPDATE OFF;

-- 自動ANALYZEを強制
COPY table_name FROM '...'
STATUPDATE ON;
```

## テーブルの健全性チェック

### 未ソート行の確認

```sql
SELECT "table", unsorted, vacuum_sort_benefit
FROM svv_table_info
WHERE "table" = 'your_table';
```

### 統計情報の古さを確認

```sql
SELECT "table", stats_off
FROM svv_table_info
WHERE "table" = 'your_table';
-- stats_off: 最後のANALYZE以降に変更された行の割合
```

### 削除行の確認

```sql
SELECT "table", tbl_rows, empty AS deleted_rows
FROM svv_table_info
WHERE "table" = 'your_table';
```

## ベストプラクティス

1. **自動 VACUUM/ANALYZE に任せる** - 通常はこれで十分
2. **大規模バッチ処理後は手動 VACUUM** - 大量DELETE や一括INSERT後
3. **オフピーク時に VACUUM** - クラスタリソースを使用する
4. **データ分布変更後は ANALYZE** - クエリプランナーを助ける
5. **svv_table_info で監視** - unsorted % と stats_off をチェック

## メンテナンスワークフロー例

```sql
-- 夜間ETLジョブ後
VACUUM FULL sales;
ANALYZE sales;

-- 状態確認
SELECT "table", unsorted, stats_off, vacuum_sort_benefit
FROM svv_table_info
WHERE "table" = 'sales';
```
