#!/bin/bash
# ===========================================
# Advanced File Operations
# ===========================================
# Robust file management functions with safety checks and intuitive interfaces
# Author: Claude & Me
# Version: 1.0
# Last Updated: 2025-05-14

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
            exa -a
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
    echo -e "${YELLOW}Files modified in the last $days days:${RESET}"
    find . -type f -mtime -"$days" -not -path "*/\.*" -not -path "*/node_modules/*" -not -path "*/venv/*" | sort -r | head -n "$count"
}

# ===========================================
# Archive Management Functions
# ===========================================

# Extract various archive formats with error checking
function extract() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: extract <file>${RESET}"
        echo "Supports: .tar.bz2, .tar.gz, .bz2, .rar, .gz, .tar, .tbz2, .tgz, .zip, .Z, .7z"
        return 1
    fi
    
    if [ ! -f "$1" ]; then
        echo -e "${RED}'$1' is not a valid file${RESET}"
        return 1
    fi
    
    # Extract based on file extension
    echo -e "${YELLOW}Extracting: $1${RESET}"
    
    case "$1" in
        *.tar.bz2)   command -v tar >/dev/null || { echo -e "${RED}Error: 'tar' command not found${RESET}"; return 1; }
                     echo "Extracting tar.bz2 archive..."
                     tar xjf "$1" ;;
        *.tar.gz)    command -v tar >/dev/null || { echo -e "${RED}Error: 'tar' command not found${RESET}"; return 1; }
                     echo "Extracting tar.gz archive..."
                     tar xzf "$1" ;;
        *.bz2)       command -v bunzip2 >/dev/null || { echo -e "${RED}Error: 'bunzip2' command not found${RESET}"; return 1; }
                     echo "Extracting bz2 archive..."
                     bunzip2 "$1" ;;
        *.rar)       command -v unrar >/dev/null || { echo -e "${RED}Error: 'unrar' command not found${RESET}"; return 1; }
                     echo "Extracting rar archive..."
                     unrar e "$1" ;;
        *.gz)        command -v gunzip >/dev/null || { echo -e "${RED}Error: 'gunzip' command not found${RESET}"; return 1; }
                     echo "Extracting gz archive..."
                     gunzip "$1" ;;
        *.tar)       command -v tar >/dev/null || { echo -e "${RED}Error: 'tar' command not found${RESET}"; return 1; }
                     echo "Extracting tar archive..."
                     tar xf "$1" ;;
        *.tbz2)      command -v tar >/dev/null || { echo -e "${RED}Error: 'tar' command not found${RESET}"; return 1; }
                     echo "Extracting tbz2 archive..."
                     tar xjf "$1" ;;
        *.tgz)       command -v tar >/dev/null || { echo -e "${RED}Error: 'tar' command not found${RESET}"; return 1; }
                     echo "Extracting tgz archive..."
                     tar xzf "$1" ;;
        *.zip)       command -v unzip >/dev/null || { echo -e "${RED}Error: 'unzip' command not found${RESET}"; return 1; }
                     echo "Extracting zip archive..."
                     unzip "$1" ;;
        *.Z)         command -v uncompress >/dev/null || { echo -e "${RED}Error: 'uncompress' command not found${RESET}"; return 1; }
                     echo "Extracting Z archive..."
                     uncompress "$1" ;;
        *.7z)        command -v 7z >/dev/null || { echo -e "${RED}Error: '7z' command not found${RESET}"; return 1; }
                     echo "Extracting 7z archive..."
                     7z x "$1" ;;
        *)           echo -e "${RED}'$1' cannot be extracted via extract${RESET}"
                     return 1 ;;
    esac
    
    # Verify extraction succeeded
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully extracted $1${RESET}"
        
        # List extracted contents
        local extracted_dir
        case "$1" in
            *.tar.bz2|*.tar.gz|*.tbz2|*.tgz|*.tar)
                extracted_dir=$(tar -tf "$1" | grep -o '^[^/]\+' | sort -u | head -1)
                ;;
            *.zip)
                extracted_dir=$(unzip -l "$1" | awk '{print $4}' | grep -o '^[^/]\+' | sort -u | head -1)
                ;;
            *.7z)
                extracted_dir=$(7z l "$1" | grep -o '^[^/]\+' | sort -u | head -1)
                ;;
            *)
                extracted_dir=$(echo "$1" | sed 's/\.[^.]*$//')
                ;;
        esac
        
        # Show extraction summary
        if [ -d "$extracted_dir" ]; then
            echo -e "${CYAN}Extracted to directory: ${BOLD}$extracted_dir${RESET}"
            echo -e "${YELLOW}Contents:${RESET}"
            ls -la "$extracted_dir" | head -n 10
            
            # If more than 10 files, show count
            local file_count=$(ls -la "$extracted_dir" | wc -l)
            if [ "$file_count" -gt 10 ]; then
                echo -e "${YELLOW}... and $((file_count-10)) more files${RESET}"
            fi
            
            # Ask if user wants to cd into the extracted directory
            echo -e "${YELLOW}Do you want to cd into the extracted directory? [y/N]${RESET}"
            read -r confirm
            if [[ "$confirm" =~ ^[yY]$ ]]; then
                cd "$extracted_dir" || return
            fi
        else
            echo -e "${CYAN}Extracted files:${RESET}"
            ls -la | head -n 10
        fi
    else
        echo -e "${RED}Failed to extract $1${RESET}"
        return 1
    fi
}

# Create a compressed archive with smart format detection
function compress() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo -e "${YELLOW}Usage: compress <output_file> <input_files/dirs...>${RESET}"
        echo "Example: compress backup.tar.gz file1 file2 dir1"
        echo "Supported formats: .tar.gz, .tar.bz2, .tgz, .tbz2, .zip, .7z"
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
            echo "Supported formats: .tar.gz, .tar.bz2, .tgz, .tbz2, .zip, .7z"
            return 1
            ;;
    esac
    
    # Verify compression succeeded
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully created $output${RESET}"
        # Show file size
        local archive_size=$(du -h "$output" | cut -f1)
        echo -e "${CYAN}Archive size: ${BOLD}$archive_size${RESET}"
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
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    
    if [ -d "$1" ]; then
        # It's a directory - create tar archive
        local backup_file="$1_$timestamp.tar.gz"
        echo -e "${YELLOW}Creating backup of directory: $1${RESET}"
        tar -czf "$backup_file" "$1"
    else
        # It's a file - make a copy
        local backup_file="$1.$timestamp.bak"
        echo -e "${YELLOW}Creating backup of file: $1${RESET}"
        cp -v "$1" "$backup_file"
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
    
    if command -v colordiff &> /dev/null; then
        colordiff -u "$1" "$2" | less -R
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

# Find and delete files matching pattern
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
    echo -e "${RED}WARNING: This will permanently delete these files. Continue? [y/N]${RESET}"
    read -r confirm
    
    if [[ "$confirm" =~ ^[yY]$ ]]; then
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

# Output module load message if verbose
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}Loaded: ${BOLD}Advanced File Operations Module${RESET}"
fi
