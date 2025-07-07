#!/bin/bash

# tmuxプロジェクト設定のバックアップ・復元スクリプト
# 使用方法: ./backup-restore.sh [オプション]

set -e

# 設定ファイルのパス
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/projects.json"
BACKUP_DIR="${SCRIPT_DIR}/backups"

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ヘルプメッセージ
show_help() {
    echo "tmuxプロジェクト設定バックアップ・復元スクリプト"
    echo ""
    echo "使用方法:"
    echo "  $0 [オプション]"
    echo ""
    echo "オプション:"
    echo "  -h, --help              このヘルプを表示"
    echo "  -b, --backup [NAME]     設定をバックアップ（名前省略時は自動生成）"
    echo "  -r, --restore [FILE]    バックアップから復元（ファイル省略時は選択メニュー）"
    echo "  -l, --list              バックアップ一覧を表示"
    echo "  -d, --delete [FILE]     バックアップファイルを削除"
    echo "  -c, --compare [FILE]    現在の設定とバックアップを比較"
    echo "  -a, --auto-backup       自動バックアップを実行"
    echo "  --clean-old             古いバックアップファイルをクリーンアップ"
    echo ""
    echo "バックアップディレクトリ: ${BACKUP_DIR}"
}

# jqの存在確認
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}エラー: jqがインストールされていません${NC}"
        exit 1
    fi
}

# バックアップディレクトリ作成
ensure_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        echo -e "${GREEN}バックアップディレクトリを作成しました: $BACKUP_DIR${NC}"
    fi
}

# 設定ファイルの存在確認
check_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}エラー: 設定ファイルが見つかりません: $CONFIG_FILE${NC}"
        exit 1
    fi
}

# バックアップファイル名生成
generate_backup_name() {
    local custom_name="$1"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    
    if [[ -n "$custom_name" ]]; then
        echo "${custom_name}_${timestamp}.json"
    else
        echo "backup_${timestamp}.json"
    fi
}

# バックアップ作成
create_backup() {
    local backup_name="$1"
    local backup_file="${BACKUP_DIR}/$(generate_backup_name "$backup_name")"
    
    ensure_backup_dir
    check_config
    
    # 設定ファイルの妥当性確認
    if ! jq . "$CONFIG_FILE" > /dev/null 2>&1; then
        echo -e "${RED}エラー: 設定ファイルが不正なJSON形式です${NC}"
        exit 1
    fi
    
    # バックアップメタデータ付きでバックアップ作成
    local backup_info=$(cat <<EOF
{
  "backup_info": {
    "created_at": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "script_version": "1.0",
    "config_file": "$CONFIG_FILE",
    "project_count": $(jq '.projects | length' "$CONFIG_FILE")
  },
  "config": $(cat "$CONFIG_FILE")
}
EOF
)
    
    echo "$backup_info" | jq . > "$backup_file"
    
    echo -e "${GREEN}バックアップを作成しました:${NC} $(basename "$backup_file")"
    echo -e "保存先: $backup_file"
    echo -e "プロジェクト数: $(jq '.projects | length' "$CONFIG_FILE")"
    
    return 0
}

# バックアップ一覧表示
list_backups() {
    ensure_backup_dir
    
    echo -e "${BLUE}=== バックアップファイル一覧 ===${NC}"
    echo ""
    
    local backup_files=($(find "$BACKUP_DIR" -name "*.json" -type f | sort -r))
    
    if [[ ${#backup_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}バックアップファイルが見つかりません${NC}"
        return
    fi
    
    for file in "${backup_files[@]}"; do
        local basename_file=$(basename "$file")
        local file_size=$(du -h "$file" | cut -f1)
        local mod_time=$(stat -c %y "$file" | cut -d. -f1)
        
        echo -e "${GREEN}●${NC} $basename_file (${file_size})"
        echo -e "  更新日時: $mod_time"
        
        # バックアップ情報を表示（あれば）
        local backup_info=$(jq -r '.backup_info // empty' "$file" 2>/dev/null)
        if [[ -n "$backup_info" ]]; then
            local created_at=$(echo "$backup_info" | jq -r '.created_at // "不明"')
            local project_count=$(echo "$backup_info" | jq -r '.project_count // "不明"')
            echo -e "  作成日時: $created_at"
            echo -e "  プロジェクト数: $project_count"
        fi
        echo ""
    done
    
    echo -e "${CYAN}合計: ${#backup_files[@]}個のバックアップ${NC}"
}

# バックアップファイル選択
select_backup() {
    local action="$1"
    ensure_backup_dir
    
    local backup_files=($(find "$BACKUP_DIR" -name "*.json" -type f | sort -r))
    
    if [[ ${#backup_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}バックアップファイルが見つかりません${NC}"
        return 1
    fi
    
    echo -e "${BLUE}${action}するバックアップファイルを選択してください:${NC}"
    echo ""
    
    for i in "${!backup_files[@]}"; do
        local file="${backup_files[$i]}"
        local basename_file=$(basename "$file")
        local mod_time=$(stat -c %y "$file" | cut -d. -f1)
        echo "  $((i+1)). $basename_file ($mod_time)"
    done
    
    echo ""
    echo -n "番号を入力 (1-${#backup_files[@]}, q=キャンセル): "
    read -r choice
    
    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo "キャンセルしました"
        return 1
    fi
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#backup_files[@]} ]]; then
        echo "${backup_files[$((choice-1))]}"
        return 0
    else
        echo -e "${RED}無効な選択です${NC}"
        return 1
    fi
}

# バックアップから復元
restore_backup() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        backup_file=$(select_backup "復元")
        [[ $? -ne 0 ]] && return 1
    else
        backup_file="${BACKUP_DIR}/${backup_file}"
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        echo -e "${RED}バックアップファイルが見つかりません: $backup_file${NC}"
        return 1
    fi
    
    # バックアップファイルの妥当性確認
    if ! jq . "$backup_file" > /dev/null 2>&1; then
        echo -e "${RED}エラー: バックアップファイルが不正なJSON形式です${NC}"
        return 1
    fi
    
    # 現在の設定のバックアップを自動作成
    echo -e "${YELLOW}復元前に現在の設定を自動バックアップします...${NC}"
    create_backup "pre_restore"
    
    echo ""
    echo -e "${YELLOW}バックアップファイル:${NC} $(basename "$backup_file")"
    
    # バックアップ情報表示
    local backup_info=$(jq -r '.backup_info // empty' "$backup_file" 2>/dev/null)
    if [[ -n "$backup_info" ]]; then
        local created_at=$(echo "$backup_info" | jq -r '.created_at // "不明"')
        local project_count=$(echo "$backup_info" | jq -r '.project_count // "不明"')
        echo -e "作成日時: $created_at"
        echo -e "プロジェクト数: $project_count"
    fi
    
    echo ""
    echo -n "このバックアップから復元しますか？ (y/N): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # 設定ファイルを復元
        local config_data=$(jq '.config // .' "$backup_file")
        echo "$config_data" | jq . > "$CONFIG_FILE"
        
        echo -e "${GREEN}設定を復元しました${NC}"
        echo -e "復元先: $CONFIG_FILE"
        
        # 復元後の設定確認
        local restored_project_count=$(jq '.projects | length' "$CONFIG_FILE")
        echo -e "復元されたプロジェクト数: $restored_project_count"
    else
        echo "キャンセルしました"
    fi
}

# バックアップファイル削除
delete_backup() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        backup_file=$(select_backup "削除")
        [[ $? -ne 0 ]] && return 1
    else
        backup_file="${BACKUP_DIR}/${backup_file}"
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        echo -e "${RED}バックアップファイルが見つかりません: $backup_file${NC}"
        return 1
    fi
    
    echo -n "バックアップファイル '$(basename "$backup_file")' を削除しますか？ (y/N): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -f "$backup_file"
        echo -e "${GREEN}バックアップファイルを削除しました${NC}"
    else
        echo "キャンセルしました"
    fi
}

# 設定ファイル比較
compare_with_backup() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        backup_file=$(select_backup "比較")
        [[ $? -ne 0 ]] && return 1
    else
        backup_file="${BACKUP_DIR}/${backup_file}"
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        echo -e "${RED}バックアップファイルが見つかりません: $backup_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}=== 設定ファイル比較 ===${NC}"
    echo -e "現在: $CONFIG_FILE"
    echo -e "バックアップ: $(basename "$backup_file")"
    echo ""
    
    # 一時ファイルでバックアップの設定部分を抽出
    local temp_backup=$(mktemp)
    jq '.config // .' "$backup_file" > "$temp_backup"
    
    # diffで比較表示
    if command -v colordiff &> /dev/null; then
        diff -u "$CONFIG_FILE" "$temp_backup" | colordiff || true
    else
        diff -u "$CONFIG_FILE" "$temp_backup" || true
    fi
    
    rm -f "$temp_backup"
}

# 自動バックアップ
auto_backup() {
    echo -e "${BLUE}=== 自動バックアップ実行 ===${NC}"
    
    # 設定ファイルに変更があるかチェック
    local latest_backup=$(find "$BACKUP_DIR" -name "*.json" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    
    if [[ -n "$latest_backup" ]]; then
        local temp_backup=$(mktemp)
        jq '.config // .' "$latest_backup" > "$temp_backup"
        
        if cmp -s "$CONFIG_FILE" "$temp_backup"; then
            echo -e "${YELLOW}設定に変更がないため、バックアップをスキップします${NC}"
            rm -f "$temp_backup"
            return 0
        fi
        rm -f "$temp_backup"
    fi
    
    create_backup "auto"
}

# 古いバックアップクリーンアップ
clean_old_backups() {
    local keep_days=30
    local keep_count=10
    
    echo -e "${BLUE}=== 古いバックアップクリーンアップ ===${NC}"
    echo -e "保持期間: ${keep_days}日、最大保持数: ${keep_count}個"
    echo ""
    
    ensure_backup_dir
    
    # 30日より古いファイルを削除
    local old_files=($(find "$BACKUP_DIR" -name "*.json" -type f -mtime +${keep_days}))
    
    if [[ ${#old_files[@]} -gt 0 ]]; then
        echo -e "${YELLOW}${keep_days}日より古いバックアップ: ${#old_files[@]}個${NC}"
        for file in "${old_files[@]}"; do
            echo "  - $(basename "$file")"
        done
        
        echo -n "これらのファイルを削除しますか？ (y/N): "
        read -r confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            rm -f "${old_files[@]}"
            echo -e "${GREEN}${#old_files[@]}個の古いバックアップを削除しました${NC}"
        fi
    fi
    
    # 最大保持数を超える場合は古いものから削除
    local all_backups=($(find "$BACKUP_DIR" -name "*.json" -type f -printf '%T@ %p\n' | sort -n | cut -d' ' -f2-))
    local excess_count=$((${#all_backups[@]} - keep_count))
    
    if [[ $excess_count -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}最大保持数を超過: ${excess_count}個削除対象${NC}"
        
        for ((i=0; i<excess_count; i++)); do
            echo "  - $(basename "${all_backups[$i]}")"
        done
        
        echo -n "これらのファイルを削除しますか？ (y/N): "
        read -r confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            for ((i=0; i<excess_count; i++)); do
                rm -f "${all_backups[$i]}"
            done
            echo -e "${GREEN}${excess_count}個の超過バックアップを削除しました${NC}"
        fi
    fi
    
    if [[ ${#old_files[@]} -eq 0 ]] && [[ $excess_count -le 0 ]]; then
        echo -e "${GREEN}クリーンアップの必要なファイルはありません${NC}"
    fi
}

# メイン処理
main() {
    check_jq
    
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        -b|--backup)
            create_backup "$2"
            ;;
        -r|--restore)
            restore_backup "$2"
            ;;
        -l|--list)
            list_backups
            ;;
        -d|--delete)
            delete_backup "$2"
            ;;
        -c|--compare)
            compare_with_backup "$2"
            ;;
        -a|--auto-backup)
            auto_backup
            ;;
        --clean-old)
            clean_old_backups
            ;;
        "")
            list_backups
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