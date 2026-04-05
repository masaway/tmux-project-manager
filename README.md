# tmux Project Manager

指定したディレクトリ配下のプロジェクトをtmuxセッションで一括管理するBashスクリプトツールです。

## 概要

### ディレクトリ構成例
```
~/projects/                    # スキャン対象ディレクトリ
├── web-app/                   # Next.js プロジェクト
│   ├── package.json
│   └── next.config.js
├── mobile-app/                # React Native プロジェクト
│   ├── package.json
│   └── app.json
├── api-server/                # Python プロジェクト
│   └── requirements.txt
└── config-manager/            # 設定管理プロジェクト
    └── .tmux.conf
```

### 一括起動の流れ

```
./start-projects.sh
         ↓
┌─────────────────────────────────────────────────────────────┐
│                    tmux セッション群                          │
├─────────────────┬─────────────────┬─────────────────────────┤
│   web-app       │   mobile-app    │      api-server         │
│ ┌─────┬───────┐ │ ┌─────┬───────┐ │ ┌─────────────────────┐ │
│ │メイン│開発用 │ │ │メイン│開発用 │ │ │                     │ │
│ │ペイン│ペイン │ │ │ペイン│ペイン │ │ │      メインペイン    │ │
│ │     │npm run│ │ │     │npm   │ │ │                     │ │
│ │     │dev    │ │ │     │start │ │ │                     │ │
│ ├─────┴───────┤ │ ├─────┴───────┤ │ ├─────────────────────┤ │
│ │             │ │ │             │ │ │                     │ │
│ │  追加ペイン  │ │ │  追加ペイン  │ │ │     追加ペイン      │ │
│ │             │ │ │             │ │ │                     │ │
│ └─────────────┘ │ └─────────────┘ │ └─────────────────────┘ │
└─────────────────┴─────────────────┴─────────────────────────┘
```

**1つのコマンドで**:
- 🚀 全プロジェクトの tmux セッションを自動作成
- 📁 各プロジェクトディレクトリで起動
- ⚡ 開発サーバーコマンドを準備状態で配置
- 🎯 効率的なペインレイアウトで整理


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

# 起動後にセッションへアタッチ/切り替え
./start-projects.sh --attach

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

### 3. 個人設定ファイルの初期化
```bash
# 対話ウィザードで personal.json を生成（推奨）
./start-projects.sh --init
```

ウィザードでは以下を設定できます：
- スキャン対象ディレクトリ
- workディレクトリ / スクリプトディレクトリのセッション作成
- 開発用ペインの分割設定
- 下段ペインでの `claude` 自動起動

完了後そのまま `--scan` でプロジェクトを自動検出するか選択できます。

> 手動で作成する場合: `cp config/default.json config/personal.json`

### 4. プロジェクト設定のカスタマイズ
```bash
# 設定ファイルを編集
./start-projects.sh --config
# または直接編集
vim config/personal.json
```

## tmux内からの利用

tmuxセッションに入った状態でも、バックグラウンドで新しいセッションを起動できます。

```bash
# セッションを作成し、切り替え先を選択するメニューを表示
./start-projects.sh --attach

# 特定プロジェクトを起動して即切り替え
./start-projects.sh --project my-app --attach
```

- **tmux内から実行**: `switch-client` で現在のウィンドウを維持しつつ切り替え
- **tmux外から実行**: 通常の `attach-session`
- `--attach` なしで1セッションのみ作成した場合（tmux外）は自動アタッチ

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

