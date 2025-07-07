#!/bin/bash

# tmuxセッション管理補助スクリプト
# 使用方法: ./session-manager.sh [オプション]

set -e

# 設定ファイルのパス
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/projects.json"

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# ヘルプメッセージ
show_help() {
    echo "tmuxセッション管理補助スクリプト"
    echo ""
    echo "使用方法:"
    echo "  $0 [オプション]"
    echo ""
    echo "オプション:"
    echo "  -h, --help          このヘルプを表示"
    echo "  -s, --status        全セッションの状態を表示"
    echo "  -a, --attach [NAME] セッションにアタッチ（名前省略時は選択メニュー）"
    echo "  -k, --kill [NAME]   セッションを削除（名前省略時は選択メニュー）"
    echo "  -r, --restart [NAME] セッションを再起動（名前省略時は選択メニュー）"
    echo "  -c, --clean         無効なセッションをクリーンアップ"
    echo "  -w, --watch         セッション状態をリアルタイム監視"
    echo ""
}

# jqの存在確認
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}エラー: jqがインストールされていません${NC}"
        exit 1
    fi
}

# tmuxの存在確認
check_tmux() {
    if ! command -v tmux &> /dev/null; then
        echo -e "${RED}エラー: tmuxがインストールされていません${NC}"
        exit 1
    fi
}

# セッション一覧取得
get_sessions() {
    tmux list-sessions -F "#{session_name}" 2>/dev/null || echo ""
}

# プロジェクト設定取得
get_project_config() {
    local project_name="$1"
    jq -r ".projects[] | select(.name == \"$project_name\")" "$CONFIG_FILE" 2>/dev/null
}

# セッション状態表示
show_status() {
    echo -e "${BLUE}=== tmuxセッション状態 ===${NC}"
    echo ""
    
    local running_sessions=($(get_sessions))
    local config_projects=($(jq -r '.projects[].name' "$CONFIG_FILE" 2>/dev/null))
    
    if [[ ${#running_sessions[@]} -eq 0 ]]; then
        echo -e "${YELLOW}実行中のセッションはありません${NC}"
    else
        echo -e "${GREEN}実行中のセッション: ${#running_sessions[@]}個${NC}"
        echo ""
        
        for session in "${running_sessions[@]}"; do
            local session_info=$(tmux list-sessions -t "$session" -F "#{session_name}:#{session_windows}:#{session_created}" 2>/dev/null | head -1)
            IFS=':' read -r name windows created <<< "$session_info"
            
            local project_config=$(get_project_config "$session")
            if [[ -n "$project_config" ]]; then
                local project_type=$(echo "$project_config" | jq -r '.type')
                local project_desc=$(echo "$project_config" | jq -r '.description')
                echo -e "${GREEN}✓${NC} ${name} (${project_type}) - ${windows}ウィンドウ"
                echo -e "  ${project_desc}"
            else
                echo -e "${CYAN}●${NC} ${name} (設定外) - ${windows}ウィンドウ"
            fi
            
            # 作成時刻を表示
            local created_time=$(date -d "@$created" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "不明")
            echo -e "  作成: ${created_time}"
            echo ""
        done
    fi
    
    # 設定済みプロジェクトの状態確認
    echo -e "${BLUE}=== 設定済みプロジェクト ===${NC}"
    echo ""
    
    for project in "${config_projects[@]}"; do
        local project_config=$(get_project_config "$project")
        local enabled=$(echo "$project_config" | jq -r '.enabled')
        local project_type=$(echo "$project_config" | jq -r '.type')
        
        if printf '%s\n' "${running_sessions[@]}" | grep -qx "$project"; then
            echo -e "${GREEN}●${NC} ${project} (${project_type}) - 実行中"
        elif [[ "$enabled" == "true" ]]; then
            echo -e "${YELLOW}○${NC} ${project} (${project_type}) - 停止中"
        else
            echo -e "${RED}✗${NC} ${project} (${project_type}) - 無効"
        fi
    done
}

# セッション選択メニュー
select_session() {
    local action="$1"
    local sessions=($(get_sessions))
    
    if [[ ${#sessions[@]} -eq 0 ]]; then
        echo -e "${YELLOW}実行中のセッションがありません${NC}"
        return 1
    fi
    
    echo -e "${BLUE}${action}するセッションを選択してください:${NC}"
    echo ""
    
    for i in "${!sessions[@]}"; do
        local session="${sessions[$i]}"
        local project_config=$(get_project_config "$session")
        if [[ -n "$project_config" ]]; then
            local project_type=$(echo "$project_config" | jq -r '.type')
            echo "  $((i+1)). $session ($project_type)"
        else
            echo "  $((i+1)). $session (設定外)"
        fi
    done
    
    echo ""
    echo -n "番号を入力 (1-${#sessions[@]}, q=キャンセル): "
    read -r choice
    
    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo "キャンセルしました"
        return 1
    fi
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#sessions[@]} ]]; then
        echo "${sessions[$((choice-1))]}"
        return 0
    else
        echo -e "${RED}無効な選択です${NC}"
        return 1
    fi
}

# セッションにアタッチ
attach_session() {
    local session_name="$1"
    
    if [[ -z "$session_name" ]]; then
        session_name=$(select_session "アタッチ")
        [[ $? -ne 0 ]] && return 1
    fi
    
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo -e "${RED}セッション '$session_name' が存在しません${NC}"
        return 1
    fi
    
    echo -e "${GREEN}セッション '$session_name' にアタッチしています...${NC}"
    tmux attach-session -t "$session_name"
}

# セッションを削除
kill_session() {
    local session_name="$1"
    
    if [[ -z "$session_name" ]]; then
        session_name=$(select_session "削除")
        [[ $? -ne 0 ]] && return 1
    fi
    
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo -e "${RED}セッション '$session_name' が存在しません${NC}"
        return 1
    fi
    
    echo -n "セッション '$session_name' を削除しますか？ (y/N): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        tmux kill-session -t "$session_name"
        echo -e "${GREEN}セッション '$session_name' を削除しました${NC}"
    else
        echo "キャンセルしました"
    fi
}

# セッション再起動
restart_session() {
    local session_name="$1"
    
    if [[ -z "$session_name" ]]; then
        session_name=$(select_session "再起動")
        [[ $? -ne 0 ]] && return 1
    fi
    
    local project_config=$(get_project_config "$session_name")
    if [[ -z "$project_config" ]]; then
        echo -e "${RED}プロジェクト '$session_name' の設定が見つかりません${NC}"
        return 1
    fi
    
    echo -n "セッション '$session_name' を再起動しますか？ (y/N): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}セッション '$session_name' を再起動中...${NC}"
        
        # 既存セッション削除
        if tmux has-session -t "$session_name" 2>/dev/null; then
            tmux kill-session -t "$session_name"
        fi
        
        # start-projects.shで再作成
        "$SCRIPT_DIR/start-projects.sh" -p "$session_name"
        
        echo -e "${GREEN}セッション '$session_name' の再起動が完了しました${NC}"
    else
        echo "キャンセルしました"
    fi
}

# 無効なセッションクリーンアップ
clean_sessions() {
    echo -e "${BLUE}=== セッションクリーンアップ ===${NC}"
    echo ""
    
    local running_sessions=($(get_sessions))
    local config_projects=($(jq -r '.projects[].name' "$CONFIG_FILE" 2>/dev/null))
    local cleanup_count=0
    
    for session in "${running_sessions[@]}"; do
        # 設定にないセッションを検出
        if ! printf '%s\n' "${config_projects[@]}" | grep -qx "$session"; then
            echo -n "設定外のセッション '$session' を削除しますか？ (y/N): "
            read -r confirm
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                tmux kill-session -t "$session"
                echo -e "${GREEN}削除しました: $session${NC}"
                cleanup_count=$((cleanup_count + 1))
            else
                echo -e "${YELLOW}スキップ: $session${NC}"
            fi
        fi
    done
    
    echo ""
    echo -e "${GREEN}クリーンアップ完了: ${cleanup_count}個のセッションを削除${NC}"
}

# リアルタイム監視
watch_sessions() {
    echo -e "${BLUE}=== tmuxセッションリアルタイム監視 ===${NC}"
    echo -e "${YELLOW}Ctrl+C で終了${NC}"
    echo ""
    
    while true; do
        clear
        echo -e "${BLUE}$(date '+%Y-%m-%d %H:%M:%S') - tmuxセッション状態${NC}"
        echo ""
        
        show_status
        
        echo ""
        echo -e "${YELLOW}更新間隔: 5秒 (Ctrl+C で終了)${NC}"
        sleep 5
    done
}

# メイン処理
main() {
    check_tmux
    check_jq
    
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        -s|--status)
            show_status
            ;;
        -a|--attach)
            attach_session "$2"
            ;;
        -k|--kill)
            kill_session "$2"
            ;;
        -r|--restart)
            restart_session "$2"
            ;;
        -c|--clean)
            clean_sessions
            ;;
        -w|--watch)
            watch_sessions
            ;;
        "")
            show_status
            ;;
        *)
            echo -e "${RED}エラー: 不明なオプション $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

# スクリプト実行
main "$@"