# バックアップ・復元機能

## バックアップスクリプト

### 基本的な使い方

```bash
# バックアップ作成
./backup-restore.sh --backup

# バックアップ一覧表示
./backup-restore.sh --list

# 最新バックアップから復元
./backup-restore.sh --restore

# 特定のバックアップから復元
./backup-restore.sh --restore backup-filename.json

# 古いバックアップを削除
./backup-restore.sh --cleanup
```

### 自動バックアップ

設定ファイルを編集する前に自動でバックアップを作成：

```bash
# 設定編集時の自動バックアップ
./start-projects.sh --config
# → 編集前にバックアップを自動作成
```

## バックアップファイル形式

### ファイル名規則

```
backups/projects-YYYYMMDD-HHMMSS.json
```

例：
- `projects-20241207-143025.json`
- `projects-20241207-090000.json`

### メタデータ

各バックアップには以下の情報が含まれます：

```json
{
  "backup_info": {
    "timestamp": "2024-12-07T14:30:25+09:00",
    "original_path": "/path/to/projects.json",
    "backup_version": "1.0",
    "project_count": 5,
    "enabled_count": 4
  },
  "projects": [...],
  "settings": {...}
}
```

## 使用例

### 定期バックアップ

```bash
# 毎日のバックアップ（crontab例）
0 9 * * * cd /path/to/tmux-project-manager && ./backup-restore.sh --backup

# 週単位での古いバックアップ削除
0 0 * * 0 cd /path/to/tmux-project-manager && ./backup-restore.sh --cleanup
```

### 設定変更前のバックアップ

```bash
# 大幅な設定変更前
./backup-restore.sh --backup

# 設定を変更
./start-projects.sh --config

# 問題がある場合は復元
./backup-restore.sh --restore
```

### 復元手順

1. **バックアップ一覧確認**
   ```bash
   ./backup-restore.sh --list
   ```

2. **復元実行**
   ```bash
   # 最新から復元
   ./backup-restore.sh --restore
   
   # 特定のバックアップから復元
   ./backup-restore.sh --restore projects-20241207-143025.json
   ```

3. **設定確認**
   ```bash
   ./start-projects.sh --list
   ```

## 手動バックアップ

### 個別ファイルのバックアップ

```bash
# 手動でバックアップ作成
cp projects.json projects-backup-$(date +%Y%m%d).json

# 特定の場所にバックアップ
cp projects.json ~/backups/tmux-projects-$(date +%Y%m%d).json
```

### 設定の比較

```bash
# 現在の設定とバックアップの比較
diff projects.json backups/projects-20241207-143025.json
```

## 復元のベストプラクティス

### 復元前の確認

1. **現在の設定をバックアップ**
   ```bash
   ./backup-restore.sh --backup
   ```

2. **復元対象の確認**
   ```bash
   ./backup-restore.sh --list
   ```

3. **復元実行**
   ```bash
   ./backup-restore.sh --restore target-backup.json
   ```

### 復元後の確認

```bash
# 設定内容の確認
./start-projects.sh --list

# 構文チェック
jq . projects.json

# ドライラン実行
./start-projects.sh --dry-run
```

## 自動化設定

### cronでの自動バックアップ

```bash
# crontab -e で追加
# 毎日午前9時にバックアップ
0 9 * * * cd /path/to/tmux-project-manager && ./backup-restore.sh --backup >/dev/null 2>&1

# 毎週日曜日に古いバックアップを削除（30日以上）
0 0 * * 0 cd /path/to/tmux-project-manager && ./backup-restore.sh --cleanup --days 30 >/dev/null 2>&1
```

### スクリプトでの自動化

```bash
#!/bin/bash
# backup-projects.sh

cd /path/to/tmux-project-manager

# バックアップ作成
./backup-restore.sh --backup

# 古いバックアップを削除（7日以上）
./backup-restore.sh --cleanup --days 7

echo "バックアップ完了: $(date)"
```

## トラブルシューティング

### 復元に失敗する場合

```bash
# バックアップファイルの構文チェック
jq . backups/target-backup.json

# 手動復元
cp backups/target-backup.json projects.json

# 設定の修正
./start-projects.sh --config
```

### バックアップが作成されない場合

```bash
# backupsディレクトリが存在するか確認
ls -la backups/

# 手動でディレクトリ作成
mkdir -p backups

# 権限確認
ls -la backups/
```