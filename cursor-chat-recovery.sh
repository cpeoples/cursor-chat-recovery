#!/usr/bin/env bash
#
# Cursor Chat Recovery Tool v1.3.0
# https://github.com/cpeoples/cursor-chat-recovery
# License: MIT

set -e

VERSION="1.3.0"

win_to_unix_path() {
    local win_path="$1"
    if command -v cygpath &> /dev/null; then
        cygpath -u "$win_path" 2>/dev/null
    else
        echo "$win_path" | sed 's|\\|/|g' | sed 's|^\([A-Za-z]\):|/\L\1|'
    fi
}

detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        CURSOR_APP="/Applications/Cursor.app"
        CURSOR_DATA_DIR="$HOME/Library/Application Support/Cursor"
        WORKSPACE_DIR="$CURSOR_DATA_DIR/User/workspaceStorage"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        local config_base="${XDG_CONFIG_HOME:-$HOME/.config}"
        CURSOR_DATA_DIR="$config_base/Cursor"
        WORKSPACE_DIR="$CURSOR_DATA_DIR/User/workspaceStorage"
        CURSOR_SERVER_DIR="$HOME/.cursor-server/data/User/workspaceStorage"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "mingw"* ]]; then
        OS="windows"
        if [ -n "$APPDATA" ]; then
            CURSOR_DATA_DIR="$(win_to_unix_path "$APPDATA")/Cursor"
            WORKSPACE_DIR="$CURSOR_DATA_DIR/User/workspaceStorage"
            [ -n "$LOCALAPPDATA" ] && CURSOR_APP="$(win_to_unix_path "$LOCALAPPDATA")/Programs/Cursor/Cursor.exe"
        else
            echo "ERROR: APPDATA environment variable not set on Windows"
            exit 1
        fi
    else
        echo "WARNING: Unknown OS: $OSTYPE - using Linux defaults"
        OS="unknown"
        CURSOR_DATA_DIR="$HOME/.config/Cursor"
        WORKSPACE_DIR="$CURSOR_DATA_DIR/User/workspaceStorage"
    fi
}

check_cursor_installed() {
    local cursor_found=false
    
    case "$OS" in
        macos)
            [[ -d "/Applications/Cursor.app" || -d "$HOME/Applications/Cursor.app" ]] && cursor_found=true
            ;;
        linux)
            if command -v cursor &> /dev/null || \
               [[ -f "/usr/bin/cursor" || -f "/usr/local/bin/cursor" || \
                  -f "$HOME/.local/bin/cursor" || -f "/snap/bin/cursor" || \
                  -d "$CURSOR_DATA_DIR" ]]; then
                cursor_found=true
            elif [ -d "$HOME/.cursor-server" ]; then
                cursor_found=true
                [[ ! -d "$WORKSPACE_DIR" && -d "$CURSOR_SERVER_DIR" ]] && WORKSPACE_DIR="$CURSOR_SERVER_DIR"
            fi
            ;;
        windows)
            [[ (-n "$CURSOR_APP" && -f "$CURSOR_APP") || -d "$CURSOR_DATA_DIR" ]] && cursor_found=true
            ;;
    esac
    
    if [ "$cursor_found" = false ]; then
        echo -e "${RED}ERROR: Cursor IDE does not appear to be installed.${NC}"
        echo ""
        echo "Please install Cursor from: https://cursor.sh"
        echo ""
        echo "If Cursor IS installed, the script couldn't find it at expected locations:"
        case "$OS" in
            macos)
                echo "  - /Applications/Cursor.app"
                echo "  - ~/Applications/Cursor.app"
                ;;
            linux)
                echo "  - /usr/bin/cursor, /usr/local/bin/cursor, ~/.local/bin/cursor"
                echo "  - /snap/bin/cursor"
                echo "  - ~/.config/Cursor/ or \$XDG_CONFIG_HOME/Cursor/"
                echo "  - ~/.cursor-server/ (remote/SSH mode)"
                ;;
            windows)
                echo "  - %LOCALAPPDATA%\\Programs\\Cursor\\Cursor.exe"
                echo "  - %APPDATA%\\Cursor\\"
                ;;
        esac
        echo ""
        echo "If you installed Cursor elsewhere, please open an issue on GitHub."
        exit 1
    fi
}

if [ "$1" = "-v" ] || [ "$1" = "--version" ]; then
    echo "Cursor Chat Recovery Tool v${VERSION}"
    exit 0
fi

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat << EOF
Cursor Chat Recovery Tool v${VERSION}

Recover lost AI chat history when Cursor creates a new workspace

Usage: $0 [OPTIONS] [project-name]

Arguments:
  project-name    Name of your project (optional, defaults to current directory)

Options:
  -h, --help       Show this help message
  -v, --version    Show version number
  -l, --list       List workspaces only (non-interactive)
  -r, --restore SOURCE TARGET
                   Restore from SOURCE to TARGET workspace (non-interactive)
  --dry-run        Show what would be done without making changes

Examples:
  $0                              # Interactive mode, auto-detect project
  $0 my-api                       # Search for 'my-api'
  $0 "My Awesome App"             # Projects with spaces
  $0 -l my-api                    # List workspaces for 'my-api'
  $0 -r 2 1 my-api                # Restore workspace 2 to 1 for 'my-api'

Supported Platforms: macOS, Linux, Windows (Git Bash/WSL/MSYS2)
EOF
    exit 0
fi

detect_os

LIST_ONLY=false
DRY_RUN=false
RESTORE_MODE=false
SOURCE_NUM=""
TARGET_NUM=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--list) LIST_ONLY=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        -r|--restore) RESTORE_MODE=true; SOURCE_NUM="$2"; TARGET_NUM="$3"; shift 3 ;;
        -*) echo "Unknown option: $1"; echo "Use --help for usage information"; exit 1 ;;
        *) PROJECT_NAME="$1"; shift ;;
    esac
done

if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME=$(basename "$(pwd)")
    echo -e "\033[1;33mNo project name provided, using current directory: $PROJECT_NAME\033[0m"
    echo "Usage: $0 [project-name] or $0 --help for more info"
    echo ""
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Cursor Chat History Manager${NC}"
echo -e "${BLUE}Project: ${GREEN}${PROJECT_NAME}${NC}"
echo -e "${BLUE}Platform: ${GREEN}${OS}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_cursor_installed

if [ ! -d "$WORKSPACE_DIR" ]; then
    echo -e "${RED}ERROR: Workspace directory not found!${NC}"
    echo ""
    echo "Expected location: $WORKSPACE_DIR"
    echo ""
    echo "Cursor appears to be installed, but the workspace directory doesn't exist."
    echo "This usually means:"
    echo ""
    echo "  1. You haven't opened any projects in Cursor yet"
    echo "  2. You haven't used AI chat in Cursor yet"
    echo ""
    echo "To fix this:"
    echo "  1. Open Cursor"
    echo "  2. Open a project folder"
    echo "  3. Use the AI chat feature at least once"
    echo "  4. Close Cursor and run this tool again"
    exit 1
fi

check_cursor_running() {
    local cursor_running=false
    
    if [[ "$OS" == "macos" ]]; then
        if pgrep -x "Cursor" > /dev/null; then
            cursor_running=true
        fi
    elif [[ "$OS" == "linux" ]]; then
        if pgrep -x "cursor" > /dev/null || pgrep -x "Cursor" > /dev/null; then
            cursor_running=true
        fi
    elif [[ "$OS" == "windows" ]]; then
        if tasklist.exe 2>/dev/null | grep -qi "Cursor.exe"; then
            cursor_running=true
        fi
    fi
    
    if [ "$cursor_running" = true ]; then
        echo -e "${RED}WARNING: Cursor is currently running!${NC}"
        echo "It's recommended to close Cursor before modifying chat history."
        echo ""

        if [ "$DRY_RUN" = true ]; then
            echo -e "${CYAN}[DRY RUN] Would require Cursor to be closed before making changes.${NC}"
            echo -e "${CYAN}[DRY RUN] Cursor was not terminated.${NC}"
            echo ""
            return
        fi

        read -p "Do you want to kill Cursor processes? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [[ "$OS" == "macos" ]]; then
                killall Cursor 2>/dev/null || true
            elif [[ "$OS" == "linux" ]]; then
                killall cursor 2>/dev/null || killall Cursor 2>/dev/null || true
            elif [[ "$OS" == "windows" ]]; then
                taskkill.exe //F //IM Cursor.exe 2>/dev/null || true
            fi
            sleep 2
            echo -e "${GREEN}Cursor processes terminated.${NC}"
            echo ""
        else
            echo -e "${YELLOW}Continuing with Cursor running (not recommended)...${NC}"
            echo ""
        fi
    fi
}

get_mod_time() {
    local file=$1
    [[ "$OS" == "macos" ]] && stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || stat -c "%y" "$file" 2>/dev/null | cut -d'.' -f1
}

get_mtime() {
    local file=$1
    [[ "$OS" == "macos" ]] && stat -f "%m" "$file" 2>/dev/null || stat -c "%Y" "$file" 2>/dev/null
}

find_all_workspaces() {
    echo -e "${CYAN}Searching for all '$PROJECT_NAME' workspaces...${NC}" >&2
    echo "" >&2
    
    local temp_file=$(mktemp)
    local count=1
    
    for dir in "$WORKSPACE_DIR"/*/; do
        state_file="${dir}state.vscdb"
        if [ -f "$state_file" ] && strings "$state_file" 2>/dev/null | grep -qi "$PROJECT_NAME"; then
            local hash=$(basename "$dir")
            local mod_time=$(get_mod_time "$state_file")
            local size=$(du -h "$state_file" 2>/dev/null | cut -f1)
            
            echo "$hash" >> "$temp_file"
            echo -e "${count}. ${GREEN}${hash}${NC}" >&2
            echo "   Modified: $mod_time" >&2
            echo "   Size: $size" >&2
            local workspace_json="${dir}workspace.json"
            if [ -f "$workspace_json" ]; then
                local project_path=$(grep -o '"folder"[[:space:]]*:[[:space:]]*"[^"]*"' "$workspace_json" 2>/dev/null | sed 's/.*"file:\/\/\([^"]*\)".*/\1/')
                [ -n "$project_path" ] && echo -e "   ${CYAN}Project: ${project_path}${NC}" >&2
            fi
            
            echo "" >&2
            ((count++))
        fi
    done
    
    echo "$temp_file"
}

show_all_recent() {
    local filter_project=$1
    [ -z "$filter_project" ] && echo -e "${CYAN}All recent workspaces (last 10):${NC}" >&2 || echo -e "${CYAN}Recent '$filter_project' workspaces:${NC}" >&2
    echo "" >&2
    
    local temp_file=$(mktemp)
    local temp_list=$(mktemp)
    local count=1
    
    for state_file in "$WORKSPACE_DIR"/*/state.vscdb; do
        [ -f "$state_file" ] && echo "$(get_mtime "$state_file") $state_file" >> "$temp_list"
    done
    
    sort -rn "$temp_list" | head -20 | while IFS= read -r line; do
        local db_file=$(echo "$line" | cut -d' ' -f2-)
        local dir_path=$(dirname "$db_file")
        local hash=$(basename "$dir_path")
        local contains_project=false
        
        strings "$db_file" 2>/dev/null | grep -qi "$filter_project" && contains_project=true
        
        [[ -n "$filter_project" && "$contains_project" = false ]] && continue
        
        local mod_time=$(get_mod_time "$db_file")
        local size=$(du -h "$db_file" 2>/dev/null | cut -f1)
        
        echo "$hash" >> "$temp_file"
        echo -e "${count}. ${GREEN}${hash}${NC}" >&2
        echo "   Modified: $mod_time" >&2
        echo "   Size: $size" >&2
        local workspace_json="$dir_path/workspace.json"
        if [ -f "$workspace_json" ]; then
            local project_path=$(grep -o '"folder"[[:space:]]*:[[:space:]]*"[^"]*"' "$workspace_json" 2>/dev/null | sed 's/.*"file:\/\/\([^"]*\)".*/\1/')
            [ -n "$project_path" ] && echo -e "   ${CYAN}Project: ${project_path}${NC}" >&2
        fi
        echo "" >&2
        
        ((count++))
        [ $count -gt 10 ] && break
    done
    
    rm -f "$temp_list"
    echo "$temp_file"
}

backup_database() {
    local db_file=$1
    local backup_file="${db_file}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}Creating backup...${NC}"
    cp "$db_file" "$backup_file"
    echo -e "${GREEN}Backup created: $(basename "$backup_file")${NC}"
    echo ""
}

copy_chat_history() {
    local source_db=$1
    local target_db=$2
    
    echo -e "${YELLOW}Copying chat history...${NC}"
    echo "From: $(basename "$(dirname "$source_db")")"
    echo "To:   $(basename "$(dirname "$target_db")")"
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY RUN] Would backup: $target_db${NC}"
        echo -e "${CYAN}[DRY RUN] Would copy: $source_db -> $target_db${NC}"
        echo ""
        return
    fi
    
    [ -f "$target_db" ] && backup_database "$target_db"
    cp "$source_db" "$target_db"
    echo -e "${GREEN}Chat history copied successfully!${NC}"
    echo ""
}

merge_chat_histories() {
    local source_db=$1
    local target_db=$2
    
    echo -e "${YELLOW}Merging chat histories...${NC}"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY RUN] Would backup: $target_db${NC}"
        echo -e "${CYAN}[DRY RUN] Would merge: $source_db -> $target_db${NC}"
        echo ""
        return
    fi
    
    if ! command -v sqlite3 &> /dev/null; then
        echo -e "${RED}sqlite3 not found. Cannot merge databases.${NC}"
        read -p "Use simple copy instead? (y/n) > " -n 1 -r
        echo ""
        [[ $REPLY =~ ^[Yy]$ ]] && copy_chat_history "$source_db" "$target_db"
        return
    fi
    
    backup_database "$target_db"
    
    sqlite3 "$target_db" <<EOF
ATTACH DATABASE '$source_db' AS source;
INSERT OR IGNORE INTO main.ItemTable SELECT * FROM source.ItemTable;
DETACH DATABASE source;
EOF
    
    echo -e "${GREEN}Databases merged successfully!${NC}"
    echo ""
}

restore_workflow() {
    local filter="$1"
    
    check_cursor_running
    
    temp_file=$(show_all_recent "$filter")
    workspace_count=$(wc -l < "$temp_file" 2>/dev/null | tr -d ' ')
    
    if [ -z "$workspace_count" ] || [ "$workspace_count" -eq 0 ]; then
        echo -e "${RED}No workspaces found${filter:+ containing '$filter'}${NC}"
        rm -f "$temp_file"
        echo ""
        read -p "Press Enter to continue..."
        return 1
    fi
    
    echo -e "${GREEN}Found $workspace_count workspace(s)${NC}"
    echo ""
    
    if [ "$workspace_count" -eq 1 ]; then
        echo -e "${YELLOW}Only one workspace found. Nothing to restore between.${NC}"
        rm -f "$temp_file"
        echo ""
        read -p "Press Enter to continue..."
        return 1
    fi
    
    echo "Enter 'q' to quit"
    echo ""
    read -p "Enter SOURCE workspace number (has the chat history you want): " source_num
    [[ "$source_num" == "q" || "$source_num" == "Q" ]] && rm -f "$temp_file" && return 1
    
    read -p "Enter TARGET workspace number (where to restore the chat): " target_num
    [[ "$target_num" == "q" || "$target_num" == "Q" ]] && rm -f "$temp_file" && return 1
    
    source_hash=$(sed -n "${source_num}p" "$temp_file" 2>/dev/null)
    target_hash=$(sed -n "${target_num}p" "$temp_file" 2>/dev/null)
    rm -f "$temp_file"
    
    if [ -z "$source_hash" ] || [ -z "$target_hash" ]; then
        echo -e "${RED}Invalid selection${NC}"; return 1
    fi
    
    if [ "$source_hash" = "$target_hash" ]; then
        echo -e "${RED}Source and target cannot be the same!${NC}"; return 1
    fi
    
    source_db="$WORKSPACE_DIR/$source_hash/state.vscdb"
    target_db="$WORKSPACE_DIR/$target_hash/state.vscdb"
    
    if [ ! -f "$source_db" ] || [ ! -f "$target_db" ]; then
        echo -e "${RED}One or both databases not found!${NC}"; return 1
    fi
    
    echo ""
    echo "Restore method:"
    echo "1. Copy (replace target with source - recommended)"
    echo "2. Merge (combine both databases - experimental)"
    echo "q. Quit"
    read -p "Select method (1/2/q): " method
    echo ""
    
    [[ "$method" == "q" || "$method" == "Q" ]] && echo "Cancelled." && return 1
    [[ "$method" == "1" ]] && copy_chat_history "$source_db" "$target_db"
    [[ "$method" == "2" ]] && merge_chat_histories "$source_db" "$target_db"
    
    echo -e "${GREEN}Done! You can now open Cursor.${NC}"
    echo -e "${CYAN}Make sure to open your project from the correct path.${NC}"
    return 0
}

main_menu() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}What would you like to do?${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "1. Find and restore '$PROJECT_NAME' workspaces"
    echo "2. Show all recent workspaces (unfiltered)"
    echo "3. View workspace details for '$PROJECT_NAME'"
    echo "q. Exit"
    echo ""
    read -p "Select option (1-3/q): " option
    echo ""
    
    case $option in
        1) restore_workflow "$PROJECT_NAME" ;;
        2) restore_workflow "" ;;
        3)
            temp_file=$(find_all_workspaces)
            workspace_count=$(wc -l < "$temp_file" 2>/dev/null | tr -d ' ')
            rm -f "$temp_file"
            
            if [ -z "$workspace_count" ] || [ "$workspace_count" -eq 0 ]; then
                echo -e "${RED}No workspaces found containing '$PROJECT_NAME'${NC}"
            else
                echo -e "${GREEN}Found $workspace_count workspace(s) containing '$PROJECT_NAME'${NC}"
            fi
            
            echo ""
            read -p "Press Enter to continue..."
            main_menu
            ;;
        q|Q) echo "Exiting..."; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; main_menu ;;
    esac
}

if [ "$LIST_ONLY" = true ]; then
    echo -e "${CYAN}Listing workspaces for '$PROJECT_NAME'...${NC}"
    echo ""
    temp_file=$(show_all_recent "$PROJECT_NAME")
    workspace_count=$(wc -l < "$temp_file" 2>/dev/null | tr -d ' ')
    rm -f "$temp_file"
    
    [[ -z "$workspace_count" || "$workspace_count" -eq 0 ]] && echo -e "${RED}No workspaces found containing '$PROJECT_NAME'${NC}" && exit 1
    echo -e "${GREEN}Found $workspace_count workspace(s)${NC}"
    exit 0
fi

if [ "$RESTORE_MODE" = true ]; then
    [[ -z "$SOURCE_NUM" || -z "$TARGET_NUM" ]] && echo -e "${RED}ERROR: --restore requires SOURCE and TARGET numbers${NC}" && exit 1
    
    echo -e "${CYAN}Non-interactive restore mode${NC}"
    echo ""
    
    temp_file=$(show_all_recent "$PROJECT_NAME")
    workspace_count=$(wc -l < "$temp_file" 2>/dev/null | tr -d ' ')
    
    [[ -z "$workspace_count" || "$workspace_count" -eq 0 ]] && echo -e "${RED}No workspaces found containing '$PROJECT_NAME'${NC}" && rm -f "$temp_file" && exit 1
    
    source_hash=$(sed -n "${SOURCE_NUM}p" "$temp_file" 2>/dev/null)
    target_hash=$(sed -n "${TARGET_NUM}p" "$temp_file" 2>/dev/null)
    rm -f "$temp_file"
    
    [[ -z "$source_hash" || -z "$target_hash" ]] && echo -e "${RED}Invalid workspace numbers. Use --list to see available workspaces.${NC}" && exit 1
    [ "$source_hash" = "$target_hash" ] && echo -e "${RED}Source and target cannot be the same!${NC}" && exit 1
    
    source_db="$WORKSPACE_DIR/$source_hash/state.vscdb"
    target_db="$WORKSPACE_DIR/$target_hash/state.vscdb"
    
    [ ! -f "$source_db" ] && echo -e "${RED}Source database not found: $source_db${NC}" && exit 1
    
    copy_chat_history "$source_db" "$target_db"
    
    [ "$DRY_RUN" = true ] && echo -e "${CYAN}[DRY RUN] No changes were made.${NC}" || echo -e "${GREEN}Done! You can now open Cursor.${NC}"
    exit 0
fi

main_menu
