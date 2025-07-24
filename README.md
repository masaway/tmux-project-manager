# tmux Project Manager

指定したディレクトリ配下のプロジェクトをtmuxセッションで一括管理するBashスクリプトツールです。

## 主なメリット

- **一括起動**: workディレクトリ配下のプロジェクトを一度に起動
- **プロジェクト自動検出**: 新しいプロジェクトディレクトリを自動で検出・設定
- **効率的なレイアウト**: 開発用ペインでコマンドを準備状態で起動
- **柔軟な設定**: JSON設定ファイルで個別プロジェクトの設定をカスタマイズ
- **型判定**: プロジェクトの種類を自動判定して適切なコマンドを設定

## 基本的な使い方

```bash
# 全プロジェクトを起動
./start-projects.sh

# 新規プロジェクトを自動検出
./start-projects.sh --scan

# プロジェクト一覧を表示
./start-projects.sh --list

# 特定のプロジェクトのみ起動
./start-projects.sh --project project-name

# 設定ファイルを編集
./start-projects.sh --config

# 実行せずに確認
./start-projects.sh --dry-run
```

## 初回セットアップ

### 1. リポジトリのクローン
```bash
git clone https://github.com/masaway/tmux-project-manager.git
cd tmux-project-manager
```

### 2. 依存関係のインストール
- `tmux` - セッション管理
- `jq` - JSON解析

```bash
# Ubuntu/Debian
sudo apt install tmux jq

# macOS
brew install tmux jq
```

### 3. 個人設定ファイルの作成
```bash
# personal.json を作成（個人のプロジェクト設定用）
cp config/default.json config/personal.json
```

### 4. プロジェクト設定のカスタマイズ
```bash
# 設定ファイルを編集
./start-projects.sh --config
# または直接編集
vim config/personal.json
```

## 設定ファイルについて

このツールは2つの設定ファイルを使用します：

- **`config/default.json`** - デフォルト設定（パブリック、空のプロジェクト配列）
- **`config/personal.json`** - 個人設定（あなた専用、`.gitignore`対象）

### 設定読み込み優先順位
1. `config/personal.json` が存在する場合 → 個人設定を使用
2. 存在しない場合 → `config/default.json` を使用

### スキャン対象ディレクトリの設定

デフォルトでは、スクリプトの親ディレクトリをスキャンしますが、任意のディレクトリを指定可能です：

```json
{
  "projects": [...],
  "settings": {
    "scan_directory": "/home/username/projects",
    "default_layout": "even-vertical",
    ...
  }
}
```

### プロジェクト追加方法
```bash
# 自動検出でプロジェクトを追加
./start-projects.sh --scan

# 手動で config/personal.json を編集
{
  "projects": [
    {
      "name": "my-project",
      "path": "/path/to/your/project",
      "enabled": true,
      "description": "プロジェクトの説明",
      "type": "nextjs",
      "commands": {
        "startup": "pwd && ls -la",
        "dev": "npm run dev"
      }
    }
  ],
  "settings": {
    "scan_directory": "/home/username/projects",
    ...
  }
}
```

