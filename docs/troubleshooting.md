# トラブルシューティング

## よくある問題と解決方法

### セッションが既に存在する

**エラー**: `duplicate session: project-name`

**解決方法**:
```bash
# 既存セッションを削除してから起動
./start-projects.sh --kill

# または個別に削除
tmux kill-session -t project-name
```

### パスが見つからない

**エラー**: `ディレクトリが存在しません: /path/to/project`

**解決方法**:
1. プロジェクトディレクトリが存在するか確認
2. `projects.json`のパス設定を確認
3. 削除されたプロジェクトをスキャンで除去

```bash
# 削除されたプロジェクトを検出
./start-projects.sh --scan
```

### コマンドが実行されない

**症状**: 起動コマンドや開発コマンドが実行されない

**確認事項**:
- コマンドの構文が正しいか
- 実行権限があるか
- パスが正しいか

```bash
# 実行予定のコマンドを確認
./start-projects.sh --dry-run
```

### 設定ファイルの構文エラー

**エラー**: `parse error: Invalid JSON`

**解決方法**:
```bash
# JSONの構文をチェック
jq . projects.json

# エラーの詳細を確認
jq -r . projects.json
```

**よくある構文エラー**:
- 最後の項目にカンマがある
- 文字列がダブルクォートで囲まれていない
- 波括弧やコンマが不足

### ペイン分割の問題

**症状**: ペインが期待通りに分割されない

**原因と解決**:
1. **ターミナルのサイズが小さい**
   - ターミナルウィンドウを大きくする
   - 最小80x24文字のサイズを確保

2. **tmuxのバージョンが古い**
   - tmuxを最新版に更新

3. **サイズ設定の問題**
   ```json
   {
     "settings": {
       "dev_pane_size": "30%"  // %記号を含める
     }
   }
   ```

### 開発コマンドが自動実行される

**症状**: 開発コマンドが即座に実行される

**説明**: 現在の仕様では、開発コマンドは準備状態で表示されます。Enterキーを押すと実行されます。

### jqコマンドが見つからない

**エラー**: `jq: command not found`

**解決方法**:
```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq

# 他のLinux
# パッケージマネージャーでjqをインストール
```

### tmuxセッションが見つからない

**エラー**: `no sessions`

**確認事項**:
```bash
# セッション一覧を確認
tmux list-sessions

# セッションを作成
./start-projects.sh

# 特定のプロジェクトを起動
./start-projects.sh --project project-name
```

## エラーハンドリング

### ログの確認

スクリプトは以下の形式でメッセージを出力します：

- **緑色**: 正常な処理
- **黄色**: 警告メッセージ
- **赤色**: エラーメッセージ

### デバッグ方法

```bash
# ドライランで実行予定を確認
./start-projects.sh --dry-run

# 詳細なセッション情報を確認
./start-projects.sh --list

# tmuxの状態を確認
tmux info
```

## 設定の復旧

### バックアップから復元

```bash
# バックアップスクリプトを使用
./backup-restore.sh --restore

# 手動でバックアップから復元
cp backups/projects-YYYYMMDD-HHMMSS.json projects.json
```

### 設定の初期化

```bash
# 設定ファイルを削除
rm projects.json

# 再スキャンで設定を再作成
./start-projects.sh --scan
```