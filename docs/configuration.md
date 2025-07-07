# 設定ファイル (projects.json)

## プロジェクト設定

各プロジェクトは以下の形式で設定します：

```json
{
  "name": "プロジェクト名",
  "path": "/絶対パス/to/project",
  "enabled": true,
  "description": "プロジェクトの説明",
  "type": "プロジェクトタイプ",
  "commands": {
    "startup": "起動時に実行するコマンド",
    "dev": "開発用コマンド（オプション）"
  }
}
```

## 設定項目説明

- **name**: tmuxセッション名として使用
- **path**: プロジェクトのルートディレクトリ
- **enabled**: `true`で起動対象、`false`で無効
- **description**: プロジェクトの説明文
- **type**: プロジェクトタイプ（表示用）
- **commands.startup**: セッション作成時に実行するコマンド
- **commands.dev**: 開発用ペインで実行するコマンド（`null`で無効）

## グローバル設定

```json
{
  "settings": {
    "default_layout": "even-vertical",
    "auto_attach": false,
    "kill_existing": false,
    "create_dev_pane": true,
    "dev_pane_size": "30%"
  }
}
```

- **default_layout**: デフォルトのtmuxレイアウト（開発ペインがない場合）
- **auto_attach**: 起動後に自動でセッションにアタッチ（無効推奨）
- **kill_existing**: 既存セッションを自動削除
- **create_dev_pane**: 開発用ペインを作成
- **dev_pane_size**: 開発用ペインのサイズ（上部左右分割の比率）

## 設定例

```json
{
  "projects": [
    {
      "name": "my-web-app",
      "path": "/home/user/work/my-web-app",
      "enabled": true,
      "description": "React + Node.js Webアプリケーション",
      "type": "nextjs",
      "commands": {
        "startup": "pwd && ls -la",
        "dev": "npm run dev"
      }
    },
    {
      "name": "config-manager",
      "path": "/home/user/work/config-manager",
      "enabled": true,
      "description": "設定ファイル管理",
      "type": "config",
      "commands": {
        "startup": "ls -la",
        "dev": null
      }
    }
  ],
  "settings": {
    "default_layout": "even-vertical",
    "auto_attach": false,
    "kill_existing": false,
    "create_dev_pane": true,
    "dev_pane_size": "30%"
  }
}
```

## 設定の編集

```bash
# 設定ファイルを開く
./start-projects.sh --config

# 設定の構文をチェック
jq . projects.json
```