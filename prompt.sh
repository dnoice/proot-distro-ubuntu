#!/bin/bash
# ===========================================
# Enhanced Interactive Prompt
# ===========================================
# A modern, context-aware prompt with git integration, visual cues, and smart indicators
# Author: Claude & Me
# Version: 2.0
# Last Updated: 2025-05-15

# ===========================================
# Configuration Options
# ===========================================

# User-configurable prompt features (can be toggled with commands)
PROMPT_SHOW_TIME=${PROMPT_SHOW_TIME:-0}         # Show timestamp in prompt (0=off, 1=on)
PROMPT_SHOW_HOST=${PROMPT_SHOW_HOST:-1}         # Show hostname in prompt (0=off, 1=on)
PROMPT_STYLE=${PROMPT_STYLE:-"modern"}          # Prompt style (modern, compact, minimal, retro)
PROMPT_GIT_ENABLE=${PROMPT_GIT_ENABLE:-1}       # Enable Git integration (0=off, 1=on)
PROMPT_GIT_CACHE_TIMEOUT=${PROMPT_GIT_CACHE_TIMEOUT:-5}  # Git cache timeout in seconds
PROMPT_COMMAND_TIME=${PROMPT_COMMAND_TIME:-1}   # Show execution time of last command (0=off, 1=on)
PROMPT_NEWLINE=${PROMPT_NEWLINE:-1}             # Add newline before prompt (0=off, 1=on)
PROMPT_MAX_PATH_LENGTH=${PROMPT_MAX_PATH_LENGTH:-30}  # Max length for displayed path (0=unlimited)
PROMPT_ENABLE_ICONS=${PROMPT_ENABLE_ICONS:-1}   # Enable Unicode icons in prompt (0=off, 1=on)
PROMPT_BATTERY_CHECK=${PROMPT_BATTERY_CHECK:-0} # Show battery status on mobile (0=off, 1=on)
PROMPT_WEATHER_CHECK=${PROMPT_WEATHER_CHECK:-0} # Show weather info (0=off, 1=on)
PROMPT_STATUS_BAR=${PROMPT_STATUS_BAR:-1}       # Show status bar with system info (0=off, 1=on)

# ===========================================
# Terminal Capability Detection
# ===========================================

# Automatically detect if terminal supports colors and unicode
if [ -t 1 ]; then
    TERM_COLORS=$(tput colors 2>/dev/null || echo 0)
    if [ -n "$TERM_COLORS" ] && [ "$TERM_COLORS" -ge 8 ]; then
        PROMPT_USE_COLORS=1
    else
        PROMPT_USE_COLORS=0
    fi
    
    # Check Unicode support by looking at locale
    if [[ "$(locale charmap 2>/dev/null)" =~ "UTF-8" ]]; then
        PROMPT_UNICODE_SUPPORT=1
    else
        PROMPT_UNICODE_SUPPORT=0
    fi
else
    PROMPT_USE_COLORS=0
    PROMPT_UNICODE_SUPPORT=0
fi

# Detect screen width for better formatting
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)

# ===========================================
# Icon and Symbols Definition
# ===========================================

# Define icons for use in prompt (with fallbacks for terminals without Unicode support)
if [ "$PROMPT_UNICODE_SUPPORT" -eq 1 ] && [ "$PROMPT_ENABLE_ICONS" -eq 1 ]; then
    # Modern Unicode symbols
    ICON_PROMPT="❯"  
    ICON_GIT="󰊢"    
    ICON_HOME="󱂵"   
    ICON_FOLDER="󰉋"  
    ICON_TIME="󱑃"   
    ICON_USER="󰀄"   
    ICON_HOST="󱐿"   
    ICON_SUCCESS="✓"
    ICON_ERROR="✗"   
    ICON_STASH="󰆦"   
    ICON_BRANCH="󰘬"  
    ICON_WARNING="⚠"
    ICON_PYTHON="󰌠"  
    ICON_NODE="󰎙"    
    ICON_DOCKER="󰡨"  
    ICON_BATTERY_HIGH="󰁹"
    ICON_BATTERY_MED="󰁶"
    ICON_BATTERY_LOW="󰁻"
    ICON_NETWORK="󰤨"
    ICON_WEATHER_SUNNY="☀"
    ICON_WEATHER_CLOUDY="☁"
    ICON_WEATHER_RAINY="󰖗"
    ICON_WEATHER_SNOWY="❄"
    ICON_COMMAND="󰘳"
else
    # ASCII fallbacks
    ICON_PROMPT=">"
    ICON_GIT="G"
    ICON_HOME="~"
    ICON_FOLDER="/"
    ICON_TIME="@"
    ICON_USER="u"
    ICON_HOST="h"
    ICON_SUCCESS="+"
    ICON_ERROR="!"
    ICON_STASH="*"
    ICON_BRANCH="#"
    ICON_WARNING="!!"
    ICON_PYTHON="Py"
    ICON_NODE="Js"
    ICON_DOCKER="D"
    ICON_BATTERY_HIGH="B:"
    ICON_BATTERY_MED="B:"
    ICON_BATTERY_LOW="B:"
    ICON_NETWORK="Net"
    ICON_WEATHER_SUNNY="Sun"
    ICON_WEATHER_CLOUDY="Cld"
    ICON_WEATHER_RAINY="Rain"
    ICON_WEATHER_SNOWY="Snow"
    ICON_COMMAND="$"
fi

# ===========================================
# Git Integration Functions
# ===========================================

# Time-based cache system for Git operations
declare -gA PROMPT_GIT_CACHE
declare -gA PROMPT_GIT_CACHE_TIMESTAMP

# Git branch function with caching for improved performance
function parse_git_branch() {
    local branch=""
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

# Git status function with more detailed information and caching
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
        local result=""
        
        # Count different status types
        local added=0
        local modified=0
        local deleted=0
        local untracked=0
        local renamed=0
        
        # Parse status for more detailed information
        while IFS= read -r line; do
            local status_code="${line:0:2}"
            case "$status_code" in
                "A "*)  ((added++)) ;;
                "M "*)  ((modified++)) ;;
                " M"*)  ((modified++)) ;;
                "D "*)  ((deleted++)) ;;
                " D"*)  ((deleted++)) ;;
                "R "*)  ((renamed++)) ;;
                "??"*)  ((untracked++)) ;;
            esac
        done <<< "$status"
        
        # Format the result
        if [[ -z "$status" ]]; then
            result="clean"  # Clean repository
        else
            result="dirty"  # Modified repository
            
            # Add detailed counts if we have changes
            local details=""
            [[ $added -gt 0 ]] && details+=" +$added"
            [[ $modified -gt 0 ]] && details+=" ~$modified"
            [[ $deleted -gt 0 ]] && details+=" -$deleted"
            [[ $untracked -gt 0 ]] && details+=" ?$untracked"
            [[ $renamed -gt 0 ]] && details+=" r$renamed"
            
            result+="$details"
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
            result="$stash_count"
        fi
        
        PROMPT_GIT_CACHE["$cache_key"]="$result"
        PROMPT_GIT_CACHE_TIMESTAMP["$cache_key"]=$current_time
        echo "$result"
    fi
}

# Count unpushed and unpulled commits with caching
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
            local unpulled=$(git log HEAD..@{upstream} --oneline 2>/dev/null | wc -l)
            
            if [[ "$unpushed" -gt 0 ]]; then
                result="${unpushed}↑"  # Arrow up indicates commits to push
            fi
            
            if [[ "$unpulled" -gt 0 ]]; then
                result="${result}${unpulled}↓"  # Arrow down indicates commits to pull
            fi
        fi
        
        PROMPT_GIT_CACHE["$cache_key"]="$result"
        PROMPT_GIT_CACHE_TIMESTAMP["$cache_key"]=$current_time
        echo "$result"
    fi
}

# Get commit count for current branch with caching
function parse_git_commits() {
    # Check if we're in a git repo
    if [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1; then
        # Check cache
        local current_time
        current_time=$(date +%s)
        local cache_key="commits:$PWD"
        
        if [[ -n "${PROMPT_GIT_CACHE[$cache_key]}" && 
              -n "${PROMPT_GIT_CACHE_TIMESTAMP[$cache_key]}" && 
              $((current_time - PROMPT_GIT_CACHE_TIMESTAMP[$cache_key])) -lt $((PROMPT_GIT_CACHE_TIMEOUT * 5)) ]]; then
            # Return cached value (commits count changes very infrequently)
            echo "${PROMPT_GIT_CACHE[$cache_key]}"
            return
        fi
        
        # Cache miss or expired - get fresh data
        local commit_count=$(git rev-list --count HEAD 2>/dev/null)
        
        PROMPT_GIT_CACHE["$cache_key"]="$commit_count"
        PROMPT_GIT_CACHE_TIMESTAMP["$cache_key"]=$current_time
        echo "$commit_count"
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

# Virtual environment function with better icon support
function parse_venv() {
    local venv_info=""
    
    if [[ -n "$VIRTUAL_ENV" ]]; then
        local venv_name=$(basename "$VIRTUAL_ENV")
        venv_info="${ICON_PYTHON} ${venv_name}"
    elif [[ -n "$CONDA_DEFAULT_ENV" && "$CONDA_DEFAULT_ENV" != "base" ]]; then
        venv_info="${ICON_PYTHON} conda:${CONDA_DEFAULT_ENV}"
    elif [[ -n "$NODE_VIRTUAL_ENV" ]]; then
        # For nvm or other Node.js environment managers
        venv_info="${ICON_NODE} $(node -v 2>/dev/null)"
    fi
    
    echo "$venv_info"
}

# Docker container detection
function parse_docker() {
    if [ -f /.dockerenv ] || grep -q docker /proc/self/cgroup 2>/dev/null; then
        echo "${ICON_DOCKER}"
    fi
}

# Kubernetes namespace detection
function parse_kubernetes() {
    if [ -n "$KUBERNETES_NAMESPACE" ] || [ -n "$KUBE_NAMESPACE" ]; then
        local k8s_ns="${KUBERNETES_NAMESPACE:-$KUBE_NAMESPACE}"
        echo "[k8s:$k8s_ns]"
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
                PROMPT_GIT_CACHE["$cache_key"]="[k8s:$k8s_context]"
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
        echo "[SSH]"
    fi
}

# Detect shared storage access (specific to Termux/proot setup)
function parse_storage() {
    if [[ "$PWD" == *"sdcard"* ]]; then
        echo "󱛞 sdcard"
    elif [[ "$PWD" == *"storage/emulated"* || "$PWD" == *"storage/self"* ]]; then
        echo "󱛞 shared"
    fi
}

# AWS profile detection
function parse_aws() {
    if [ -n "$AWS_PROFILE" ]; then
        echo "[aws:$AWS_PROFILE]"
    elif [ -n "$AWS_DEFAULT_PROFILE" ]; then
        echo "[aws:$AWS_DEFAULT_PROFILE]"
    fi
}

# Check battery status on mobile devices
function parse_battery() {
    if [ "$PROMPT_BATTERY_CHECK" -ne 1 ]; then
        return
    fi
    
    local battery_icon=""
    local battery_level=""
    
    # Try to get battery info via Termux API
    if command -v termux-battery-status &>/dev/null; then
        local battery_info=$(termux-battery-status 2>/dev/null)
        
        if [ -n "$battery_info" ]; then
            battery_level=$(echo "$battery_info" | grep -o '"percentage":[0-9]*' | grep -o '[0-9]*')
            local charging=$(echo "$battery_info" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            
            if [ -n "$battery_level" ]; then
                # Select appropriate icon based on battery level
                if [ "$battery_level" -ge 75 ]; then
                    battery_icon="$ICON_BATTERY_HIGH"
                elif [ "$battery_level" -ge 25 ]; then
                    battery_icon="$ICON_BATTERY_MED"
                else
                    battery_icon="$ICON_BATTERY_LOW"
                fi
                
                # Add charging indicator if applicable
                if [ "$charging" = "CHARGING" ]; then
                    battery_icon="${battery_icon}⚡"
                fi
                
                echo "$battery_icon $battery_level%"
            fi
        fi
    elif [ -f "/sys/class/power_supply/BAT0/capacity" ]; then
        # Fallback to sysfs on Linux
        battery_level=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
        local status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
        
        if [ -n "$battery_level" ]; then
            # Select appropriate icon based on battery level
            if [ "$battery_level" -ge 75 ]; then
                battery_icon="$ICON_BATTERY_HIGH"
            elif [ "$battery_level" -ge 25 ]; then
                battery_icon="$ICON_BATTERY_MED"
            else
                battery_icon="$ICON_BATTERY_LOW"
            fi
            
            # Add charging indicator if applicable
            if [ "$status" = "Charging" ]; then
                battery_icon="${battery_icon}⚡"
            fi
            
            echo "$battery_icon $battery_level%"
        fi
    fi
}

# Command execution timer with microsecond precision
PROMPT_TIMER_START=0

function prompt_timer_start() {
    if [[ "$PROMPT_COMMAND_TIME" == "1" ]]; then
        PROMPT_TIMER_START=$(date +%s%N 2>/dev/null || date +%s)
    fi
}

function prompt_timer_stop() {
    if [[ "$PROMPT_COMMAND_TIME" == "1" && "$PROMPT_TIMER_START" -gt 0 ]]; then
        local timer_stop=$(date +%s%N 2>/dev/null || date +%s)
        local elapsed_ns=$((timer_stop - PROMPT_TIMER_START))
        local elapsed_readable=""
        
        # Better formatting of elapsed time
        if [ ${#elapsed_ns} -ge 10 ]; then  # If we have nanosecond precision
            local elapsed_s=$((elapsed_ns / 1000000000))
            local elapsed_ms=$(((elapsed_ns % 1000000000) / 1000000))
            
            if [ "$elapsed_s" -ge 3600 ]; then
                # Format as hours:minutes:seconds for long operations
                local hours=$((elapsed_s / 3600))
                local minutes=$(((elapsed_s % 3600) / 60))
                local seconds=$((elapsed_s % 60))
                elapsed_readable="${hours}h ${minutes}m ${seconds}s"
            elif [ "$elapsed_s" -ge 60 ]; then
                # Format as minutes:seconds
                local minutes=$((elapsed_s / 60))
                local seconds=$((elapsed_s % 60))
                elapsed_readable="${minutes}m ${seconds}s"
            elif [ "$elapsed_s" -ge 10 ]; then
                # Just seconds for medium operations
                elapsed_readable="${elapsed_s}s"
            elif [ "$elapsed_s" -gt 0 ]; then
                # Seconds and milliseconds for short operations
                elapsed_readable="${elapsed_s}.$(printf %03d $elapsed_ms)s"
            elif [ "$elapsed_ms" -gt 0 ]; then
                # Just milliseconds for very short operations
                elapsed_readable="${elapsed_ms}ms"
            fi
        else
            # Simple seconds precision as fallback
            local elapsed_s=$elapsed_ns
            if [ "$elapsed_s" -ge 3600 ]; then
                local hours=$((elapsed_s / 3600))
                local minutes=$(((elapsed_s % 3600) / 60))
                local seconds=$((elapsed_s % 60))
                elapsed_readable="${hours}h ${minutes}m ${seconds}s"
            elif [ "$elapsed_s" -ge 60 ]; then
                local minutes=$((elapsed_s / 60))
                local seconds=$((elapsed_s % 60))
                elapsed_readable="${minutes}m ${seconds}s"
            else
                elapsed_readable="${elapsed_s}s"
            fi
        fi
        
        if [ -n "$elapsed_readable" ]; then
            echo "${ICON_TIME} ${elapsed_readable}"
        fi
        
        PROMPT_TIMER_START=0
    fi
}

# Network status function
function parse_network() {
    # Only show in status bar
    if [ "$PROMPT_STATUS_BAR" -eq 0 ]; then
        return
    fi
    
    local network_icon="${ICON_NETWORK}"
    
    # Check for internet connectivity (quick check)
    if ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1 || ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        network_icon="${network_icon} ✓"
    else
        network_icon="${network_icon} ✗"
    fi
    
    echo "$network_icon"
}

# Weather function (for status bar)
function parse_weather() {
    if [ "$PROMPT_WEATHER_CHECK" -ne 1 ]; then
        return
    fi
    
    # Check if we have a cached weather result
    local cache_file="/tmp/.weather_cache"
    local cache_max_age=3600  # 1 hour
    
    if [ -f "$cache_file" ]; then
        local cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
        local current_time=$(date +%s)
        
        if [ $((current_time - cache_time)) -lt $cache_max_age ]; then
            # Use cached weather
            cat "$cache_file"
            return
        fi
    fi
    
    # Fetch new weather data (lightweight version for terminals)
    if command -v curl &>/dev/null; then
        # Try to get a simple icon + temp
        local weather_data=$(curl -s "wttr.in/?format=%c+%t" 2>/dev/null)
        
        if [ -n "$weather_data" ] && [ ${#weather_data} -lt 20 ]; then
            echo "$weather_data" > "$cache_file"
            echo "$weather_data"
        fi
    fi
}

# Start the timer before each command
trap 'prompt_timer_start' DEBUG

# ===========================================
# Prompt Setup
# ===========================================

# Better handling of prompt command with error trapping for exit codes
trap 'export PROMPT_EXIT_CODE=$?' DEBUG

# Smart path shortening function
function shorten_path() {
    local path="$1"
    local max_length="$PROMPT_MAX_PATH_LENGTH"
    
    # Don't shorten if max_length is 0 or path is already short enough
    if [ "$max_length" -eq 0 ] || [ ${#path} -le "$max_length" ]; then
        echo "$path"
        return
    fi
    
    # Replace home directory with ~
    path="${path/#$HOME/~}"
    
    # If still too long, use smart shortening
    if [ ${#path} -gt "$max_length" ]; then
        # Keep first directory and last two directories
        local first_dir=$(echo "$path" | cut -d'/' -f1)
        
        # Count the number of directories
        local dir_count=$(echo "$path" | tr -cd '/' | wc -c)
        
        if [ "$dir_count" -le 2 ]; then
            # Not enough directories to shorten meaningfully
            echo "$path"
        else
            # Get last two directories
            local last_two=$(echo "$path" | rev | cut -d'/' -f1-2 | rev)
            echo "${first_dir}/.../${last_two}"
        fi
    else
        echo "$path"
    fi
}

# Function to get last command status indicator
function get_status_indicator() {
    local EXIT="${1:-0}"
    
    if [ $EXIT -eq 0 ]; then
        echo "${GREEN}${ICON_SUCCESS}${RESET}"
    else
        echo "${RED}${ICON_ERROR} $EXIT${RESET}"
    fi
}

# Set custom prompt with all the features
function set_prompt() {
    local EXIT="${PROMPT_EXIT_CODE:-0}"
    local base_color="${CYAN}"
    local accent_color="${BOLD_GREEN}"
    local path_color="${BLUE}"
    local status_color="${YELLOW}"
    
    # Start building PS1
    PS1=""

    # Add status bar if enabled
    if [[ "$PROMPT_STATUS_BAR" == "1" ]]; then
        # Get terminal width for formatting
        local term_width=$(tput cols 2>/dev/null || echo 80)
        
        # Create horizontal line with host info in the middle 
        local system_info=""
        
        # Add hostname and user
        if [[ "$PROMPT_SHOW_HOST" == "1" ]]; then
            system_info="${base_color}\h${RESET}"
        fi
        
        # Add system load if available
        if command -v uptime &>/dev/null; then
            local load=$(uptime | grep -oE 'load average: [0-9]+\.[0-9]+' | sed 's/load average: //')
            if [ -n "$load" ]; then
                system_info="${system_info} ${status_color}load:${load}${RESET}"
            fi
        fi
        
        # Add battery status if enabled
        local battery_status=$(parse_battery)
        if [ -n "$battery_status" ]; then
            system_info="${system_info} ${battery_status}"
        fi
        
        # Add network status
        local network_status=$(parse_network)
        if [ -n "$network_status" ]; then
            system_info="${system_info} ${network_status}"
        fi
        
        # Add weather if enabled
        local weather_info=$(parse_weather)
        if [ -n "$weather_info" ]; then
            system_info="${system_info} ${weather_info}"
        fi
        
        # Calculate padding based on terminal width and system_info length
        local visible_length=$(echo -e "$system_info" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" | wc -c)
        local left_padding=$(( (term_width - visible_length) / 2 ))
        local right_padding=$(( term_width - left_padding - visible_length ))
        local line_char="─"
        
        # Build status bar
        PS1+="${base_color}"
        PS1+=$(printf "%0.s$line_char" $(seq 1 $left_padding))
        PS1+="${system_info}"
        PS1+=$(printf "%0.s$line_char" $(seq 1 $right_padding))
        PS1+="${RESET}\n"
    fi

    # Add error code if previous command failed
    if [ $EXIT -eq 0 ]; then
        PS1+="${GREEN}${ICON_SUCCESS} ${RESET}"
    else
        PS1+="${RED}${ICON_ERROR} $EXIT ${RESET}"
    fi

    # Add command execution time if enabled
    local exec_time=$(prompt_timer_stop)
    if [ -n "$exec_time" ]; then
        PS1+="${status_color}${exec_time} ${RESET}"
    fi

    # Show timestamp if enabled
    if [[ "$PROMPT_SHOW_TIME" == "1" ]]; then
        PS1+="${base_color}$(date +%H:%M) ${RESET}"
    fi

    # User and hostname - use different colors for root
    if [[ $EUID -eq 0 ]]; then
        PS1+="${RED}${ICON_USER} \u${RESET}"
    else  
        PS1+="${base_color}${ICON_USER} \u${RESET}"
    fi
    
    # Add hostname if enabled
    if [[ "$PROMPT_SHOW_HOST" == "1" ]]; then
        PS1+=" ${base_color}${ICON_HOST} \h${RESET}"
    fi

    # Environment indicators
    local ssh_info=$(parse_ssh)
    local docker_info=$(parse_docker)
    local k8s_info=$(parse_kubernetes)
    local aws_info=$(parse_aws)
    
    [ -n "$ssh_info" ] && PS1+=" ${YELLOW}${ssh_info}${RESET}"
    [ -n "$docker_info" ] && PS1+=" ${CYAN}${docker_info}${RESET}"
    [ -n "$k8s_info" ] && PS1+=" ${BLUE}${k8s_info}${RESET}"
    [ -n "$aws_info" ] && PS1+=" ${YELLOW}${aws_info}${RESET}"

    # Current directory (with path shortening)
    local dir_path=$(shorten_path "\w")
    
    # Apply different icons based on path
    if [[ "$dir_path" == "~"* ]]; then
        PS1+=" ${path_color}${ICON_HOME} ${dir_path}${RESET}"
    else
        PS1+=" ${path_color}${ICON_FOLDER} ${dir_path}${RESET}"
    fi

    # Shared storage indicator
    local storage_info=$(parse_storage)
    [ -n "$storage_info" ] && PS1+=" ${PURPLE}${storage_info}${RESET}"

    # Git information if enabled and available
    if [[ "$PROMPT_GIT_ENABLE" == "1" ]]; then
        local git_branch=$(parse_git_branch)
        if [[ -n "$git_branch" ]]; then
            local git_status=$(parse_git_status)
            PS1+=" ${YELLOW}${ICON_GIT} ${git_branch}${RESET}"
            
            # Status indicator
            if [[ "$git_status" == "clean" ]]; then
                PS1+=" ${GREEN}${ICON_SUCCESS}${RESET}"
            else
                # Extract status details if available
                if [[ "$git_status" == *"dirty"* ]]; then
                    local git_details=$(echo "$git_status" | sed 's/dirty//')
                    PS1+=" ${RED}${ICON_ERROR}${git_details}${RESET}"
                fi
            fi
            
            # Add stash information if any
            local git_stash=$(parse_git_stash)
            if [[ -n "$git_stash" ]]; then
                PS1+=" ${PURPLE}${ICON_STASH} ${git_stash}${RESET}"
            fi
            
            # Add unpushed commit information if any
            local git_unpushed=$(parse_git_unpushed)
            if [[ -n "$git_unpushed" ]]; then
                PS1+=" ${YELLOW}${git_unpushed}${RESET}"
            fi
            
            # Add commit count if not too large
            local git_commits=$(parse_git_commits)
            if [[ -n "$git_commits" ]] && [[ "$git_commits" -lt 1000 ]]; then
                PS1+=" ${CYAN}${git_commits}c${RESET}"
            fi
        fi
    fi

    # Virtual environment indicator
    local venv_info=$(parse_venv)
    [ -n "$venv_info" ] && PS1+=" ${PURPLE}${venv_info}${RESET}"

    # Show jobs count if any running
    if [ $(jobs -p | wc -l) -gt 0 ]; then
        PS1+=" ${YELLOW}[$(jobs -p | wc -l) jobs]${RESET}"
    fi

    # Add newline for cleaner display if enabled
    if [[ "$PROMPT_NEWLINE" == "1" ]]; then
        PS1+="\n"
    fi

    # Prompt symbol based on style and user
    case "$PROMPT_STYLE" in
        minimal)
            # Minimal style with simple symbol
            if [[ $EUID -eq 0 ]]; then
                PS1+="${RED}# ${RESET}"
            else
                PS1+="${accent_color}$ ${RESET}"
            fi
            ;;
        compact)
            # Compact style with smaller indicators
            if [[ $EUID -eq 0 ]]; then
                PS1+="${RED}# ${RESET}"
            else
                PS1+="${accent_color}> ${RESET}"
            fi
            ;;
        retro)
            # Old-school terminal style
            if [[ $EUID -eq 0 ]]; then
                PS1+="${RED}# ${RESET}"
            else
                PS1+="${GREEN}\$ ${RESET}"
            fi
            ;;
        *)
            # Modern style with Unicode prompt symbol (default)
            if [[ $EUID -eq 0 ]]; then
                PS1+="${RED}${ICON_PROMPT} ${RESET}"
            else
                PS1+="${accent_color}${ICON_PROMPT} ${RESET}"
            fi
            ;;
    esac
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

# Function to toggle status bar
function toggle_status_bar() {
    if [[ "$PROMPT_STATUS_BAR" == "0" ]]; then
        PROMPT_STATUS_BAR=1
        echo -e "${GREEN}Prompt will now show status bar${RESET}"
    else
        PROMPT_STATUS_BAR=0
        echo -e "${GREEN}Prompt will no longer show status bar${RESET}"
    fi
}

# Function to toggle Unicode icons
function toggle_prompt_icons() {
    if [[ "$PROMPT_ENABLE_ICONS" == "0" ]]; then
        PROMPT_ENABLE_ICONS=1
        echo -e "${GREEN}Prompt will now show Unicode icons${RESET}"
    else
        PROMPT_ENABLE_ICONS=0
        echo -e "${GREEN}Prompt will no longer show Unicode icons${RESET}"
    fi
    
    # Reload prompt to update icons
    echo -e "${YELLOW}Note: You need to reload your prompt with 'reload' for this change to take effect${RESET}"
}

# Function to toggle battery status display
function toggle_battery_status() {
    if [[ "$PROMPT_BATTERY_CHECK" == "0" ]]; then
        PROMPT_BATTERY_CHECK=1
        echo -e "${GREEN}Prompt will now show battery status${RESET}"
    else
        PROMPT_BATTERY_CHECK=0
        echo -e "${GREEN}Prompt will no longer show battery status${RESET}"
    fi
}

# Function to toggle weather information
function toggle_weather() {
    if [[ "$PROMPT_WEATHER_CHECK" == "0" ]]; then
        PROMPT_WEATHER_CHECK=1
        echo -e "${GREEN}Prompt will now show weather information${RESET}"
        
        # Clear weather cache
        rm -f /tmp/.weather_cache
    else
        PROMPT_WEATHER_CHECK=0
        echo -e "${GREEN}Prompt will no longer show weather information${RESET}"
    fi
}

# Function to cycle through prompt styles
function cycle_prompt_style() {
    case "$PROMPT_STYLE" in
        modern)
            PROMPT_STYLE="compact"
            echo -e "${GREEN}Prompt style set to compact${RESET}"
            ;;
        compact)
            PROMPT_STYLE="minimal"
            echo -e "${GREEN}Prompt style set to minimal${RESET}"
            ;;
        minimal)
            PROMPT_STYLE="retro"
            echo -e "${GREEN}Prompt style set to retro${RESET}"
            ;;
        *)
            PROMPT_STYLE="modern"
            echo -e "${GREEN}Prompt style set to modern${RESET}"
            ;;
    esac
}

# Function to set max path length
function set_path_length() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: set_path_length <length>${RESET}"
        echo "Examples:"
        echo "  set_path_length 30  - Set max path length to 30 characters"
        echo "  set_path_length 0   - Disable path shortening"
        return 1
    fi
    
    if ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid length. Please provide a number.${RESET}"
        return 1
    fi
    
    PROMPT_MAX_PATH_LENGTH="$1"
    
    if [ "$1" -eq 0 ]; then
        echo -e "${GREEN}Path shortening disabled. Full paths will be shown.${RESET}"
    else
        echo -e "${GREEN}Maximum path length set to $1 characters.${RESET}"
    fi
}

# Function to display prompt configuration
function prompt_config() {
    echo -e "${BOLD_GREEN}Current Prompt Configuration:${RESET}"
    echo -e "${CYAN}Style:${RESET} ${YELLOW}$PROMPT_STYLE${RESET}"
    echo -e "${CYAN}Show Time:${RESET} $([ "$PROMPT_SHOW_TIME" == "1" ] && echo "${GREEN}enabled${RESET}" || echo "${RED}disabled${RESET}")"
    echo -e "${CYAN}Show Hostname:${RESET} $([ "$PROMPT_SHOW_HOST" == "1" ] && echo "${GREEN}enabled${RESET}" || echo "${RED}disabled${RESET}")"
    echo -e "${CYAN}Show Git Info:${RESET} $([ "$PROMPT_GIT_ENABLE" == "1" ] && echo "${GREEN}enabled${RESET}" || echo "${RED}disabled${RESET}")"
    echo -e "${CYAN}Command Time:${RESET} $([ "$PROMPT_COMMAND_TIME" == "1" ] && echo "${GREEN}enabled${RESET}" || echo "${RED}disabled${RESET}")"
    echo -e "${CYAN}Newline:${RESET} $([ "$PROMPT_NEWLINE" == "1" ] && echo "${GREEN}enabled${RESET}" || echo "${RED}disabled${RESET}")"
    echo -e "${CYAN}Status Bar:${RESET} $([ "$PROMPT_STATUS_BAR" == "1" ] && echo "${GREEN}enabled${RESET}" || echo "${RED}disabled${RESET}")"
    echo -e "${CYAN}Unicode Icons:${RESET} $([ "$PROMPT_ENABLE_ICONS" == "1" ] && echo "${GREEN}enabled${RESET}" || echo "${RED}disabled${RESET}")"
    echo -e "${CYAN}Battery Status:${RESET} $([ "$PROMPT_BATTERY_CHECK" == "1" ] && echo "${GREEN}enabled${RESET}" || echo "${RED}disabled${RESET}")"
    echo -e "${CYAN}Weather Info:${RESET} $([ "$PROMPT_WEATHER_CHECK" == "1" ] && echo "${GREEN}enabled${RESET}" || echo "${RED}disabled${RESET}")"
    echo -e "${CYAN}Max Path Length:${RESET} ${YELLOW}$PROMPT_MAX_PATH_LENGTH${RESET}$([ "$PROMPT_MAX_PATH_LENGTH" == "0" ] && echo " (unlimited)")"
    echo -e "${CYAN}Git Cache Timeout:${RESET} ${YELLOW}${PROMPT_GIT_CACHE_TIMEOUT}s${RESET}"
    
    echo
    echo -e "${CYAN}Toggle Commands:${RESET}"
    echo -e "  ${GREEN}ptime${RESET}      - Toggle timestamp"
    echo -e "  ${GREEN}phost${RESET}      - Toggle hostname"
    echo -e "  ${GREEN}pgit${RESET}       - Toggle Git information"
    echo -e "  ${GREEN}pcmd${RESET}       - Toggle command execution time"
    echo -e "  ${GREEN}pnewline${RESET}   - Toggle newline"
    echo -e "  ${GREEN}pstyle${RESET}     - Cycle through prompt styles"
    echo -e "  ${GREEN}pstatusbar${RESET} - Toggle status bar"
    echo -e "  ${GREEN}picons${RESET}     - Toggle Unicode icons"
    echo -e "  ${GREEN}pbattery${RESET}   - Toggle battery status"
    echo -e "  ${GREEN}pweather${RESET}   - Toggle weather information"
    echo -e "  ${GREEN}ppath${RESET}      - Set max path length"
    echo -e "  ${GREEN}pconfig${RESET}    - Show this configuration"
}

# Preview function to show different prompt styles
function preview_prompt_styles() {
    local original_style="$PROMPT_STYLE"
    
    echo -e "${GREEN}Prompt Style Preview:${RESET}"
    echo
    
    # Preview each style
    for style in "modern" "compact" "minimal" "retro"; do
        PROMPT_STYLE="$style"
        echo -e "${CYAN}Style: ${BOLD}$style${RESET}"
        set_prompt  # Generate prompt with this style
        echo -e "${PS1@P}"  # Print the prompt with expansions
        echo
    done
    
    # Restore original style
    PROMPT_STYLE="$original_style"
}

# Set aliases for toggling prompt options
alias ptime="toggle_prompt_time"
alias phost="toggle_prompt_host"
alias pgit="toggle_prompt_git"
alias pcmd="toggle_command_time"
alias pnewline="toggle_prompt_newline"
alias pstyle="cycle_prompt_style"
alias pstatusbar="toggle_status_bar"
alias picons="toggle_prompt_icons"
alias pbattery="toggle_battery_status"
alias pweather="toggle_weather"
alias ppath="set_path_length"
alias pconfig="prompt_config"
alias ppreview="preview_prompt_styles"

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
    echo -e "${GREEN}Loaded: ${BOLD}Enhanced Interactive Prompt Module${RESET} (v2.0)"
fi
