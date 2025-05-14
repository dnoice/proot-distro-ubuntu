#!/bin/bash
# ===========================================
# Prompt Configuration
# ===========================================
# A customizable, informative prompt with git integration, error codes, and visual enhancements
# Author: Claude & Me
# Version: 1.1
# Last Updated: 2025-05-14

# ===========================================
# Prompt Configuration Options
# ===========================================

# User-configurable prompt features
PROMPT_SHOW_TIME=${PROMPT_SHOW_TIME:-0}       # Show timestamp in prompt (0=off, 1=on)
PROMPT_SHOW_HOST=${PROMPT_SHOW_HOST:-1}       # Show hostname in prompt (0=off, 1=on)
PROMPT_STYLE=${PROMPT_STYLE:-"fancy"}         # Prompt style (fancy, minimal, plain)
PROMPT_GIT_ENABLE=${PROMPT_GIT_ENABLE:-1}     # Enable Git integration (0=off, 1=on)
PROMPT_GIT_CACHE_TIMEOUT=${PROMPT_GIT_CACHE_TIMEOUT:-5}  # Git cache timeout in seconds
PROMPT_COMMAND_TIME=${PROMPT_COMMAND_TIME:-0} # Show execution time of last command (0=off, 1=on)
PROMPT_NEWLINE=${PROMPT_NEWLINE:-1}           # Add newline before prompt (0=off, 1=on)

# ===========================================
# Terminal Color Detection
# ===========================================

# Automatically detect if terminal supports colors
if [ -t 1 ]; then
    TERM_COLORS=$(tput colors 2>/dev/null || echo 0)
    if [ -n "$TERM_COLORS" ] && [ "$TERM_COLORS" -ge 8 ]; then
        PROMPT_USE_COLORS=1
    else
        PROMPT_USE_COLORS=0
    fi
else
    PROMPT_USE_COLORS=0
fi

# ===========================================
# Git Integration Functions
# ===========================================

# Time-based cache system for Git operations
declare -gA PROMPT_GIT_CACHE
declare -gA PROMPT_GIT_CACHE_TIMESTAMP

# Git branch function with caching for improved performance
function parse_git_branch() {
    local branch
    # Check if we're in a git repo
    if [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1; then
        # Check if branch is already cached and cache is still valid
        local current_time
        current_time=$(date +%s)
        local cache_key="branch:$PWD"
        
        if [[ -n "${PROMPT_GIT_CACHE[$cache_key]}" && 
              -n "${PROMPT_GIT_CACHE_TIMESTAMP[$cache_key]}" && 
              $((current_time - PROMPT_GIT_CACHE_TIMESTAMP[$cache_key])) -lt $PROMPT_GIT_CACHE_TIMEOUT ]]; then
            # Return cached value
            echo "${PROMPT_GIT_CACHE[$cache_key]}"
            return
        fi
        
        # Cache miss or expired - get fresh data
        branch=$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')
        PROMPT_GIT_CACHE["$cache_key"]="$branch"
        PROMPT_GIT_CACHE_TIMESTAMP["$cache_key"]=$current_time
        echo "$branch"
    fi
}

# Git status function with caching and ASCII symbols for better compatibility
function parse_git_status() {
    # Check if we're in a git repo
    if [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1; then
        # Check cache
        local current_time
        current_time=$(date +%s)
        local cache_key="status:$PWD"
        
        if [[ -n "${PROMPT_GIT_CACHE[$cache_key]}" && 
              -n "${PROMPT_GIT_CACHE_TIMESTAMP[$cache_key]}" && 
              $((current_time - PROMPT_GIT_CACHE_TIMESTAMP[$cache_key])) -lt $PROMPT_GIT_CACHE_TIMEOUT ]]; then
            # Return cached value
            echo "${PROMPT_GIT_CACHE[$cache_key]}"
            return
        fi
        
        # Cache miss or expired - get fresh data
        local status=$(git status --porcelain 2> /dev/null)
        local result
        
        if [[ -z $status ]]; then
            result="+"  # Using + for clean status (more compatible than checkmark)
        else
            result="*"  # Using * for dirty status (more compatible than X)
        fi
        
        PROMPT_GIT_CACHE["$cache_key"]="$result"
        PROMPT_GIT_CACHE_TIMESTAMP["$cache_key"]=$current_time
        echo "$result"
    fi
}

# Detect stashed changes with caching for better performance
function parse_git_stash() {
    # Check if we're in a git repo
    if [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1; then
        # Check cache
        local current_time
        current_time=$(date +%s)
        local cache_key="stash:$PWD"
        
        if [[ -n "${PROMPT_GIT_CACHE[$cache_key]}" && 
              -n "${PROMPT_GIT_CACHE_TIMESTAMP[$cache_key]}" && 
              $((current_time - PROMPT_GIT_CACHE_TIMESTAMP[$cache_key])) -lt $((PROMPT_GIT_CACHE_TIMEOUT * 3)) ]]; then
            # Return cached value (stashes change less frequently, so use longer timeout)
            echo "${PROMPT_GIT_CACHE[$cache_key]}"
            return
        fi
        
        # Cache miss or expired - get fresh data
        local stash_count=$(git stash list 2>/dev/null | wc -l)
        local result=""
        
        if [[ "$stash_count" -gt 0 ]]; then
            result="$stash_count stash"
        fi
        
        PROMPT_GIT_CACHE["$cache_key"]="$result"
        PROMPT_GIT_CACHE_TIMESTAMP["$cache_key"]=$current_time
        echo "$result"
    fi
}

# Count unpushed commits with caching
function parse_git_unpushed() {
    # Check if we're in a git repo
    if [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1; then
        # Check cache
        local current_time
        current_time=$(date +%s)
        local cache_key="unpushed:$PWD"
        
        if [[ -n "${PROMPT_GIT_CACHE[$cache_key]}" && 
              -n "${PROMPT_GIT_CACHE_TIMESTAMP[$cache_key]}" && 
              $((current_time - PROMPT_GIT_CACHE_TIMESTAMP[$cache_key])) -lt $((PROMPT_GIT_CACHE_TIMEOUT * 2)) ]]; then
            # Return cached value (unpushed changes slightly less frequently)
            echo "${PROMPT_GIT_CACHE[$cache_key]}"
            return
        fi
        
        # Cache miss or expired - get fresh data
        local result=""
        
        # Check if there's a remote branch to compare with
        if git rev-parse --abbrev-ref @{upstream} >/dev/null 2>&1; then
            local unpushed=$(git log @{upstream}..HEAD --oneline 2>/dev/null | wc -l)
            if [[ "$unpushed" -gt 0 ]]; then
                result="$unpushed↑"  # Arrow up indicates commits to push
            fi
        fi
        
        PROMPT_GIT_CACHE["$cache_key"]="$result"
        PROMPT_GIT_CACHE_TIMESTAMP["$cache_key"]=$current_time
        echo "$result"
    fi
}

# Function to clear git caches when needed (e.g., after git operations)
function clear_git_cache() {
    # Delete all caches for the current directory
    local cache_pattern=":$PWD"
    for key in "${!PROMPT_GIT_CACHE[@]}"; do
        if [[ "$key" == *"$cache_pattern" ]]; then
            unset "PROMPT_GIT_CACHE[$key]"
            unset "PROMPT_GIT_CACHE_TIMESTAMP[$key]"
        fi
    done
}

# ===========================================
# Environment Detection Functions
# ===========================================

# Virtual environment function
function parse_venv() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        local venv_name=$(basename "$VIRTUAL_ENV")
        echo "($venv_name) "
    elif [[ -n "$CONDA_DEFAULT_ENV" && "$CONDA_DEFAULT_ENV" != "base" ]]; then
        echo "(conda:$CONDA_DEFAULT_ENV) "
    fi
}

# Docker container detection
function parse_docker() {
    if [ -f /.dockerenv ] || grep -q docker /proc/self/cgroup 2>/dev/null; then
        echo "[🐳] "
    fi
}

# Kubernetes namespace detection
function parse_kubernetes() {
    if [ -n "$KUBERNETES_NAMESPACE" ] || [ -n "$KUBE_NAMESPACE" ]; then
        local k8s_ns="${KUBERNETES_NAMESPACE:-$KUBE_NAMESPACE}"
        echo "[k8s:$k8s_ns] "
    elif [ -f "$HOME/.kube/config" ] && command -v kubectl &>/dev/null; then
        # Only show Kubernetes context if .kube/config exists and kubectl is available
        local cache_key="kubectl_context"
        local current_time=$(date +%s)
        
        # Cache kubectl context for performance (can be slow)
        if [[ -z "${PROMPT_GIT_CACHE[$cache_key]}" || 
              -z "${PROMPT_GIT_CACHE_TIMESTAMP[$cache_key]}" || 
              $((current_time - PROMPT_GIT_CACHE_TIMESTAMP[$cache_key])) -gt 60 ]]; then
            local k8s_context=$(kubectl config current-context 2>/dev/null)
            if [ -n "$k8s_context" ]; then
                PROMPT_GIT_CACHE["$cache_key"]="[k8s:$k8s_context] "
            else
                PROMPT_GIT_CACHE["$cache_key"]=""
            fi
            PROMPT_GIT_CACHE_TIMESTAMP["$cache_key"]=$current_time
        fi
        
        echo "${PROMPT_GIT_CACHE[$cache_key]}"
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
    elif [[ "$PWD" == *"storage/emulated"* || "$PWD" == *"storage/self"* ]]; then
        echo "[📱 shared] "
    fi
}

# AWS profile detection
function parse_aws() {
    if [ -n "$AWS_PROFILE" ]; then
        echo "[aws:$AWS_PROFILE] "
    elif [ -n "$AWS_DEFAULT_PROFILE" ]; then
        echo "[aws:$AWS_DEFAULT_PROFILE] "
    fi
}

# Command execution timer
PROMPT_TIMER_START=0

function prompt_timer_start() {
    if [[ "$PROMPT_COMMAND_TIME" == "1" ]]; then
        PROMPT_TIMER_START=$(date +%s%N)
    fi
}

function prompt_timer_stop() {
    if [[ "$PROMPT_COMMAND_TIME" == "1" && "$PROMPT_TIMER_START" -gt 0 ]]; then
        local timer_stop=$(date +%s%N)
        local elapsed_ns=$((timer_stop - PROMPT_TIMER_START))
        local elapsed_ms=$((elapsed_ns / 1000000))
        
        if [ "$elapsed_ms" -ge 1000 ]; then
            # Show in seconds if >= 1 second
            local elapsed_s=$((elapsed_ms / 1000))
            echo "[${elapsed_s}s] "
        elif [ "$elapsed_ms" -ge 100 ]; then
            # Show in milliseconds if >= 100ms
            echo "[${elapsed_ms}ms] "
        fi
        
        PROMPT_TIMER_START=0
    fi
}

# Start the timer before each command
trap 'prompt_timer_start' DEBUG

# ===========================================
# Prompt Setup
# ===========================================

# Better handling of prompt command with error trapping for exit codes
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

    # Add command execution time if enabled
    if [[ "$PROMPT_COMMAND_TIME" == "1" ]]; then
        PS1+="$(prompt_timer_stop)"
    fi

    # Show timestamp if enabled
    if [[ "$PROMPT_SHOW_TIME" == "1" ]]; then
        PS1+="${CYAN}$(date +%H:%M) ${RESET}"
    fi

    # User and hostname - use different colors for root
    if [[ $EUID -eq 0 ]]; then
        PS1+="${BOLD_RED}\u${RESET}"
    else  
        PS1+="${CYAN}\u${RESET}"
    fi
    
    # Add hostname if enabled
    if [[ "$PROMPT_SHOW_HOST" == "1" ]]; then
        PS1+="@${GREEN}\h${RESET}"
    fi

    # Environment indicators
    PS1+=" $(parse_ssh)"
    PS1+="$(parse_docker)"
    PS1+="$(parse_kubernetes)"
    PS1+="$(parse_aws)"

    # Current directory (full path, with ~ for home)
    if [[ "$PROMPT_STYLE" == "minimal" ]]; then
        # Minimal style: only show the current directory name, not the full path
        PS1+=" ${BLUE}\W${RESET}"
    else
        # Default style: show the full path with ~ for home
        PS1+=" ${BLUE}\w${RESET}"
    fi

    # Shared storage indicator
    PS1+=" $(parse_storage)"

    # Git information if enabled and available
    if [[ "$PROMPT_GIT_ENABLE" == "1" ]]; then
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
    fi

    # Virtual environment indicator
    PS1+=" ${PURPLE}$(parse_venv)${RESET}"

    # Show jobs count if any running
    if [ $(jobs -p | wc -l) -gt 0 ]; then
        PS1+=" ${YELLOW}[$(jobs -p | wc -l) jobs]${RESET}"
    fi

    # Add newline for cleaner display if enabled
    if [[ "$PROMPT_NEWLINE" == "1" ]]; then
        PS1+="\n"
    fi

    # Prompt symbol (# for root, $ for others)
    if [[ "$PROMPT_STYLE" == "plain" ]]; then
        # Plain style: simple $ prompt
        PS1+="$ "
    else
        # Default style: colored prompt
        if [[ $EUID -eq 0 ]]; then
            PS1+="${BOLD_RED}# ${RESET}"
        else
            PS1+="${BOLD_GREEN}\$ ${RESET}"
        fi
    fi
}

# ===========================================
# Prompt Style and Customization Functions
# ===========================================

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

# Function to toggle command execution time display
function toggle_command_time() {
    if [[ "$PROMPT_COMMAND_TIME" == "0" ]]; then
        PROMPT_COMMAND_TIME=1
        echo -e "${GREEN}Prompt will now show command execution times${RESET}"
    else
        PROMPT_COMMAND_TIME=0
        echo -e "${GREEN}Prompt will no longer show command execution times${RESET}"
    fi
}

# Function to toggle hostname display
function toggle_prompt_host() {
    if [[ "$PROMPT_SHOW_HOST" == "0" ]]; then
        PROMPT_SHOW_HOST=1
        echo -e "${GREEN}Prompt will now show hostname${RESET}"
    else
        PROMPT_SHOW_HOST=0
        echo -e "${GREEN}Prompt will no longer show hostname${RESET}"
    fi
}

# Function to toggle newline in prompt
function toggle_prompt_newline() {
    if [[ "$PROMPT_NEWLINE" == "0" ]]; then
        PROMPT_NEWLINE=1
        echo -e "${GREEN}Prompt will now show a newline${RESET}"
    else
        PROMPT_NEWLINE=0
        echo -e "${GREEN}Prompt will no longer show a newline${RESET}"
    fi
}

# Function to toggle Git information in prompt
function toggle_prompt_git() {
    if [[ "$PROMPT_GIT_ENABLE" == "0" ]]; then
        PROMPT_GIT_ENABLE=1
        echo -e "${GREEN}Prompt will now show Git information${RESET}"
    else
        PROMPT_GIT_ENABLE=0
        echo -e "${GREEN}Prompt will no longer show Git information${RESET}"
    fi
}

# Function to cycle through prompt styles
function cycle_prompt_style() {
    case "$PROMPT_STYLE" in
        "fancy")
            PROMPT_STYLE="minimal"
            echo -e "${GREEN}Prompt style set to minimal${RESET}"
            ;;
        "minimal")
            PROMPT_STYLE="plain"
            echo -e "${GREEN}Prompt style set to plain${RESET}"
            ;;
        "plain"|*)
            PROMPT_STYLE="fancy"
            echo -e "${GREEN}Prompt style set to fancy${RESET}"
            ;;
    esac
}

# Function to display prompt configuration
function prompt_config() {
    echo -e "${BOLD_GREEN}Current Prompt Configuration:${RESET}"
    echo -e "${CYAN}Style:${RESET} $PROMPT_STYLE"
    echo -e "${CYAN}Show Time:${RESET} $([ "$PROMPT_SHOW_TIME" == "1" ] && echo "enabled" || echo "disabled")"
    echo -e "${CYAN}Show Hostname:${RESET} $([ "$PROMPT_SHOW_HOST" == "1" ] && echo "enabled" || echo "disabled")"
    echo -e "${CYAN}Show Git Info:${RESET} $([ "$PROMPT_GIT_ENABLE" == "1" ] && echo "enabled" || echo "disabled")"
    echo -e "${CYAN}Command Time:${RESET} $([ "$PROMPT_COMMAND_TIME" == "1" ] && echo "enabled" || echo "disabled")"
    echo -e "${CYAN}Newline:${RESET} $([ "$PROMPT_NEWLINE" == "1" ] && echo "enabled" || echo "disabled")"
    echo -e "${CYAN}Git Cache Timeout:${RESET} ${PROMPT_GIT_CACHE_TIMEOUT}s"
    echo
    echo -e "${CYAN}Toggle Commands:${RESET}"
    echo -e "  ptime - Toggle timestamp"
    echo -e "  phost - Toggle hostname"
    echo -e "  pgit - Toggle Git information"
    echo -e "  pcmd - Toggle command execution time"
    echo -e "  pnewline - Toggle newline"
    echo -e "  pstyle - Cycle through prompt styles"
    echo -e "  pconfig - Show this configuration"
}

# Set aliases for toggling prompt options
alias ptime="toggle_prompt_time"
alias phost="toggle_prompt_host"
alias pgit="toggle_prompt_git"
alias pcmd="toggle_command_time"
alias pnewline="toggle_prompt_newline"
alias pstyle="cycle_prompt_style"
alias pconfig="prompt_config"

# Set the prompt command to update PS1 before each command
PROMPT_COMMAND="set_prompt"

# Register this module's health check function
function _prompt_sh_health_check() {
    # Check if our prompt command is functioning
    if ! declare -F set_prompt >/dev/null; then
        echo -e "${RED}Error: Prompt function 'set_prompt' not defined${RESET}"
        return 1
    fi
    
    # Check for common prompt elements
    if ! echo "$PS1" | grep -q "\\\u"; then
        echo -e "${YELLOW}Warning: Prompt may not contain username (\\\u)${RESET}"
    fi
    
    # All checks passed
    return 0
}

# Output module load message if verbose
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}Loaded: ${BOLD}Enhanced Prompt Module${RESET} (v1.1)"
fi
