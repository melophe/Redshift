# 圧縮エンコーディング

## 圧縮エンコーディングとは？

圧縮エンコーディングは**各カラムのデータをどう圧縮するか**を決定する。

適切な圧縮でストレージ削減とクエリ性能向上が可能。

```
圧縮なし:
┌──────────────────────────────────┐
│ Tokyo Tokyo Tokyo Tokyo Tokyo    │  100 bytes
└──────────────────────────────────┘

圧縮あり (RLE):
┌──────────────────────────────────┐
│ Tokyo x 5                        │  10 bytes
└──────────────────────────────────┘
```

## なぜカラムナストレージは圧縮効率が良いか

```
行指向: 異なる型が混在 → 圧縮効率悪い
┌────┬───────┬─────┬────────┐
│ 1  │ Tokyo │ 25  │ 50000  │  データ型が混在
└────┴───────┴─────┴────────┘

列指向: 同じ型が連続 → 圧縮効率良い
┌───────┬───────┬───────┬───────┐
│ Tokyo │ Tokyo │ Osaka │ Tokyo │  同じ型 = 圧縮しやすい
└───────┴───────┴───────┴───────┘
```

## エンコーディングの種類

### 1. RAW（圧縮なし）

圧縮を適用しない。

```sql
column_name VARCHAR(100) ENCODE RAW
```

**使用場面:** 圧縮効果が薄いデータ（ランダムデータ、既に圧縮済み）

### 2. AZ64

Amazon独自のアルゴリズム。数値・日付型に最適。

```sql
column_name BIGINT ENCODE AZ64
```

**使用場面:** 数値、日付、タイムスタンプ - **これらの型の推奨デフォルト**

### 3. LZO

汎用的な圧縮。

```sql
column_name VARCHAR(500) ENCODE LZO
```

**使用場面:** 長い文字列、様々なテキストデータ

### 4. ZSTD

高い圧縮率と良好なパフォーマンス。

```sql
column_name VARCHAR(1000) ENCODE ZSTD
```

**使用場面:** 大きなテキストカラム - **VARCHARに推奨**

### 5. BYTEDICT

辞書ベースの圧縮。カーディナリティが低い場合に有効。

```sql
column_name VARCHAR(50) ENCODE BYTEDICT
```

**使用場面:** ユニーク値が少ない（国コード、ステータスフラグ）

### 6. RUNLENGTH (RLE)

連続する同じ値を「値 x 回数」で保存。

```sql
column_name VARCHAR(50) ENCODE RUNLENGTH
```

**使用場面:** 連続して繰り返す値が多い（ソート済みカラム）

### 7. DELTA / DELTA32K

前の値との差分を保存。

```sql
column_name INT ENCODE DELTA
```

**使用場面:** 連番または連番に近い数値（ID、タイムスタンプ）

### 8. MOSTLY8 / MOSTLY16 / MOSTLY32

大半の値が小さいサイズに収まる場合に圧縮。

```sql
column_name BIGINT ENCODE MOSTLY16
```

**使用場面:** BIGINTだが大半の値が小さい場合

## エンコーディング推奨

| データ型 | 推奨エンコーディング |
|----------|---------------------|
| INT, BIGINT | AZ64 |
| DATE, TIMESTAMP | AZ64 |
| DECIMAL | AZ64 |
| BOOLEAN | RAW または ZSTD |
| VARCHAR（短い、低カーディナリティ） | BYTEDICT |
| VARCHAR（長いテキスト） | ZSTD または LZO |
| CHAR | BYTEDICT または LZO |
| ソート済みで繰り返しが多いカラム | RUNLENGTH |

## 自動圧縮推奨 (ANALYZE COMPRESSION)

Redshiftに最適なエンコーディングを推奨させる:

```sql
ANALYZE COMPRESSION table_name;
```

出力:
```
Column     | Encoding | Est. Reduction
-----------+----------+---------------
user_id    | AZ64     | 75%
name       | ZSTD     | 60%
status     | BYTEDICT | 90%
```

## 圧縮の設定方法

### テーブル作成時

```sql
CREATE TABLE users (
    user_id     BIGINT       ENCODE AZ64,
    name        VARCHAR(100) ENCODE ZSTD,
    status      VARCHAR(20)  ENCODE BYTEDICT,
    created_at  TIMESTAMP    ENCODE AZ64
);
```

### COPYで自動圧縮

```sql
COPY table_name
FROM 's3://...'
COMPUPDATE ON;  -- 自動的に圧縮を適用
```

### 圧縮の変更（テーブル再構築が必要）

```sql
-- 新しいエンコーディングでテーブル作成
CREATE TABLE users_new (...) ENCODE ...;

-- データをコピー
INSERT INTO users_new SELECT * FROM users;

-- テーブルを入れ替え
DROP TABLE users;
ALTER TABLE users_new RENAME TO users;
```

## 現在の圧縮設定を確認

```sql
SELECT "column", "encoding"
FROM pg_table_def
WHERE tablename = 'your_table';
```

## ベストプラクティス

1. **ANALYZE COMPRESSION を使う** - サンプルデータで推奨を取得
2. **COPYで自動圧縮** - 新しいテーブルには `COMPUPDATE ON`
3. **数値/日付には AZ64** - Amazon最適化アルゴリズム
4. **テキストには ZSTD** - 圧縮率と速度のバランスが良い
5. **低カーディナリティには BYTEDICT** - ステータス、国コード等
