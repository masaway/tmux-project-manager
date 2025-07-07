# プロジェクトタイプ

`--scan`オプションを使用することで、プロジェクトディレクトリの構成を自動判定します。

## 自動判定ルール

以下のファイルの存在に基づいて自動判定されます：

### Web開発系
- `package.json` + `next.config.*` → **nextjs**
- `package.json` + `app.json` → **react-native**
- `package.json` のみ → **nodejs**

### サーバーサイド
- `requirements.txt`, `setup.py`, `pyproject.toml` → **python**
- `Cargo.toml` → **rust**
- `go.mod` → **go**

### その他
- `Makefile` → **make**
- `.tmux.conf` → **config**
- `企画書.md` + 複数の.mdファイル → **planning**
- `*.sh`, `*.bash` → **shell**
- `test.sh`, `tst.sh` → **test**
- 該当なし → **unknown**

## デフォルト開発コマンド

プロジェクトタイプに応じて、以下の開発コマンドが自動設定されます：

- **nextjs**: `npm run dev`
- **react-native**: `npm start`
- **nodejs**: `npm start`
- **python**: `python main.py`
- **shell**: `./メインスクリプト.sh`
- **その他**: `null`（開発ペインなし）

## 使用例

```bash
# 新しいプロジェクトを追加
mkdir /path/to/work/my-nextjs-app
echo '{"name": "my-app"}' > /path/to/work/my-nextjs-app/package.json
touch /path/to/work/my-nextjs-app/next.config.js

# 自動検出・設定
./start-projects.sh --scan
# → my-nextjs-app (nextjs) として自動検出
# → 開発コマンド: npm run dev
```

## カスタマイズ

自動検出後、必要に応じて設定を手動で調整できます：

```bash
# 設定ファイルを編集
./start-projects.sh --config
```

例：開発コマンドを変更
```json
{
  "name": "my-project",
  "type": "nextjs",
  "commands": {
    "dev": "npm run dev -- --port 3001"
  }
}
```