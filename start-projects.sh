#!/bin/bash

# workディレクトリのプロジェクトをtmuxセッションで起動するスクリプト
# 使用方法: ./start-projects.sh [オプション]

set -e

# 設定ファイルのパス
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
DEFAULT_CONFIG="${CONFIG_DIR}/default.json"
PERSONAL_CONFIG="${CONFIG_DIR}/personal.json"

# 個人設定が存在すれば優先、なければデフォルト使用
if [[ -f "$PERSONAL_CONFIG" ]]; then
    CONFIG_FILE="$PERSONAL_CONFIG"
else
    CONFIG_FILE="$DEFAULT_CONFIG"
fi

WORK_DIR="$(dirname "$SCRIPT_DIR")"

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ヘルプメッセージ
show_help() {
    echo "プロジェクトtmuxセッション起動スクリプト"
    echo ""
    echo "使用方法:"
    echo "  $0 [オプション]"
    echo ""
    echo "オプション:"
    echo "  -h, --help      このヘルプを表示"
    echo "  -l, --list      プロジェクト一覧を表示"
    echo "  -c, --config    設定ファイルを編集"
    echo "  -s, --scan      workディレクトリを調査し、新規/削除されたプロジェクトを検出"
    echo "  -k, --kill      既存セッションを削除してから起動"
    echo "  -d, --dry-run   実行せずに実行予定のコマンドを表示"
    echo "  -p, --project   特定のプロジェクトのみ起動 (例: -p tmux-config)"
    echo ""
    echo "設定ファイル: ${CONFIG_FILE}"
}

# jqの存在確認
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}エラー: jqがインストールされていません${NC}"
        echo "Ubuntu/Debian: sudo apt install jq"
        echo "macOS: brew install jq"
        exit 1
    fi
}

# 設定ファイルの存在確認
check_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}エラー: 設定ファイルが見つかりません: $CONFIG_FILE${NC}"
        exit 1
    fi
}

# プロジェクト一覧表示
list_projects() {
    echo -e "${BLUE}=== プロジェクト一覧 ===${NC}"
    echo ""
    
    local enabled_count=0
    local disabled_count=0
    
    # プロジェクト配列を取得して配列に格納
    local projects_array=()
    while IFS= read -r line; do
        projects_array+=("$line")
    done < <(jq -c '.projects[]' "$CONFIG_FILE")
    
    for project in "${projects_array[@]}"; do
        local name=$(echo "$project" | jq -r '.name')
        local enabled=$(echo "$project" | jq -r '.enabled')
        local description=$(echo "$project" | jq -r '.description')
        local type=$(echo "$project" | jq -r '.type')
        local path=$(echo "$project" | jq -r '.path')
        
        if [[ "$enabled" == "true" ]]; then
            echo -e "${GREEN}✓${NC} ${name} (${type})"
            echo -e "  ${description}"
            echo -e "  パス: ${path}"
            enabled_count=$((enabled_count + 1))
        else
            echo -e "${YELLOW}✗${NC} ${name} (${type}) - 無効"
            echo -e "  ${description}"
            echo -e "  パス: ${path}"
            disabled_count=$((disabled_count + 1))
        fi
        echo ""
    done
    
    echo -e "${BLUE}合計: ${enabled_count}個有効, ${disabled_count}個無効${NC}"
}

# プロジェクトタイプを推測
detect_project_type() {
    local project_path="$1"
    
    # ファイルの存在に基づいてプロジェクトタイプを推測
    if [[ -f "$project_path/package.json" ]]; then
        if [[ -f "$project_path/next.config.ts" ]] || [[ -f "$project_path/next.config.js" ]]; then
            echo "nextjs"
        elif [[ -f "$project_path/app.json" ]] || [[ -f "$project_path/expo-env.d.ts" ]]; then
            echo "react-native"
        else
            echo "nodejs"
        fi
    elif [[ -f "$project_path/requirements.txt" ]] || [[ -f "$project_path/setup.py" ]] || [[ -f "$project_path/pyproject.toml" ]]; then
        echo "python"
    elif [[ -f "$project_path/Cargo.toml" ]]; then
        echo "rust"
    elif [[ -f "$project_path/go.mod" ]]; then
        echo "go"
    elif [[ -f "$project_path/Makefile" ]] || [[ -f "$project_path/makefile" ]]; then
        echo "make"
    elif [[ -f "$project_path/.tmux.conf" ]] || [[ -f "$project_path/tmux.conf" ]]; then
        echo "config"
    elif [[ -f "$project_path/企画書.md" ]] || [[ -f "$project_path/README.md" ]] && [[ $(find "$project_path" -name "*.md" | wc -l) -gt 2 ]]; then
        echo "planning"
    elif [[ -f "$project_path/test.sh" ]] || [[ -f "$project_path/tst.sh" ]]; then
        echo "test"
    elif [[ $(find "$project_path" -name "*.sh" -o -name "*.bash" | head -1) ]]; then
        echo "shell"
    else
        echo "unknown"
    fi
}

# ディレクトリスキャン機能
scan_directories() {
    echo -e "${BLUE}=== workディレクトリスキャン ===${NC}"
    echo "設定ファイル: $CONFIG_FILE"
    echo ""
    
    local work_dir="$WORK_DIR"
    local new_projects=()
    local missing_projects=()
    local existing_projects=()
    
    # 現在の設定からプロジェクト一覧を取得
    while IFS= read -r project_name; do
        existing_projects+=("$project_name")
    done < <(jq -r '.projects[].name' "$CONFIG_FILE")
    
    echo -e "${YELLOW}現在の設定済みプロジェクト:${NC} ${#existing_projects[@]}個"
    
    # workディレクトリの実際のディレクトリを調査
    echo -e "${YELLOW}実際のディレクトリを調査中...${NC}"
    
    local actual_dirs=()
    while IFS= read -r dir; do
        local basename=$(basename "$dir")
        # 隠しディレクトリとファイル、tmux-project-managerディレクトリを除外
        if [[ ! "$basename" =~ ^\. && -d "$dir" && "$basename" != "tmux-project-manager" ]]; then
            actual_dirs+=("$basename")
        fi
    done < <(find "$work_dir" -maxdepth 1 -type d | grep -v "^$work_dir$")
    
    echo -e "${YELLOW}実際のディレクトリ:${NC} ${#actual_dirs[@]}個"
    echo ""
    
    # 新規プロジェクトの検出
    echo -e "${GREEN}=== 新規プロジェクト検出 ===${NC}"
    for dir in "${actual_dirs[@]}"; do
        if ! printf '%s\n' "${existing_projects[@]}" | grep -qx "$dir"; then
            new_projects+=("$dir")
            local full_path="$work_dir/$dir"
            local project_type=$(detect_project_type "$full_path")
            echo -e "${GREEN}+ 新規:${NC} $dir (推定タイプ: $project_type)"
            echo -e "  パス: $full_path"
        fi
    done
    
    if [[ ${#new_projects[@]} -eq 0 ]]; then
        echo -e "${YELLOW}新規プロジェクトはありません${NC}"
    fi
    echo ""
    
    # 削除されたプロジェクトの検出
    echo -e "${RED}=== 削除されたプロジェクト検出 ===${NC}"
    for project in "${existing_projects[@]}"; do
        if ! printf '%s\n' "${actual_dirs[@]}" | grep -qx "$project"; then
            missing_projects+=("$project")
            local project_path=$(jq -r ".projects[] | select(.name == \"$project\") | .path" "$CONFIG_FILE")
            echo -e "${RED}- 削除:${NC} $project"
            echo -e "  設定パス: $project_path"
        fi
    done
    
    if [[ ${#missing_projects[@]} -eq 0 ]]; then
        echo -e "${YELLOW}削除されたプロジェクトはありません${NC}"
    fi
    echo ""
    
    # サマリー表示
    echo -e "${BLUE}=== スキャン結果サマリー ===${NC}"
    echo -e "設定済みプロジェクト: ${#existing_projects[@]}個"
    echo -e "実際のディレクトリ: ${#actual_dirs[@]}個"
    echo -e "${GREEN}新規プロジェクト: ${#new_projects[@]}個${NC}"
    echo -e "${RED}削除されたプロジェクト: ${#missing_projects[@]}個${NC}"
    
    # 新規プロジェクトの追加提案
    if [[ ${#new_projects[@]} -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}新規プロジェクトを設定ファイルに追加しますか？ (y/N):${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            add_new_projects "${new_projects[@]}"
        fi
    fi
    
    # 削除されたプロジェクトの削除提案
    if [[ ${#missing_projects[@]} -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}削除されたプロジェクトを設定ファイルから除去しますか？ (y/N):${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            remove_missing_projects "${missing_projects[@]}"
        fi
    fi
}

# 新規プロジェクトをJSONに追加
add_new_projects() {
    local projects=("$@")
    echo -e "${GREEN}新規プロジェクトを追加中...${NC}"
    
    for project in "${projects[@]}"; do
        local full_path="$WORK_DIR/$project"
        local project_type=$(detect_project_type "$full_path")
        local startup_cmd="null"
        local dev_cmd="null"
        
        # プロジェクトタイプに応じた開発コマンドを設定
        case "$project_type" in
            "nextjs")
                dev_cmd="npm run dev"
                ;;
            "react-native")
                dev_cmd="npm start"
                ;;
            "nodejs")
                dev_cmd="npm start"
                ;;
            "python")
                dev_cmd="python main.py"
                ;;
            "shell")
                # .shファイルがあれば実行可能にする
                local shell_file=$(find "$full_path" -name "*.sh" | head -1)
                if [[ -n "$shell_file" ]]; then
                    dev_cmd="./$(basename "$shell_file")"
                fi
                ;;
        esac
        
        # JSONに新しいプロジェクトを追加
        local new_project=$(cat <<EOF
{
  "name": "$project",
  "path": "$full_path",
  "enabled": true,
  "description": "自動検出されたプロジェクト ($project_type)",
  "type": "$project_type",
  "commands": {
    "startup": "$startup_cmd",
    "dev": $([[ "$dev_cmd" == "null" ]] && echo "null" || echo "\"$dev_cmd\"")
  }
}
EOF
)
        
        # jqを使ってJSONに追加
        local tmp_file=$(mktemp)
        jq ".projects += [$new_project]" "$CONFIG_FILE" > "$tmp_file"
        mv "$tmp_file" "$CONFIG_FILE"
        
        echo -e "${GREEN}追加完了:${NC} $project ($project_type)"
    done
}

# 削除されたプロジェクトをJSONから除去
remove_missing_projects() {
    local projects=("$@")
    echo -e "${RED}削除されたプロジェクトを除去中...${NC}"
    
    for project in "${projects[@]}"; do
        local tmp_file=$(mktemp)
        jq "del(.projects[] | select(.name == \"$project\"))" "$CONFIG_FILE" > "$tmp_file"
        mv "$tmp_file" "$CONFIG_FILE"
        
        echo -e "${RED}除去完了:${NC} $project"
    done
}

# セッションが存在するかチェック
session_exists() {
    tmux has-session -t "$1" 2>/dev/null
}

# セッションを作成
create_session() {
    local name="$1"
    local path="$2"
    local startup_cmd="$3"
    local dev_cmd="$4"
    local dry_run="$5"
    
    # パラメータ検証
    if [[ -z "$name" || -z "$path" ]]; then
        echo -e "${RED}エラー: セッション名またはパスが空です${NC}"
        return 1
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        echo -e "${BLUE}[DRY-RUN]${NC} セッション作成: $name"
        echo "  パス: $path"
        echo "  起動コマンド: $startup_cmd"
        if [[ "$dev_cmd" != "null" && -n "$dev_cmd" ]]; then
            echo "  開発コマンド: $dev_cmd"
        fi
        return
    fi
    
    echo -e "${GREEN}セッション作成中:${NC} $name"
    
    # メインペイン作成
    if ! tmux new-session -d -s "$name" -c "$path" 2>/dev/null; then
        echo -e "${RED}エラー: セッション '$name' の作成に失敗しました${NC}"
        return 1
    fi
    
    # セッション作成後の安定化待機
    sleep 0.1
    
    # 起動コマンドを実行
    if [[ -n "$startup_cmd" && "$startup_cmd" != "null" ]]; then
        if ! tmux send-keys -t "$name" "$startup_cmd" Enter 2>/dev/null; then
            echo -e "${YELLOW}警告: 起動コマンド送信に失敗 ($name)${NC}"
        fi
    fi
    
    # 開発コマンドがある場合は新しいペインを作成
    if [[ "$dev_cmd" != "null" && -n "$dev_cmd" ]]; then
        local create_dev_pane=$(jq -r '.settings.create_dev_pane' "$CONFIG_FILE")
        if [[ "$create_dev_pane" == "true" ]]; then
            local dev_pane_size=$(jq -r '.settings.dev_pane_size' "$CONFIG_FILE")
            # %記号を除去し、数値のみ抽出
            local size_num="${dev_pane_size%\%}"
            
            # セッションの存在を再確認
            if ! tmux has-session -t "$name" 2>/dev/null; then
                echo -e "${RED}エラー: セッション '$name' が存在しません${NC}"
                return 1
            fi
            
            # 3分割レイアウト作成：上部を左右分割、下部に1つ
            # 1. 最初に上下分割
            if tmux split-window -t "$name" -v -c "$path" 2>/dev/null; then
                sleep 0.1
                # 2. 上部ペインを左右分割（開発用）
                local split_success=false
                if [[ "$size_num" =~ ^[0-9]+$ ]] && [[ "$size_num" -ge 1 ]] && [[ "$size_num" -le 99 ]]; then
                    if tmux split-window -t "$name:0.0" -h -p "$size_num" -c "$path" 2>/dev/null; then
                        split_success=true
                    fi
                fi
                
                if [[ "$split_success" == "false" ]]; then
                    # サイズ指定失敗時はデフォルト分割
                    if tmux split-window -t "$name:0.0" -h -c "$path" 2>/dev/null; then
                        split_success=true
                    fi
                fi
                
                if [[ "$split_success" == "true" ]]; then
                    sleep 0.1
                    # 開発コマンドを右上ペインで送信（Enterは送信しない）
                    if ! tmux send-keys -t "$name:0.1" "$dev_cmd" 2>/dev/null; then
                        echo -e "${YELLOW}警告: 開発コマンド送信に失敗 ($name)${NC}"
                    fi
                    
                    # 下段ペインでclaudeを自動実行する設定をチェック
                    local enable_claude=$(jq -r '.settings.enable_claude_in_bottom_pane' "$CONFIG_FILE")
                    if [[ "$enable_claude" == "true" ]]; then
                        # 下段ペイン（0.2）でclaudeを実行
                        if ! tmux send-keys -t "$name:0.2" "claude" Enter 2>/dev/null; then
                            echo -e "${YELLOW}警告: claude実行に失敗 ($name)${NC}"
                        fi
                    fi
                    
                    # メインペイン（左上）を選択
                    tmux select-pane -t "$name:0.0" 2>/dev/null
                else
                    echo -e "${RED}エラー: 開発ペイン分割に失敗しました ($name)${NC}"
                fi
            else
                echo -e "${RED}エラー: 初期ペイン分割に失敗しました ($name)${NC}"
            fi
        fi
    else
        # 開発コマンドがない場合は通常の上下2分割
        tmux split-window -t "$name" -v -c "$path" 2>/dev/null
        sleep 0.1
        
        # 下段ペインでclaudeを自動実行する設定をチェック
        local enable_claude=$(jq -r '.settings.enable_claude_in_bottom_pane' "$CONFIG_FILE")
        if [[ "$enable_claude" == "true" ]]; then
            # 下段ペイン（0.1）でclaudeを実行
            if ! tmux send-keys -t "$name:0.1" "claude" Enter 2>/dev/null; then
                echo -e "${YELLOW}警告: claude実行に失敗 ($name)${NC}"
            fi
        fi
        
        tmux select-pane -t "$name:0.0" 2>/dev/null
    fi
    
    # レイアウト設定（開発ペインがある場合は専用レイアウト適用しない）
    local layout=$(jq -r '.settings.default_layout' "$CONFIG_FILE")
    local create_dev_pane=$(jq -r '.settings.create_dev_pane' "$CONFIG_FILE")
    
    if [[ "$create_dev_pane" != "true" || "$dev_cmd" == "null" || -z "$dev_cmd" ]]; then
        # 開発ペインがない場合のみレイアウト適用
        if [[ "$layout" != "null" && -n "$layout" ]]; then
            tmux select-layout -t "$name" "$layout" 2>/dev/null
        fi
    fi
}

# メイン処理
main() {
    local kill_existing=false
    local dry_run=false
    local specific_project=""
    
    # オプション解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -l|--list)
                check_jq
                check_config
                list_projects
                exit 0
                ;;
            -c|--config)
                check_config
                "${EDITOR:-nano}" "$CONFIG_FILE"
                exit 0
                ;;
            -s|--scan)
                check_jq
                check_config
                scan_directories
                exit 0
                ;;
            -k|--kill)
                kill_existing=true
                shift
                ;;
            -d|--dry-run)
                dry_run=true
                shift
                ;;
            -p|--project)
                specific_project="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}エラー: 不明なオプション $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    check_jq
    check_config
    
    echo -e "${BLUE}=== プロジェクトセッション起動 ===${NC}"
    echo "設定ファイル: $CONFIG_FILE"
    echo ""
    
    local session_count=0
    local skipped_count=0
    
    # 親ディレクトリ（workディレクトリ）のセッション作成（最初に実行）
    local enable_parent_dir=$(jq -r '.settings.enable_parent_directory' "$CONFIG_FILE")
    if [[ "$enable_parent_dir" == "true" ]]; then
        local parent_session_name="work-dir"
        if [[ -z "$specific_project" ]]; then
            # 既存セッションの処理
            if session_exists "$parent_session_name"; then
                if [[ "$kill_existing" == "true" ]]; then
                    if [[ "$dry_run" != "true" ]]; then
                        echo -e "${YELLOW}既存セッション削除:${NC} $parent_session_name"
                        tmux kill-session -t "$parent_session_name"
                    else
                        echo -e "${BLUE}[DRY-RUN]${NC} 既存セッション削除: $parent_session_name"
                    fi
                else
                    echo -e "${YELLOW}スキップ:${NC} $parent_session_name (セッション既存)"
                    skipped_count=$((skipped_count + 1))
                fi
            fi
            
            # 新規セッション作成
            if [[ "$kill_existing" == "true" ]] || ! session_exists "$parent_session_name"; then
                create_session "$parent_session_name" "$WORK_DIR" "null" "null" "$dry_run"
                session_count=$((session_count + 1))
            fi
        fi
    fi
    
    # スクリプト格納ディレクトリのセッション作成（2番目に実行）
    local enable_script_dir=$(jq -r '.settings.enable_script_directory' "$CONFIG_FILE")
    if [[ "$enable_script_dir" == "true" ]]; then
        local script_session_name="script-dir"
        if [[ -z "$specific_project" ]]; then
            # 既存セッションの処理
            if session_exists "$script_session_name"; then
                if [[ "$kill_existing" == "true" ]]; then
                    if [[ "$dry_run" != "true" ]]; then
                        echo -e "${YELLOW}既存セッション削除:${NC} $script_session_name"
                        tmux kill-session -t "$script_session_name"
                    else
                        echo -e "${BLUE}[DRY-RUN]${NC} 既存セッション削除: $script_session_name"
                    fi
                else
                    echo -e "${YELLOW}スキップ:${NC} $script_session_name (セッション既存)"
                    skipped_count=$((skipped_count + 1))
                fi
            fi
            
            # 新規セッション作成
            if [[ "$kill_existing" == "true" ]] || ! session_exists "$script_session_name"; then
                create_session "$script_session_name" "$SCRIPT_DIR" "null" "null" "$dry_run"
                session_count=$((session_count + 1))
            fi
        fi
    fi
    
    # プロジェクト配列を取得して配列に格納
    local projects_array=()
    while IFS= read -r line; do
        projects_array+=("$line")
    done < <(jq -c '.projects[]' "$CONFIG_FILE")
    
    for project in "${projects_array[@]}"; do
        local name=$(echo "$project" | jq -r '.name')
        local enabled=$(echo "$project" | jq -r '.enabled')
        local path=$(echo "$project" | jq -r '.path')
        local startup_cmd=$(echo "$project" | jq -r '.commands.startup')
        local dev_cmd=$(echo "$project" | jq -r '.commands.dev')
        
        # 特定のプロジェクトが指定されている場合はそれ以外をスキップ
        if [[ -n "$specific_project" && "$name" != "$specific_project" ]]; then
            continue
        fi
        
        # 無効なプロジェクトをスキップ
        if [[ "$enabled" != "true" ]]; then
            echo -e "${YELLOW}スキップ:${NC} $name (無効)"
            skipped_count=$((skipped_count + 1))
            continue
        fi
        
        # パスの存在確認
        if [[ ! -d "$path" ]]; then
            echo -e "${RED}エラー:${NC} $name - ディレクトリが存在しません: $path"
            skipped_count=$((skipped_count + 1))
            continue
        fi
        
        # 既存セッションの処理
        if session_exists "$name"; then
            if [[ "$kill_existing" == "true" ]]; then
                if [[ "$dry_run" != "true" ]]; then
                    echo -e "${YELLOW}既存セッション削除:${NC} $name"
                    tmux kill-session -t "$name"
                else
                    echo -e "${BLUE}[DRY-RUN]${NC} 既存セッション削除: $name"
                fi
            else
                echo -e "${YELLOW}スキップ:${NC} $name (セッション既存)"
                skipped_count=$((skipped_count + 1))
                continue
            fi
        fi
        
        # セッション作成
        create_session "$name" "$path" "$startup_cmd" "$dev_cmd" "$dry_run"
        session_count=$((session_count + 1))
        
    done
    
    echo ""
    echo -e "${GREEN}完了!${NC} ${session_count}個のセッションを処理、${skipped_count}個をスキップ"
    
    if [[ "$dry_run" != "true" && "$session_count" -gt 0 ]]; then
        echo ""
        echo -e "${BLUE}セッション一覧:${NC}"
        tmux list-sessions
    fi
}

# スクリプト実行
main "$@"