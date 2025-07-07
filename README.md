# tmux Project Manager

workディレクトリ配下のプロジェクトをtmuxセッションで一括管理するBashスクリプトツールです。

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

## 依存関係

- `tmux` - セッション管理
- `jq` - JSON解析

```bash
# Ubuntu/Debian
sudo apt install tmux jq

# macOS
brew install tmux jq
```

## 詳細ドキュメント

- [設定ファイル](docs/configuration.md) - projects.jsonの設定方法
- [プロジェクトタイプ](docs/project-types.md) - 自動判定される項目と設定
- [レイアウト](docs/layouts.md) - tmuxペインレイアウトの詳細
- [トラブルシューティング](docs/troubleshooting.md) - よくある問題と解決方法
- [セッション管理](docs/session-management.md) - セッションの管理方法
- [バックアップ・復元](docs/backup-restore.md) - 設定のバックアップ機能