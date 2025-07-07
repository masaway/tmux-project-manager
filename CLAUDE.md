# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language Preferences
- 常に日本語で

## プロジェクト概要

このリポジトリは、workディレクトリ配下のプロジェクトをtmuxセッションで一括管理するためのBashスクリプトツールです。複数のプロジェクトを効率的に起動・管理できます。

## 技術構成

- **メイン言語**: Bash Shell Script
- **設定ファイル**: JSON
- **必要な依存関係**: tmux, jq
- **対象プラットフォーム**: Linux, macOS

## 主要ファイル

- `start-projects.sh` - メインスクリプト（470行）
- `projects.json` - プロジェクト設定とグローバル設定
- `README.md` - 詳細なドキュメント

## 主要コマンド

```bash
# プロジェクト起動
./start-projects.sh

# 新規プロジェクト検出とスキャン
./start-projects.sh --scan

# プロジェクト一覧表示
./start-projects.sh --list

# 設定ファイル編集
./start-projects.sh --config

# 特定プロジェクトのみ起動
./start-projects.sh --project <project-name>

# 既存セッション削除後起動
./start-projects.sh --kill

# ドライラン（実行せずに確認）
./start-projects.sh --dry-run
```

## アーキテクチャ

### プロジェクト管理の仕組み
1. `projects.json`で各プロジェクトの設定を管理
2. プロジェクトタイプの自動判定（nextjs, react-native, python, etc.）
3. tmuxセッションの自動作成とレイアウト設定
4. 起動コマンドと開発コマンドの分離実行

### 設定ファイル構造
- `projects[]` - 各プロジェクトの個別設定
- `settings` - グローバル設定（レイアウト、自動アタッチ等）

### プロジェクトタイプ判定
ファイルパターンに基づく自動判定：
- package.json + next.config.* → nextjs
- package.json + app.json → react-native
- requirements.txt → python
- Cargo.toml → rust
- その他多数のパターン

## 開発ガイドライン

### シェルスクリプト開発
- `set -e`でエラー時の即座終了
- 色付きコンソール出力の活用
- jqを使用したJSON操作
- 適切なエラーハンドリング

### JSON設定の管理
- プロジェクト設定の整合性維持
- グローバル設定の適切な活用
- 新規プロジェクトの自動検出・追加機能

### コードスタイル
- 日本語コメントの使用
- 関数の適切な分割
- 引数検証と存在チェック

## 拡張可能な機能

- 新しいプロジェクトタイプの追加
- カスタムコマンドの設定
- レイアウトオプションの追加
- 自動スキャン機能の改良