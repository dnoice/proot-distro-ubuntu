#!/bin/bash
# ===========================================
# Prompt Configuration
# ===========================================
# A customizable, informative prompt with git integration, error codes, and visual enhancements
# Author: Claude & You
# Version: 1.0
# Last Updated: 2025-05-14

# ===========================================
# Git Integration Functions
# ===========================================

# Git branch function with caching for improved performance
function parse_git_branch() {
    local branch
    # Check if we're in a git repo
    if [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1; then
        # Cache the branch name to improve performance
        if [ -z "$CACHED_GIT_BRANCH" ] || [ "$CACHED_GIT_TIMER" -lt $(date +%s) ]; then
            branch=$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')
            CACHED_GIT_BRANCH="$branch"
            # Cache for 5 seconds
            CACHED_GIT_TIMER=$(($(date +%s) + 5))
        else
            branch="$CACHED_GIT_BRANCH"
        fi
        echo "$branch"
    fi
}

# Git status function with caching and ASCII symbols for better compatibility
function parse_git_status() {
    # Check if we're in a git repo
    if [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1; then
        # Cache the status to improve performance
        if [ -z "$CACHED_GIT_STATUS" ] || [ "$CACHED_GIT_STATUS_TIMER" -lt $(date +%s) ]; then
            local status=$(git status --porcelain 2> /dev/null)
            if [[ -z $status ]]; then
                CACHED_GIT_STATUS="clean"
            else
                CACHED_GIT_STATUS="dirty"
            fi
            # Cache for 5 seconds
            CACHED_GIT_STATUS_TIMER=$(($(date +%s) + 5))
        fi
        
        if [[ "$CACHED_GIT_STATUS" == "clean" ]]; then
            echo "+"  # Using + for clean status (more compatible than checkmark)
        else
            echo "*"  # Using * for dirty status (more compatible than X)
        fi
    fi
}

# Detect stashed changes with caching for better performance
function parse_git_stash() {
    # Check if we're in a git repo
    if [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1; then
        # Cache the stash info to improve performance
        if [ -z "$CACHED_GIT_STASH" ] || [ "$CACHED_GIT_STASH_TIMER" -lt $(date +%s) ]; then
            local stash_count=$(git stash list 2>/dev/null | wc -l)
            CACHED_GIT_STASH="$stash_count"
            # Cache for 30 seconds (stash changes less frequently)
            CACHED_GIT_STASH_TIMER=$(($(date +%s) + 30))
        else
            stash_count="$CACHED_GIT_STASH"
        fi
        
        if [[ "$stash_count" -gt 0 ]]; then
            echo "$stash_count stash"
        fi
    fi
}

# Count unpushed commits with caching
function parse_git_unpushed() {
    # Check if we're in a git repo
    if [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1; then
        # Cache the unpushed info to improve performance
        if [ -z "$CACHED_GIT_UNPUSHED" ] || [ "$CACHED_GIT_UNPUSHED_TIMER" -lt $(date +%s) ]; then
            # Check if there's a remote branch to compare with
            if git rev-parse --abbrev-ref @{upstream} >/dev/null 2>&1; then
                local unpushed=$(git log @{upstream}..HEAD --oneline 2>/dev/null | wc -l)
                CACHED_GIT_UNPUSHED="$unpushed"
            else
                CACHED_GIT_UNPUSHED="0"
            fi
            # Cache for 10 seconds
            CACHED_GIT_UNPUSHED_TIMER=$(($(date +%s) + 10))
        else
            unpushed="$CACHED_GIT_UNPUSHED"
        fi
        
        if [[ "$unpushed" -gt 0 ]]; then
            echo "$unpushed↑"  # Arrow up indicates commits to push
        fi
    fi
}

# ===========================================
# Environment Detection Functions
# ===========================================

# Virtual environment function
function parse_venv() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo "($(basename "$VIRTUAL_ENV")) "
    fi
}

# Docker container detection
function parse_docker() {
    if [ -f /.dockerenv ]; then
        echo "[🐳] "
    fi
}

# Detect if in SSH session
function parse_ssh() {
    if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
        echo "[SSH] "
    fi
}

# Detect shared storage access (specific to Termux/proot setup)
function parse_storage() {
    if [[ "$PWD" == *"sdcard"* ]]; then
        echo "[📱 shared] "
    fi
}

# ===========================================
# Prompt Setup
# ===========================================

# Better handling of prompt command with error trapping
trap 'export PREV_EXIT_CODE=$?' DEBUG

# Set custom prompt with all the features
function set_prompt() {
    local EXIT="${PREV_EXIT_CODE:-0}"
    PS1=""

    # Add chroot information if available
    PS1+="${debian_chroot:+($debian_chroot)}"

    # Add error code if previous command failed
    if [ $EXIT != 0 ]; then
        PS1+="${BOLD_RED}[$EXIT] ${RESET}"
    fi

    # Show timestamp if enabled
    if [[ "$PROMPT_SHOW_TIME" == "1" ]]; then
        PS1+="${CYAN}$(date +%H:%M) ${RESET}"
    fi

    # User and hostname - use different colors for root
    if [[ $EUID -eq 0 ]]; then
        PS1+="${BOLD_RED}\u${RESET}@${GREEN}\h${RESET}"
    else  
        PS1+="${CYAN}\u${RESET}@${GREEN}\h${RESET}"
    fi

    # SSH indicator
    PS1+=" $(parse_ssh)"
    
    # Docker indicator
    PS1+="$(parse_docker)"

    # Current directory (full path, with ~ for home)
    PS1+=" ${BLUE}\w${RESET}"

    # Shared storage indicator
    PS1+=" $(parse_storage)"

    # Git information if available
    local git_branch=$(parse_git_branch)
    if [[ -n "$git_branch" ]]; then
        local git_status=$(parse_git_status)
        PS1+=" ${YELLOW}(${git_branch}${RESET}"
        if [[ "$git_status" == "+" ]]; then
            PS1+=" ${GREEN}${git_status}${RESET}"
        else
            PS1+=" ${RED}${git_status}${RESET}"
        fi
        
        # Add stash information if any
        local git_stash=$(parse_git_stash)
        if [[ -n "$git_stash" ]]; then
            PS1+=" ${PURPLE}${git_stash}${RESET}"
        fi
        
        # Add unpushed commit information if any
        local git_unpushed=$(parse_git_unpushed)
        if [[ -n "$git_unpushed" ]]; then
            PS1+=" ${YELLOW}${git_unpushed}${RESET}"
        fi
        
        PS1+="${YELLOW})${RESET}"
    fi

    # Virtual environment indicator
    PS1+=" ${PURPLE}$(parse_venv)${RESET}"

    # Show jobs count if any running
    if [ $(jobs -p | wc -l) -gt 0 ]; then
        PS1+=" ${YELLOW}[$(jobs -p | wc -l) jobs]${RESET}"
    fi

    # New line and prompt symbol (# for root, $ for others)
    PS1+="\n"
    if [[ $EUID -eq 0 ]]; then
        PS1+="${BOLD_RED}# ${RESET}"
    else
        PS1+="${BOLD_GREEN}\$ ${RESET}"
    fi
}

# Enable time in prompt option (default: off)
PROMPT_SHOW_TIME=0

# Function to toggle timestamp display in prompt
function toggle_prompt_time() {
    if [[ "$PROMPT_SHOW_TIME" == "0" ]]; then
        PROMPT_SHOW_TIME=1
        echo -e "${GREEN}Prompt will now show timestamps${RESET}"
    else
        PROMPT_SHOW_TIME=0
        echo -e "${GREEN}Prompt will no longer show timestamps${RESET}"
    fi
}

# Set alias for toggling prompt time
alias ptime="toggle_prompt_time"

# Set the prompt command to update PS1 before each command
PROMPT_COMMAND="set_prompt"

# Output module load message if verbose
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}Loaded: ${BOLD}Enhanced Prompt Module${RESET}"
fi
