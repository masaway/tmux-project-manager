# セッション管理

## 補助スクリプトでの管理（推奨）

### セッション管理機能

```bash
# セッション状態確認
./session-manager.sh --status

# セッションにアタッチ（選択メニュー）
./session-manager.sh --attach

# 特定セッションにアタッチ
./session-manager.sh --attach project-name

# セッション削除
./session-manager.sh --kill

# セッション再起動
./session-manager.sh --restart

# リアルタイム監視
./session-manager.sh --watch
```

### 基本的な使い方

1. **セッションの起動**
   ```bash
   ./start-projects.sh
   ```

2. **セッションの確認**
   ```bash
   ./session-manager.sh --status
   ```

3. **セッションにアタッチ**
   ```bash
   ./session-manager.sh --attach
   # 選択メニューから選択
   ```

4. **セッションから抜ける**
   ```
   Ctrl+B → D
   ```

## 標準tmuxコマンド

### 基本操作

```bash
# セッション一覧
tmux list-sessions

# セッションにアタッチ
tmux attach-session -t プロジェクト名

# セッションを削除
tmux kill-session -t プロジェクト名

# 全セッションを削除
tmux kill-server
```

### セッション内操作

#### 基本キーバインド

- **Ctrl+B**: プレフィックスキー
- **Ctrl+B → D**: セッションからデタッチ
- **Ctrl+B → ?**: ヘルプ表示

#### ペイン操作

- **Ctrl+B → O**: 次のペインに移動
- **Ctrl+B → ;**: 前のペインに戻る
- **Ctrl+B → 矢印キー**: ペイン間移動
- **Ctrl+B → X**: ペインを削除
- **Ctrl+B → Z**: ペインを全画面表示

#### ウィンドウ操作

- **Ctrl+B → C**: 新しいウィンドウ作成
- **Ctrl+B → N**: 次のウィンドウ
- **Ctrl+B → P**: 前のウィンドウ
- **Ctrl+B → 数字**: 指定番号のウィンドウに移動

## セッションの管理戦略

### 日常的な使用方法

1. **朝の作業開始**
   ```bash
   ./start-projects.sh
   ./session-manager.sh --status
   ```

2. **プロジェクト間の切り替え**
   ```bash
   ./session-manager.sh --attach
   ```

3. **夜の作業終了**
   ```bash
   # セッションを残したまま終了（推奨）
   # または全削除
   ./session-manager.sh --kill
   ```

### プロジェクト追加時

```bash
# 新しいプロジェクトを検出
./start-projects.sh --scan

# 新しいプロジェクトのみ起動
./start-projects.sh --project new-project
```

### 設定変更時

```bash
# 設定を変更
./start-projects.sh --config

# 変更の影響を確認
./start-projects.sh --dry-run

# 既存セッションを削除して再起動
./start-projects.sh --kill
```

## 効率的な使用方法

### エイリアスの設定

```bash
# ~/.bashrc または ~/.zshrc に追加
alias tpm='cd /path/to/tmux-project-manager'
alias tpms='./start-projects.sh'
alias tpma='./session-manager.sh --attach'
alias tpml='./start-projects.sh --list'
alias tpmc='./start-projects.sh --config'
```

### 起動時の自動実行

```bash
# ~/.bashrc に追加
if command -v tmux &> /dev/null; then
    cd /path/to/tmux-project-manager
    ./start-projects.sh --dry-run > /dev/null 2>&1
fi
```

## トラブルシューティング

### セッションが応答しない

```bash
# セッションを強制終了
tmux kill-session -t stuck-session

# tmuxサーバーを再起動
tmux kill-server
```

### ペインの配置が崩れる

```bash
# レイアウトを修正
tmux select-layout -t session-name even-vertical

# 手動でペインを整理
# Ctrl+B → Space（レイアウト循環）
```