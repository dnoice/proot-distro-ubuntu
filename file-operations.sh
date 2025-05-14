#!/bin/bash
# ===========================================
# Advanced File Operations
# ===========================================
# Robust file management functions with safety checks and intuitive interfaces
# Author: Claude & Me
# Version: 1.1
# Last Updated: 2025-05-14

# ===========================================
# Configuration Options
# ===========================================

# User-configurable options
FILE_OP_VERBOSE=${FILE_OP_VERBOSE:-1}                      # Verbose output (0=off, 1=on)
FILE_OP_BACKUP_DIR=${FILE_OP_BACKUP_DIR:-"$HOME/.backups"} # Default backup directory
FILE_OP_TRASH_DIR=${FILE_OP_TRASH_DIR:-"$HOME/.trash"}     # Trash directory for safer deletion
FILE_OP_CONFIRM_DELETE=${FILE_OP_CONFIRM_DELETE:-1}        # Confirm before deleting (0=off, 1=on)
FILE_OP_MAX_PREVIEW_LINES=${FILE_OP_MAX_PREVIEW_LINES:-10} # Maximum lines to show in previews

# ===========================================
# Basic File Navigation & Management
# ===========================================

# Better ls commands
alias ls="ls --color=auto"
alias l="ls -A1"
alias ll="ls -lh"
alias la="ls -lah"
alias lt="ls -lahtr"  # Sort by time, reversed

# Enhanced navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ......="cd ../../../../.."

# Multi-level navigation
alias ..1="cd .."
alias ..2="cd ../.."
alias ..3="cd ../../.."
alias ..4="cd ../../../.."
alias ..5="cd ../../../../.."

# Directory creation and file operations
alias mkd="mkdir -p"
alias rd="rmdir"
alias cp="cp -iv"
alias mv="mv -iv"
alias rm="rm -iv"
alias ln="ln -iv"
alias chmod="chmod -v"
alias chown="chown -v"

# Finding files and content
alias ff="find . -type f -name"
alias fd="find . -type d -name"
alias fgrep="find . -type f -exec grep -l"
alias fsize="find . -type f -name"

# Show file contents with syntax highlighting if available
if command -v bat &> /dev/null; then
    alias cat="bat --style=plain"
    alias catp="bat --style=plain --paging=always"
elif command -v pygmentize &> /dev/null; then
    # Use pygments if bat is not available
    alias ccat="pygmentize -g"
    # Function to handle multiple files and non-text files
    function pcat() {
        for file in "$@"; do
            if [ -f "$file" ]; then
                if file --mime "$file" | grep -q "text/"; then
                    pygmentize -g "$file"
                else
                    echo -e "${YELLOW}Binary file: $file${RESET}"
                    file "$file"
                fi
            else
                echo -e "${RED}File not found: $file${RESET}"
            fi
        done
    }
fi

# Add locate if available
if command -v locate &> /dev/null; then
    alias loc="locate"
    alias udb="sudo updatedb"
fi

# Tree command with different depths
if command -v tree &> /dev/null; then
    alias t="tree -L 1 -C"
    alias t2="tree -L 2 -C"
    alias t3="tree -L 3 -C"
    alias ta="tree -a -L 1 -C"
    alias ta2="tree -a -L 2 -C"
    alias td="tree -d -L 1 -C"
    alias td2="tree -d -L 2 -C"
fi

# Enhanced cd function with option to toggle verbosity
CD_VERBOSE=1  # Set to 0 to make less verbose by default

function cd() {
    # Save old directory for potential "back" command
    OLDPWD_STACK+=("$PWD")
    if [ ${#OLDPWD_STACK[@]} -gt 20 ]; then
        # Keep only the last 20 directories in history
        OLDPWD_STACK=("${OLDPWD_STACK[@]:1}")
    fi
    
    # Handle special case for cd with no arguments
    if [ "$#" -eq 0 ]; then
        builtin cd || return
    else
        builtin cd "$@" || return
    fi
    
    if [ "$CD_VERBOSE" -eq 1 ]; then
        # Show directory content
        if command -v exa &> /dev/null; then
            exa -a --icons --group-directories-first
        else
            ls -a
        fi
        
        # Show git status if in a git repository
        if git rev-parse --git-dir > /dev/null 2>&1; then
            echo
            echo -e "${YELLOW}Git status:${RESET}"
            git status -s
        fi
        
        # Show project info if available
        if [ -f "package.json" ]; then
            echo
            echo -e "${YELLOW}Node.js project:${RESET} $(jq -r '.name + " v" + .version' package.json 2>/dev/null)"
        fi
        
        if [ -f "requirements.txt" ]; then
            echo
            echo -e "${YELLOW}Python project with requirements.txt${RESET}"
        fi
    fi
}

# Initialize directory history stack
OLDPWD_STACK=()

# Function to go back in directory history
function back() {
    if [ ${#OLDPWD_STACK[@]} -eq 0 ]; then
        echo -e "${RED}No previous directory in history${RESET}"
        return 1
    fi
    
    local prev_dir="${OLDPWD_STACK[-1]}"
    unset 'OLDPWD_STACK[-1]'  # Remove last element
    
    echo -e "${CYAN}Going back to: ${BOLD}$prev_dir${RESET}"
    builtin cd "$prev_dir" || return
    
    if [ "$CD_VERBOSE" -eq 1 ]; then
        ls -a
    fi
}

alias b="back"

# Toggle cd verbosity
function toggle_cd_verbose() {
    if [ "$CD_VERBOSE" -eq 1 ]; then
        CD_VERBOSE=0
        echo "CD verbosity is now OFF"
    else
        CD_VERBOSE=1
        echo "CD verbosity is now ON"
    fi
}

alias cdv="toggle_cd_verbose"

# Recently modified files
function recent() {
    local count=${1:-10}
    local days=${2:-7}
    local ignore_pattern=${3:-"node_modules|\.git|venv|__pycache__"}
    
    echo -e "${YELLOW}Files modified in the last $days days:${RESET}"
    
    if command -v fd &> /dev/null; then
        # Use fd (faster alternative to find) if available
        fd --changed-within "${days}days" --type f --exclude "$ignore_pattern" | sort -r | head -n "$count"
    else
        find . -type f -mtime -"$days" -not -path "*/\.*" -not -path "*/node_modules/*" -not -path "*/venv/*" | grep -v -E "$ignore_pattern" | sort -r | head -n "$count"
    fi
}

# ===========================================
# Trash Management for Safer File Deletion
# ===========================================

# Initialize trash directory
function _init_trash_dir() {
    if [ ! -d "$FILE_OP_TRASH_DIR" ]; then
        mkdir -p "$FILE_OP_TRASH_DIR"
        if [ ! -d "$FILE_OP_TRASH_DIR/.info" ]; then
            mkdir -p "$FILE_OP_TRASH_DIR/.info"
        fi
    fi
}

# Move files to trash instead of deleting
function trash() {
    _init_trash_dir
    
    if [ $# -eq 0 ]; then
        echo -e "${YELLOW}Usage: trash <file1> [file2] [...]${RESET}"
        echo "Move files to trash instead of deleting them permanently"
        return 1
    fi
    
    local file_count=0
    for file in "$@"; do
        if [ ! -e "$file" ]; then
            echo -e "${RED}Error: '$file' does not exist${RESET}"
            continue
        fi
        
        # Generate a unique filename in trash
        local base_name=$(basename "$file")
        local trash_name="$base_name.$(date +%Y%m%d%H%M%S).$$"
        
        # Move file to trash
        mv "$file" "$FILE_OP_TRASH_DIR/$trash_name"
        
        # Save original path info
        echo "$PWD/$file" > "$FILE_OP_TRASH_DIR/.info/$trash_name.path"
        
        ((file_count++))
    done
    
    if [ $file_count -gt 0 ]; then
        echo -e "${GREEN}Moved $file_count item(s) to trash${RESET}"
    fi
}

# List trashed files
function trash_list() {
    _init_trash_dir
    
    echo -e "${YELLOW}Trash contents:${RESET}"
    local file_count=0
    
    for file in "$FILE_OP_TRASH_DIR"/*; do
        if [ -f "$file" ] || [ -d "$file" ]; then
            local trash_name=$(basename "$file")
            local original_path="Unknown"
            local info_file="$FILE_OP_TRASH_DIR/.info/$trash_name.path"
            
            if [ -f "$info_file" ]; then
                original_path=$(cat "$info_file")
            fi
            
            # Get timestamp from filename
            local timestamp="unknown"
            if [[ "$trash_name" =~ \.([0-9]{14})\. ]]; then
                local timestamp_str="${BASH_REMATCH[1]}"
                timestamp=$(date -d "${timestamp_str:0:4}-${timestamp_str:4:2}-${timestamp_str:6:2} ${timestamp_str:8:2}:${timestamp_str:10:2}:${timestamp_str:12:2}" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)
                if [ $? -ne 0 ]; then
                    timestamp="$(date -j -f "%Y%m%d%H%M%S" "${timestamp_str}" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)"
                fi
            fi
            
            # Get size
            local size=$(du -sh "$file" | cut -f1)
            
            echo -e "${CYAN}$file_count:${RESET} ${BOLD}${trash_name%.*.*}${RESET} (${GREEN}$size${RESET}, trashed on ${YELLOW}$timestamp${RESET})"
            echo -e "   Original path: ${PURPLE}$original_path${RESET}"
            
            ((file_count++))
        fi
    done
    
    if [ $file_count -eq 0 ]; then
        echo -e "${GREEN}Trash is empty${RESET}"
    else
        echo
        echo -e "${CYAN}Total: $file_count item(s)${RESET}"
        echo -e "${YELLOW}Use 'trash_restore <number>' to restore or 'trash_empty' to empty trash${RESET}"
    fi
}

# Restore file from trash
function trash_restore() {
    _init_trash_dir
    
    if [ $# -eq 0 ]; then
        echo -e "${YELLOW}Usage: trash_restore <number|filename>${RESET}"
        echo "Restore a file from trash"
        trash_list
        return 1
    fi
    
    local target="$1"
    local file_to_restore=""
    local original_path=""
    
    # Check if we're using a number
    if [[ "$target" =~ ^[0-9]+$ ]]; then
        local count=0
        for file in "$FILE_OP_TRASH_DIR"/*; do
            if [ -f "$file" ] || [ -d "$file" ]; then
                if [ $count -eq "$target" ]; then
                    file_to_restore="$file"
                    break
                fi
                ((count++))
            fi
        done
    else
        # Direct filename match
        for file in "$FILE_OP_TRASH_DIR"/$target*; do
            if [ -e "$file" ]; then
                file_to_restore="$file"
                break
            fi
        done
    fi
    
    if [ -z "$file_to_restore" ] || [ ! -e "$file_to_restore" ]; then
        echo -e "${RED}Error: File not found in trash${RESET}"
        trash_list
        return 1
    fi
    
    local trash_name=$(basename "$file_to_restore")
    local info_file="$FILE_OP_TRASH_DIR/.info/$trash_name.path"
    
    if [ -f "$info_file" ]; then
        original_path=$(cat "$info_file")
    fi
    
    # Determine restore location
    local restore_path=""
    local restore_dirname=""
    local restore_basename="${trash_name%.*.*}"
    
    if [ -n "$original_path" ] && [ "$original_path" != "Unknown" ]; then
        restore_path="$original_path"
        restore_dirname=$(dirname "$original_path")
    else
        restore_path="$PWD/$restore_basename"
        restore_dirname="$PWD"
    fi
    
    # Check if target directory exists
    if [ ! -d "$restore_dirname" ]; then
        echo -e "${YELLOW}Original directory no longer exists. Restoring to current directory.${RESET}"
        restore_path="$PWD/$restore_basename"
    fi
    
    # Check if target file already exists
    if [ -e "$restore_path" ]; then
        echo -e "${RED}Warning: A file or directory already exists at the target location:${RESET}"
        echo -e "${YELLOW}$restore_path${RESET}"
        echo -e "${YELLOW}Restore to a different location? [y/N]${RESET}"
        read -r alt_confirm
        
        if [[ "$alt_confirm" =~ ^[yY]$ ]]; then
            echo -e "${YELLOW}Enter new filename (with path if desired):${RESET}"
            read -r restore_path
            
            if [ -z "$restore_path" ]; then
                echo -e "${RED}No path provided. Aborting.${RESET}"
                return 1
            fi
        else
            echo -e "${RED}Restoration aborted.${RESET}"
            return 1
        fi
    fi
    
    # Restore the file
    mv "$file_to_restore" "$restore_path"
    rm -f "$info_file"
    
    echo -e "${GREEN}Successfully restored '${BOLD}${restore_basename}${RESET}${GREEN}' to '${BOLD}${restore_path}${RESET}${GREEN}'${RESET}"
}

# Empty the trash
function trash_empty() {
    _init_trash_dir
    
    local file_count=$(find "$FILE_OP_TRASH_DIR" -maxdepth 1 -not -path "$FILE_OP_TRASH_DIR" -not -path "$FILE_OP_TRASH_DIR/.info" | wc -l)
    
    if [ "$file_count" -eq 0 ]; then
        echo -e "${GREEN}Trash is already empty${RESET}"
        return 0
    fi
    
    echo -e "${RED}Warning: This will permanently delete $file_count item(s) in trash${RESET}"
    echo -e "${YELLOW}Continue? [y/N]${RESET}"
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo -e "${YELLOW}Operation cancelled${RESET}"
        return 1
    fi
    
    # Empty trash
    rm -rf "$FILE_OP_TRASH_DIR"/*
    rm -rf "$FILE_OP_TRASH_DIR/.info"/*
    
    echo -e "${GREEN}Trash emptied successfully${RESET}"
}

# Aliases for trash functions
alias tl="trash_list"
alias tr="trash_restore"
alias te="trash_empty"

# Override rm with trash if configured to do so
if [ "$FILE_OP_CONFIRM_DELETE" -eq 1 ]; then
    function rm() {
        if [ "$1" = "-rf" ] || [ "$1" = "-fr" ]; then
            echo -e "${YELLOW}Using trash instead of dangerous 'rm -rf'. Use '\\rm' for real deletion.${RESET}"
            shift
            trash "$@"
        else
            echo -e "${YELLOW}Using trash instead of rm. Use '\\rm' for real deletion.${RESET}"
            trash "$@"
        fi
    }
fi

# ===========================================
# Archive Management Functions
# ===========================================

# Extract various archive formats with error checking
function extract() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: extract <file>${RESET}"
        echo "Supports: .tar.bz2, .tar.gz, .bz2, .rar, .gz, .tar, .tbz2, .tgz, .zip, .Z, .7z, .xz, .zst"
        return 1
    fi
    
    if [ ! -f "$1" ]; then
        echo -e "${RED}'$1' is not a valid file${RESET}"
        return 1
    fi
    
    # Create a temporary directory for extraction
    local extract_dir
    local file_base=$(basename "$1")
    local file_name="${file_base%.*}"
    
    # For double extensions like .tar.gz
    if [[ "$file_name" == *.tar ]]; then
        file_name="${file_name%.*}"
    fi
    
    # Extract to a subdirectory if not already in one
    if [ -d "$file_name" ]; then
        extract_dir="$file_name"
    else
        extract_dir="$file_name"
        mkdir -p "$extract_dir"
    fi
    
    # Check if directory creation was successful
    if [ ! -d "$extract_dir" ]; then
        echo -e "${RED}Failed to create extraction directory: $extract_dir${RESET}"
        return 1
    fi
    
    # Extract based on file extension
    echo -e "${YELLOW}Extracting: $1 to $extract_dir${RESET}"
    
    case "$1" in
        *.tar.bz2)   command -v tar >/dev/null || { echo -e "${RED}Error: 'tar' command not found${RESET}"; return 1; }
                     echo "Extracting tar.bz2 archive..."
                     tar xjf "$1" -C "$extract_dir" --strip-components=1 || { echo -e "${RED}Extraction failed${RESET}"; rm -rf "$extract_dir"; return 1; }
                     ;;
        *.tar.gz)    command -v tar >/dev/null || { echo -e "${RED}Error: 'tar' command not found${RESET}"; return 1; }
                     echo "Extracting tar.gz archive..."
                     tar xzf "$1" -C "$extract_dir" --strip-components=1 || { echo -e "${RED}Extraction failed${RESET}"; rm -rf "$extract_dir"; return 1; }
                     ;;
        *.tar.xz)    command -v tar >/dev/null || { echo -e "${RED}Error: 'tar' command not found${RESET}"; return 1; }
                     echo "Extracting tar.xz archive..."
                     tar xJf "$1" -C "$extract_dir" --strip-components=1 || { echo -e "${RED}Extraction failed${RESET}"; rm -rf "$extract_dir"; return 1; }
                     ;;
        *.tar.zst)   command -v tar >/dev/null || { echo -e "${RED}Error: 'tar' command not found${RESET}"; return 1; }
                     command -v zstd >/dev/null || { echo -e "${RED}Error: 'zstd' command not found${RESET}"; return 1; }
                     echo "Extracting tar.zst archive..."
                     tar --zstd -xf "$1" -C "$extract_dir" --strip-components=1 || { echo -e "${RED}Extraction failed${RESET}"; rm -rf "$extract_dir"; return 1; }
                     ;;
        *.bz2)       command -v bunzip2 >/dev/null || { echo -e "${RED}Error: 'bunzip2' command not found${RESET}"; return 1; }
                     echo "Extracting bz2 archive..."
                     bunzip2 -c "$1" > "$extract_dir/${file_name}" || { echo -e "${RED}Extraction failed${RESET}"; rm -rf "$extract_dir"; return 1; }
                     ;;
        *.rar)       command -v unrar >/dev/null || { echo -e "${RED}Error: 'unrar' command not found${RESET}"; return 1; }
                     echo "Extracting rar archive..."
                     unrar x "$1" "$extract_dir/" || { echo -e "${RED}Extraction failed${RESET}"; rm -rf "$extract_dir"; return 1; }
                     ;;
        *.gz)        command -v gunzip >/dev/null || { echo -e "${RED}Error: 'gunzip' command not found${RESET}"; return 1; }
                     echo "Extracting gz archive..."
                     gunzip -c "$1" > "$extract_dir/${file_name}" || { echo -e "${RED}Extraction failed${RESET}"; rm -rf "$extract_dir"; return 1; }
                     ;;
        *.tar)       command -v tar >/dev/null || { echo -e "${RED}Error: 'tar' command not found${RESET}"; return 1; }
                     echo "Extracting tar archive..."
                     tar xf "$1" -C "$extract_dir" --strip-components=1 || { echo -e "${RED}Extraction failed${RESET}"; rm -rf "$extract_dir"; return 1; }
                     ;;
        *.tbz2)      command -v tar >/dev/null || { echo -e "${RED}Error: 'tar' command not found${RESET}"; return 1; }
                     echo "Extracting tbz2 archive..."
                     tar xjf "$1" -C "$extract_dir" --strip-components=1 || { echo -e "${RED}Extraction failed${RESET}"; rm -rf "$extract_dir"; return 1; }
                     ;;
        *.tgz)       command -v tar >/dev/null || { echo -e "${RED}Error: 'tar' command not found${RESET}"; return 1; }
                     echo "Extracting tgz archive..."
                     tar xzf "$1" -C "$extract_dir" --strip-components=1 || { echo -e "${RED}Extraction failed${RESET}"; rm -rf "$extract_dir"; return 1; }
                     ;;
        *.zip)       command -v unzip >/dev/null || { echo -e "${RED}Error: 'unzip' command not found${RESET}"; return 1; }
                     echo "Extracting zip archive..."
                     unzip "$1" -d "$extract_dir" || { echo -e "${RED}Extraction failed${RESET}"; rm -rf "$extract_dir"; return 1; }
                     ;;
        *.Z)         command -v uncompress >/dev/null || { echo -e "${RED}Error: 'uncompress' command not found${RESET}"; return 1; }
                     echo "Extracting Z archive..."
                     uncompress -c "$1" > "$extract_dir/${file_name}" || { echo -e "${RED}Extraction failed${RESET}"; rm -rf "$extract_dir"; return 1; }
                     ;;
        *.7z)        command -v 7z >/dev/null || { echo -e "${RED}Error: '7z' command not found${RESET}"; return 1; }
                     echo "Extracting 7z archive..."
                     7z x -o"$extract_dir" "$1" || { echo -e "${RED}Extraction failed${RESET}"; rm -rf "$extract_dir"; return 1; }
                     ;;
        *.xz)        command -v xz >/dev/null || { echo -e "${RED}Error: 'xz' command not found${RESET}"; return 1; }
                     echo "Extracting xz archive..."
                     xz -dc "$1" > "$extract_dir/${file_name}" || { echo -e "${RED}Extraction failed${RESET}"; rm -rf "$extract_dir"; return 1; }
                     ;;
        *.zst)       command -v zstd >/dev/null || { echo -e "${RED}Error: 'zstd' command not found${RESET}"; return 1; }
                     echo "Extracting zst archive..."
                     zstd -dc "$1" > "$extract_dir/${file_name}" || { echo -e "${RED}Extraction failed${RESET}"; rm -rf "$extract_dir"; return 1; }
                     ;;
        *)           echo -e "${RED}'$1' cannot be extracted via extract${RESET}"
                     rm -rf "$extract_dir"
                     return 1 ;;
    esac
    
    # Verify extraction succeeded
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully extracted $1 to $extract_dir${RESET}"
        
        # List extracted contents
        echo -e "${CYAN}Extracted contents:${RESET}"
        ls -la "$extract_dir" | head -n 10
        
        # If more than 10 files, show count
        local file_count=$(ls -la "$extract_dir" | wc -l)
        if [ "$file_count" -gt 10 ]; then
            echo -e "${YELLOW}... and $((file_count-10)) more files${RESET}"
        fi
        
        # Ask if user wants to cd into the extracted directory
        echo -e "${YELLOW}Do you want to cd into the extracted directory? [y/N]${RESET}"
        read -r confirm
        if [[ "$confirm" =~ ^[yY]$ ]]; then
            cd "$extract_dir" || return
        fi
    else
        echo -e "${RED}Failed to extract $1${RESET}"
        rm -rf "$extract_dir"
        return 1
    fi
}

# Create a compressed archive with smart format detection
function compress() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo -e "${YELLOW}Usage: compress <output_file> <input_files/dirs...>${RESET}"
        echo "Example: compress backup.tar.gz file1 file2 dir1"
        echo "Supported formats: .tar.gz, .tar.bz2, .tar.xz, .tar.zst, .tgz, .tbz2, .zip, .7z"
        return 1
    fi
    
    local output="$1"
    shift
    local inputs=("$@")
    
    # Check if all input files/dirs exist
    for input in "${inputs[@]}"; do
        if [ ! -e "$input" ]; then
            echo -e "${RED}Error: '$input' does not exist${RESET}"
            return 1
        fi
    done
    
    # Compress based on output file extension
    echo -e "${YELLOW}Compressing ${inputs[*]} to $output...${RESET}"
    
    case "$output" in
        *.tar.gz|*.tgz)
            command -v tar >/dev/null || { echo -e "${RED}Error: 'tar' command not found${RESET}"; return 1; }
            tar czf "$output" "${inputs[@]}"
            ;;
        *.tar.bz2|*.tbz2)
            command -v tar >/dev/null || { echo -e "${RED}Error: 'tar' command not found${RESET}"; return 1; }
            tar cjf "$output" "${inputs[@]}"
            ;;
        *.tar.xz)
            command -v tar >/dev/null || { echo -e "${RED}Error: 'tar' command not found${RESET}"; return 1; }
            tar cJf "$output" "${inputs[@]}"
            ;;
        *.tar.zst)
            command -v tar >/dev/null || { echo -e "${RED}Error: 'tar' command not found${RESET}"; return 1; }
            command -v zstd >/dev/null || { echo -e "${RED}Error: 'zstd' command not found${RESET}"; return 1; }
            tar --zstd -cf "$output" "${inputs[@]}"
            ;;
        *.zip)
            command -v zip >/dev/null || { echo -e "${RED}Error: 'zip' command not found${RESET}"; return 1; }
            zip -r "$output" "${inputs[@]}"
            ;;
        *.7z)
            command -v 7z >/dev/null || { echo -e "${RED}Error: '7z' command not found${RESET}"; return 1; }
            7z a "$output" "${inputs[@]}"
            ;;
        *)
            echo -e "${RED}Unsupported archive format: $output${RESET}"
            echo "Supported formats: .tar.gz, .tar.bz2, .tar.xz, .tar.zst, .tgz, .tbz2, .zip, .7z"
            return 1
            ;;
    esac
    
    # Verify compression succeeded
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully created $output${RESET}"
        # Show file size
        local archive_size=$(du -h "$output" | cut -f1)
        echo -e "${CYAN}Archive size: ${BOLD}$archive_size${RESET}"
        
        # Show compression ratio
        local original_size=0
        for input in "${inputs[@]}"; do
            if [ -d "$input" ]; then
                original_size=$((original_size + $(du -bs "$input" | cut -f1)))
            else
                original_size=$((original_size + $(stat -c%s "$input" 2>/dev/null || stat -f%z "$input")))
            fi
        done
        local archive_bytes=$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output")
        local ratio=$(echo "scale=2; $original_size / $archive_bytes" | bc 2>/dev/null)
        
        if [ -n "$ratio" ] && [ "$ratio" != "0" ]; then
            echo -e "${CYAN}Compression ratio: ${BOLD}${ratio}x${RESET}"
        fi
    else
        echo -e "${RED}Failed to create $output${RESET}"
        return 1
    fi
}

# ===========================================
# Directory & Path Utilities
# ===========================================

# Make directory and cd into it
function mcd() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: mcd <directory>${RESET}"
        return 1
    fi
    
    mkdir -p "$1"
    if [ $? -eq 0 ]; then
        cd "$1" || return
        echo -e "${GREEN}Created and moved to directory: $1${RESET}"
        ls -a
    else
        echo -e "${RED}Failed to create directory: $1${RESET}"
        return 1
    fi
}

# Quick file backup with timestamp
function backup() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: backup <file_or_directory>${RESET}"
        return 1
    fi
    
    if [ ! -e "$1" ]; then
        echo -e "${RED}Error: File or directory '$1' not found${RESET}"
        return 1
    fi
    
    # Create backup directory if it doesn't exist
    if [ ! -d "$FILE_OP_BACKUP_DIR" ]; then
        mkdir -p "$FILE_OP_BACKUP_DIR"
    fi
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local source_file="$1"
    local source_name=$(basename "$source_file")
    local backup_file=""
    
    if [ -d "$source_file" ]; then
        # It's a directory - create tar archive
        backup_file="$FILE_OP_BACKUP_DIR/${source_name}_$timestamp.tar.gz"
        echo -e "${YELLOW}Creating backup of directory: $source_file${RESET}"
        tar -czf "$backup_file" "$source_file"
    else
        # It's a file - make a copy
        backup_file="$FILE_OP_BACKUP_DIR/${source_name}.$timestamp.bak"
        echo -e "${YELLOW}Creating backup of file: $source_file${RESET}"
        cp -v "$source_file" "$backup_file"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Backup created: $backup_file${RESET}"
        # Show file size
        local backup_size=$(du -h "$backup_file" | cut -f1)
        echo -e "${CYAN}Backup size: ${BOLD}$backup_size${RESET}"
    else
        echo -e "${RED}Failed to create backup${RESET}"
        return 1
    fi
}

# Alias for quick backup
alias bak="backup"

# List backup files
function backup_list() {
    if [ ! -d "$FILE_OP_BACKUP_DIR" ]; then
        echo -e "${YELLOW}Backup directory does not exist: $FILE_OP_BACKUP_DIR${RESET}"
        return 1
    fi
    
    local pattern="$1"
    
    echo -e "${YELLOW}Backups in $FILE_OP_BACKUP_DIR:${RESET}"
    
    if [ -n "$pattern" ]; then
        echo -e "${CYAN}Filtering by: $pattern${RESET}"
        find "$FILE_OP_BACKUP_DIR" -type f -name "*$pattern*" | sort -r | while read -r backup_file; do
            local file_info=$(file -b "$backup_file")
            local file_size=$(du -h "$backup_file" | cut -f1)
            local file_date=$(date -r "$backup_file" +"%Y-%m-%d %H:%M:%S")
            echo -e "${GREEN}$(basename "$backup_file")${RESET} ($file_size, $file_date)"
            echo -e "  ${CYAN}Type: $file_info${RESET}"
        done
    else
        ls -lht "$FILE_OP_BACKUP_DIR" | grep -v "^total" | head -n 20
        
        # Show count if more than 20 files
        local file_count=$(ls -la "$FILE_OP_BACKUP_DIR" | grep -v "^total" | grep -v "^\." | wc -l)
        if [ "$file_count" -gt 20 ]; then
            echo -e "${YELLOW}... and $((file_count-20)) more files${RESET}"
        fi
    fi
}

# Restore a backup file
function backup_restore() {
    if [ ! -d "$FILE_OP_BACKUP_DIR" ]; then
        echo -e "${YELLOW}Backup directory does not exist: $FILE_OP_BACKUP_DIR${RESET}"
        return 1
    fi
    
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: backup_restore <backup_file> [destination]${RESET}"
        echo "Use backup_list to see available backups"
        return 1
    fi
    
    local backup_name="$1"
    local backup_file=""
    
    # Check if file exists directly
    if [ -f "$FILE_OP_BACKUP_DIR/$backup_name" ]; then
        backup_file="$FILE_OP_BACKUP_DIR/$backup_name"
    else
        # Try to find the file by pattern
        backup_file=$(find "$FILE_OP_BACKUP_DIR" -type f -name "*$backup_name*" | head -n 1)
        
        if [ -z "$backup_file" ]; then
            echo -e "${RED}Error: Backup file not found: $backup_name${RESET}"
            echo "Use backup_list to see available backups"
            return 1
        fi
    fi
    
    local destination="$2"
    local is_archive=0
    
    # Check if the backup is an archive
    if [[ "$backup_file" == *.tar.gz || "$backup_file" == *.tgz ]]; then
        is_archive=1
    fi
    
    # Determine destination
    if [ -z "$destination" ]; then
        if [ $is_archive -eq 1 ]; then
            # For archives, extract to current directory
            destination="."
        else
            # For regular files, extract to basename without timestamp
            local base_name=$(basename "$backup_file")
            # Remove timestamp pattern and .bak extension
            destination="${base_name%%.*}"
        fi
    fi
    
    # Restore the backup
    if [ $is_archive -eq 1 ]; then
        echo -e "${YELLOW}Extracting archive to $destination...${RESET}"
        if [ ! -d "$destination" ]; then
            mkdir -p "$destination"
        fi
        tar -xzf "$backup_file" -C "$destination"
    else
        echo -e "${YELLOW}Restoring file to $destination...${RESET}"
        cp -v "$backup_file" "$destination"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Backup restored successfully to: $destination${RESET}"
    else
        echo -e "${RED}Failed to restore backup${RESET}"
        return 1
    fi
}

# File comparison with highlights
function fcompare() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo -e "${RED}Usage: fcompare <file1> <file2>${RESET}"
        return 1
    fi
    
    if [ ! -f "$1" ]; then
        echo -e "${RED}Error: File '$1' not found or is not a regular file${RESET}"
        return 1
    fi
    
    if [ ! -f "$2" ]; then
        echo -e "${RED}Error: File '$2' not found or is not a regular file${RESET}"
        return 1
    fi
    
    echo -e "${YELLOW}Comparing $1 and $2...${RESET}"
    
    # Check if files are binary
    if file "$1" | grep -q "binary"; then
        echo -e "${YELLOW}Warning: '$1' appears to be a binary file${RESET}"
    fi
    
    if file "$2" | grep -q "binary"; then
        echo -e "${YELLOW}Warning: '$2' appears to be a binary file${RESET}"
    fi
    
    # Use appropriate diff tool
    if command -v colordiff &> /dev/null; then
        colordiff -u "$1" "$2" | less -R
    elif command -v icdiff &> /dev/null; then
        icdiff "$1" "$2" | less -R
    else
        diff -u "$1" "$2" | less -R
    fi
}

# Show directory sizes in human readable format
function dirsize() {
    echo -e "${YELLOW}Directory sizes:${RESET}"
    
    if [ -z "$1" ]; then
        du -sh ./* 2>/dev/null | sort -h
    else
        du -sh "$@" | sort -h
    fi
}

# Enhanced temporary directory function
function cdtemp() {
    local tempdir=$(mktemp -d)
    cd "$tempdir" || return
    echo -e "${GREEN}Created and moved to temporary directory: $tempdir${RESET}"
    echo "This directory will be deleted when you exit unless you save your work elsewhere."
    echo "Type 'exit_temp' to leave and delete this directory."
    
    # Create a function to cleanup when done
    function exit_temp() {
        local current_dir="$PWD"
        cd .. || return
        
        echo -e "${YELLOW}Do you want to delete the temporary directory? [Y/n]${RESET}"
        read -r confirm
        
        if [[ ! "$confirm" =~ ^[nN]$ ]]; then
            rm -rf "$current_dir"
            echo -e "${GREEN}Temporary directory deleted: $current_dir${RESET}"
            unset -f exit_temp
        else
            echo -e "${YELLOW}Temporary directory kept: $current_dir${RESET}"
            unset -f exit_temp
        fi
    }
}

# ===========================================
# File Content Manipulation
# ===========================================

# Find and delete files matching pattern with trash support
function fdelete() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: fdelete <pattern>${RESET}"
        echo "Example: fdelete '*.tmp'"
        return 1
    fi
    
    echo -e "${YELLOW}Finding files matching pattern: $1${RESET}"
    
    local files=($(find . -name "$1" -type f))
    local count=${#files[@]}
    
    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}No files found matching pattern: $1${RESET}"
        return 0
    fi
    
    echo -e "${YELLOW}Found $count files:${RESET}"
    for file in "${files[@]}"; do
        echo "$file"
    done
    
    echo
    echo -e "${YELLOW}Do you want to: [t]rash these files, [d]elete permanently, or [c]ancel? [t/d/C]${RESET}"
    read -r action
    
    case "$action" in
        [tT])
            # Initialize trash if needed
            _init_trash_dir
            echo -e "${CYAN}Moving files to trash...${RESET}"
            for file in "${files[@]}"; do
                trash "$file"
            done
            echo -e "${GREEN}Moved $count files to trash${RESET}"
            ;;
        [dD])
            echo -e "${RED}WARNING: This will permanently delete these files. Are you sure? [y/N]${RESET}"
            read -r confirm
            
            if [[ "$confirm" =~ ^[yY]$ ]]; then
                echo -e "${RED}Deleting files...${RESET}"
                find . -name "$1" -type f -delete
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Successfully deleted $count files.${RESET}"
                else
                    echo -e "${RED}Error occurred while deleting files.${RESET}"
                    return 1
                fi
            else
                echo -e "${YELLOW}Operation cancelled.${RESET}"
            fi
            ;;
        *)
            echo -e "${YELLOW}Operation cancelled.${RESET}"
            ;;
    esac
}

# Find and replace text in files
function freplace() {
    if [ $# -lt 2 ]; then
        echo -e "${RED}Usage: freplace 'pattern' 'replacement' [file_pattern]${RESET}"
        echo "Examples:"
        echo "  freplace 'foo' 'bar'           # Replace in all text files"
        echo "  freplace 'foo' 'bar' '*.txt'   # Replace only in .txt files"
        echo "  freplace 'foo' 'bar' '*.{txt,md}' # Replace in txt and md files"
        return 1
    fi
    
    local pattern="$1"
    local replacement="$2"
    local file_pattern=${3:-"*.{txt,md,html,css,js,py,java,c,cpp,h,hpp,sh,json,xml,yml,yaml}"}
    
    # Safety check - preview changes
    echo -e "${YELLOW}Preview of changes (replacing '$pattern' with '$replacement' in $file_pattern):${RESET}"
    
    # Find matching files
    local matching_files=($(find . -type f -name "$file_pattern" -not -path "*/\.*" -not -path "*/node_modules/*" -not -path "*/venv/*" 2>/dev/null))
    
    if [ ${#matching_files[@]} -eq 0 ]; then
        echo -e "${RED}No matching files found${RESET}"
        return 1
    fi
    
    echo -e "${GREEN}Found ${#matching_files[@]} potentially matching files${RESET}"
    
    # Find files that actually contain the pattern
    local files_with_matches=()
    for file in "${matching_files[@]}"; do
        if grep -q "$pattern" "$file" 2>/dev/null; then
            files_with_matches+=("$file")
        fi
    done
    
    if [ ${#files_with_matches[@]} -eq 0 ]; then
        echo -e "${YELLOW}Pattern '$pattern' not found in any files${RESET}"
        return 0
    fi
    
    echo -e "${GREEN}Found ${#files_with_matches[@]} files containing the pattern${RESET}"
    
    # Show preview of first few files
    local preview_count=$(( ${#files_with_matches[@]} < 5 ? ${#files_with_matches[@]} : 5 ))
    for ((i=0; i<preview_count; i++)); do
        local file="${files_with_matches[$i]}"
        echo -e "${CYAN}$file:${RESET}"
        grep --color=always -n "$pattern" "$file" 2>/dev/null | head -n 3
        echo
    done
    
    if [ ${#files_with_matches[@]} -gt 5 ]; then
        echo -e "${YELLOW}... and $((${#files_with_matches[@]} - 5)) more files${RESET}"
    fi
    
    echo -e "${YELLOW}Do you want to proceed with replacement? [y/N]${RESET}"
    read -r confirm
    
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        echo -e "${GREEN}Replacing '$pattern' with '$replacement'...${RESET}"
        
        # Create a backup before making changes
        echo -e "${YELLOW}Create a backup before proceeding? [Y/n]${RESET}"
        read -r backup_confirm
        
        if [[ ! "$backup_confirm" =~ ^[nN]$ ]]; then
            local timestamp=$(date +"%Y%m%d_%H%M%S")
            local backup_dir="$FILE_OP_BACKUP_DIR/freplace_$timestamp"
            mkdir -p "$backup_dir"
            
            for file in "${files_with_matches[@]}"; do
                local dir_structure=$(dirname "$file")
                mkdir -p "$backup_dir/$dir_structure"
                cp "$file" "$backup_dir/$file"
            done
            
            echo -e "${GREEN}Backup created at: $backup_dir${RESET}"
        fi
        
        local count=0
        for file in "${files_with_matches[@]}"; do
            sed -i "s/$pattern/$replacement/g" "$file"
            ((count++))
        done
        
        echo -e "${GREEN}Done! Modified $count files.${RESET}"
    else
        echo -e "${YELLOW}Operation cancelled${RESET}"
    fi
}

# Function to get file encoding
function fencoding() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: fencoding <file>${RESET}"
        return 1
    fi

    if [ ! -f "$1" ]; then
        echo -e "${RED}Error: File '$1' not found${RESET}"
        return 1
    fi
    
    if command -v file &> /dev/null; then
        echo -e "${YELLOW}File encoding for '$1':${RESET}"
        file -i "$1"
        
        if command -v chardet &> /dev/null; then
            echo -e "${YELLOW}Detailed encoding analysis:${RESET}"
            chardet "$1"
        elif command -v iconv &> /dev/null; then
            echo -e "${YELLOW}Available encodings for conversion:${RESET}"
            iconv -l | head -n 5
            echo "... (use 'iconv -l' to see all)"
        fi
    else
        echo -e "${RED}Error: 'file' command not found${RESET}"
    fi
}

# Function to convert file encoding
function fconvert() {
    if [ $# -lt 3 ]; then
        echo -e "${RED}Usage: fconvert <input_file> <from_encoding> <to_encoding> [output_file]${RESET}"
        echo "Example: fconvert myfile.txt ISO-8859-1 UTF-8 myfile_utf8.txt"
        return 1
    fi
    
    local input_file="$1"
    local from_encoding="$2"
    local to_encoding="$3"
    local output_file="${4:-${input_file}.${to_encoding}}"
    
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}Error: Input file '$input_file' not found${RESET}"
        return 1
    fi
    
    if command -v iconv &> /dev/null; then
        echo -e "${YELLOW}Converting '$input_file' from $from_encoding to $to_encoding...${RESET}"
        iconv -f "$from_encoding" -t "$to_encoding" "$input_file" > "$output_file"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Conversion successful. Output saved to '$output_file'${RESET}"
        else
            echo -e "${RED}Conversion failed${RESET}"
            return 1
        fi
    else
        echo -e "${RED}Error: 'iconv' command not found${RESET}"
        return 1
    fi
}

# Function to batch rename files
function rename_batch() {
    if [ $# -lt 2 ]; then
        echo -e "${RED}Usage: rename_batch <pattern> <replacement> [files...]${RESET}"
        echo "Examples:"
        echo "  rename_batch 'IMG_' 'Photo_' *.jpg            # Replace prefix in all JPG files"
        echo "  rename_batch '.JPG' '.jpg' *.JPG             # Convert extension to lowercase"
        echo "  rename_batch ' ' '_' *                      # Replace spaces with underscores"
        return 1
    fi
    
    local pattern="$1"
    local replacement="$2"
    shift 2
    
    # No files specified, show error
    if [ $# -eq 0 ]; then
        echo -e "${RED}Error: No files specified${RESET}"
        return 1
    fi
    
    echo -e "${YELLOW}Preview of renames (replacing '$pattern' with '$replacement'):${RESET}"
    
    local preview_changes=()
    local has_changes=0
    
    # Generate preview
    for file in "$@"; do
        if [ ! -e "$file" ]; then
            echo -e "${RED}Warning: '$file' does not exist, skipping${RESET}"
            continue
        fi
        
        local new_name="${file//$pattern/$replacement}"
        
        if [ "$file" != "$new_name" ]; then
            echo -e "${CYAN}$file${RESET} → ${GREEN}$new_name${RESET}"
            preview_changes+=("$file|$new_name")
            has_changes=1
        fi
    done
    
    if [ $has_changes -eq 0 ]; then
        echo -e "${YELLOW}No files would be renamed with the given pattern${RESET}"
        return 0
    fi
    
    # Ask for confirmation
    echo
    echo -e "${YELLOW}Proceed with renaming? [y/N]${RESET}"
    read -r confirm
    
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        echo -e "${GREEN}Renaming files...${RESET}"
        
        local rename_count=0
        local error_count=0
        
        for change in "${preview_changes[@]}"; do
            local old_name="${change%%|*}"
            local new_name="${change##*|}"
            
            # Check if target already exists
            if [ -e "$new_name" ] && [ "$old_name" != "$new_name" ]; then
                echo -e "${RED}Error: Cannot rename '$old_name' to '$new_name', target already exists${RESET}"
                error_count=$((error_count + 1))
                continue
            fi
            
            mv -v "$old_name" "$new_name"
            
            if [ $? -eq 0 ]; then
                rename_count=$((rename_count + 1))
            else
                error_count=$((error_count + 1))
            fi
        done
        
        echo -e "${GREEN}Renamed $rename_count file(s) successfully${RESET}"
        if [ $error_count -gt 0 ]; then
            echo -e "${RED}Failed to rename $error_count file(s)${RESET}"
        fi
    else
        echo -e "${YELLOW}Operation cancelled${RESET}"
    fi
}

# Aliases for file operations
alias extract="extract"
alias compress="compress"
alias rename="rename_batch"
alias dirsize="dirsize"
alias compare="fcompare"
alias bakls="backup_list"
alias bakrest="backup_restore"

# Register this module's health check function
function _file_operations_sh_health_check() {
    # Check if backup directory exists or can be created
    if [ ! -d "$FILE_OP_BACKUP_DIR" ]; then
        if ! mkdir -p "$FILE_OP_BACKUP_DIR" 2>/dev/null; then
            echo -e "${YELLOW}Warning: Unable to create backup directory: $FILE_OP_BACKUP_DIR${RESET}"
            return 1
        fi
        rmdir "$FILE_OP_BACKUP_DIR" 2>/dev/null
    fi
    
    # Check if trash directory exists or can be created
    if [ ! -d "$FILE_OP_TRASH_DIR" ]; then
        if ! mkdir -p "$FILE_OP_TRASH_DIR" 2>/dev/null; then
            echo -e "${YELLOW}Warning: Unable to create trash directory: $FILE_OP_TRASH_DIR${RESET}"
            return 1
        fi
        rmdir "$FILE_OP_TRASH_DIR" 2>/dev/null
    fi
    
    # Check for required commands
    local missing_commands=()
    for cmd in tar gzip bzip2 find grep sed; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        echo -e "${YELLOW}Warning: Some recommended utilities are missing: ${missing_commands[*]}${RESET}"
        echo -e "${YELLOW}Some features may not work correctly.${RESET}"
    fi
    
    return 0
}

# Output module load message if verbose
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}Loaded: ${BOLD}Advanced File Operations Module${RESET} (v1.1)"
fi
