#!/bin/bash
# ===========================================
# Core Settings & Environment Configuration
# ===========================================
# Sets up basic environment behavior, history settings, and shell options
# Author: Claude & Me
# Version: 1.1
# Last Updated: 2025-05-14

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# ===========================================
# Locale Settings
# ===========================================

# Set default locale if not already set
if [ -z "$LANG" ]; then
    export LANG="en_US.UTF-8"
fi

if [ -z "$LC_ALL" ]; then
    export LC_ALL="en_US.UTF-8"
fi

# Check if locale is actually available on the system
if command -v locale &>/dev/null; then
    if ! locale -a 2>/dev/null | grep -q "en_US.UTF-8"; then
        # Fallback to available locales or C locale
        if locale -a 2>/dev/null | grep -q "C.UTF-8"; then
            export LANG="C.UTF-8"
            export LC_ALL="C.UTF-8"
        elif locale -a 2>/dev/null | grep -q "en_US"; then
            export LANG="en_US"
            export LC_ALL="en_US" 
        else
            export LANG="C"
            export LC_ALL="C"
        fi
    fi
fi

# ===========================================
# Terminal Capability Detection
# ===========================================

# Detect terminal capabilities with better error handling
TERM_COLORS=$(tput colors 2>/dev/null || echo 0)
TERM_LINES=$(tput lines 2>/dev/null || echo 24)
TERM_COLS=$(tput cols 2>/dev/null || echo 80)

# Store terminal information for later use
export TERMINAL_INFO="$TERM ${TERM_COLORS}colors ${TERM_LINES}x${TERM_COLS}"

# Adjust settings based on terminal capabilities
if [ "$TERM_COLORS" -ge 256 ]; then
    export COLORTERM="truecolor"
fi

# Set appropriate TERM if not properly set
if [ "$TERM" = "dumb" ] || [ -z "$TERM" ]; then
    export TERM="xterm-256color"
fi

# ===========================================
# Security Settings
# ===========================================

# Set more secure default umask (only user can read/write new files)
umask 077

# Create secure temporary directory if needed
if [ ! -d "$HOME/.tmp" ]; then
    mkdir -p "$HOME/.tmp" 2>/dev/null
    if [ -d "$HOME/.tmp" ]; then
        chmod 700 "$HOME/.tmp"
        export TMPDIR="$HOME/.tmp"
    fi
fi

# Disable shell history for root user if desired
if [ "$(id -u)" -eq 0 ] && [ "$DISABLE_ROOT_HISTORY" = "1" ]; then
    unset HISTFILE
    HISTSIZE=0
    HISTFILESIZE=0
fi

# ===========================================
# History Configuration
# ===========================================

# Don't put duplicate lines or lines starting with space in the history
HISTCONTROL=ignoreboth:erasedups

# More granular control over what gets ignored in history
HISTIGNORE="ls:ll:la:l:cd:pwd:exit:clear:history:h:c:e:bg:fg"

# Append to the history file, don't overwrite it
shopt -s histappend 2>/dev/null || true

# Write history after each command (synchronize across sessions)
# Only set PROMPT_COMMAND if it's not already set to avoid overriding
if [ -z "$PROMPT_COMMAND" ]; then
    export PROMPT_COMMAND="history -a"
else
    export PROMPT_COMMAND="${PROMPT_COMMAND%%;*}; history -a"
fi

# Set history length with reasonable defaults
HISTSIZE=${HISTSIZE:-10000}
HISTFILESIZE=${HISTFILESIZE:-20000}

# Add timestamps to history
export HISTTIMEFORMAT="%F %T "

# ===========================================
# Shell Options
# ===========================================

# Check window size after each command
shopt -s checkwinsize 2>/dev/null || true

# Use extended pattern matching features
shopt -s extglob 2>/dev/null || true

# Enable ** recursive glob for pathname expansion (if supported)
shopt -s globstar 2>/dev/null || true

# Case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob 2>/dev/null || true

# Autocorrect typos in path names when using `cd`
shopt -s cdspell 2>/dev/null || true

# Enable autocd (change directories without using cd)
shopt -s autocd 2>/dev/null || true

# Correct minor errors in directory names during completion
shopt -s dirspell 2>/dev/null || true

# When changing directory, add previous directory to stack
shopt -s dirpersist 2>/dev/null || true

# Make less more friendly for non-text input files
if command -v lesspipe &>/dev/null; then
    eval "$(SHELL=/bin/sh lesspipe)" 2>/dev/null || true
elif [ -x /usr/bin/lesspipe ]; then
    eval "$(SHELL=/bin/sh lesspipe)" 2>/dev/null || true
fi

# Set variable identifying the chroot you work in
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# ===========================================
# Programmable Completion
# ===========================================

# Enable programmable completion features
if ! shopt -oq posix; then
    # Try multiple completion files in order of preference
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    elif [ -f /usr/local/etc/bash_completion ]; then
        . /usr/local/etc/bash_completion
    fi
    
    # Check for Termux-specific completion
    if [ -n "$TERMUX_ENVIRONMENT" ] && [ -f "$PREFIX/etc/bash_completion" ]; then
        . "$PREFIX/etc/bash_completion"
    fi
fi

# ===========================================
# Default Editor
# ===========================================

# Check for preferred editors in order with fallbacks
if [ -n "$EDITOR" ]; then
    # User already has a preferred editor set
    true
elif command -v vim &>/dev/null; then
    export EDITOR='vim'
    export VISUAL='vim'
elif command -v nano &>/dev/null; then
    export EDITOR='nano'
    export VISUAL='nano'
elif command -v vi &>/dev/null; then
    export EDITOR='vi'
    export VISUAL='vi'
elif command -v emacs &>/dev/null; then
    export EDITOR='emacs -nw'
    export VISUAL='emacs'
elif command -v micro &>/dev/null; then
    # Micro is a good alternative in Termux
    export EDITOR='micro'
    export VISUAL='micro'
fi

# Set pager with reasonable options
export PAGER='less'
export LESS='-R -i -g -c -W'

# Make less behave like more when output fits on one screen
export LESS="$LESS -F -X"

# ===========================================
# Terminal Colors
# ===========================================

# Set common colors for use in other scripts
# Check for terminal support first
if [ -t 1 ] && [ "$TERM_COLORS" -gt 1 ]; then
    export RESET="$(tput sgr0 2>/dev/null || echo '')"
    export BLACK="$(tput setaf 0 2>/dev/null || echo '')"
    export RED="$(tput setaf 1 2>/dev/null || echo '')"
    export GREEN="$(tput setaf 2 2>/dev/null || echo '')"
    export YELLOW="$(tput setaf 3 2>/dev/null || echo '')"
    export BLUE="$(tput setaf 4 2>/dev/null || echo '')"
    export PURPLE="$(tput setaf 5 2>/dev/null || echo '')"
    export CYAN="$(tput setaf 6 2>/dev/null || echo '')"
    export WHITE="$(tput setaf 7 2>/dev/null || echo '')"
    export BOLD="$(tput bold 2>/dev/null || echo '')"
    export BOLD_RED="${BOLD}${RED}"
    export BOLD_GREEN="${BOLD}${GREEN}"
    export BOLD_YELLOW="${BOLD}${YELLOW}"
    export BOLD_BLUE="${BOLD}${BLUE}"
    export BOLD_PURPLE="${BOLD}${PURPLE}"
    export BOLD_CYAN="${BOLD}${CYAN}"
    export BOLD_WHITE="${BOLD}${WHITE}"
    
    # Advanced formatting
    export UNDERLINE="$(tput smul 2>/dev/null || echo '')"
    export NO_UNDERLINE="$(tput rmul 2>/dev/null || echo '')"
    export STANDOUT="$(tput smso 2>/dev/null || echo '')"
    export NO_STANDOUT="$(tput rmso 2>/dev/null || echo '')"
else
    # Define empty colors for non-interactive sessions
    export RESET="" BLACK="" RED="" GREEN="" YELLOW="" BLUE="" PURPLE="" CYAN="" WHITE="" BOLD=""
    export BOLD_RED="" BOLD_GREEN="" BOLD_YELLOW="" BOLD_BLUE="" BOLD_PURPLE="" BOLD_CYAN="" BOLD_WHITE=""
    export UNDERLINE="" NO_UNDERLINE="" STANDOUT="" NO_STANDOUT=""
fi

# ===========================================
# Default PATH Enhancement 
# ===========================================

# Path manipulation function - adds directory to PATH if it exists and isn't already in PATH
function path_add() {
    local dir="$1"
    
    # Skip if directory doesn't exist or is empty
    if [ ! -d "$dir" ]; then
        return 0
    fi
    
    # Skip if already in PATH
    if [[ ":$PATH:" == *":$dir:"* ]]; then
        return 0
    fi
    
    # Add to PATH
    PATH="${dir}:${PATH}"
}

# Add user's private bins in order of preference
path_add "$HOME/bin"
path_add "$HOME/.local/bin"
path_add "$HOME/scripts"
path_add "$HOME/.cargo/bin"
path_add "$HOME/go/bin"
path_add "$HOME/.npm/bin"

# Add Termux-specific paths if in Termux
if [ -n "$TERMUX_ENVIRONMENT" ]; then
    path_add "$PREFIX/bin"
    path_add "$PREFIX/games"
    path_add "$PREFIX/local/bin"
fi

# Function to deduplicate PATH entries with improved algorithm
function deduplicate_path() {
    if [ -n "$PATH" ]; then
        local new_path=""
        local IFS=":"
        local paths=($PATH)
        local seen=()
        
        # Iterate through paths in order
        for p in "${paths[@]}"; do
            if [ -n "$p" ] && [[ ! " ${seen[*]} " =~ " $p " ]]; then
                # Only add if not seen before
                new_path="${new_path:+$new_path:}$p"
                seen+=("$p")
            fi
        done
        
        # Set the deduplicated PATH
        PATH="$new_path"
    fi
}

# Apply path deduplication
deduplicate_path

# ===========================================
# Default Aliases
# ===========================================

# Color support for common commands
if [ -x /usr/bin/dircolors ]; then
    if [ -r ~/.dircolors ]; then
        eval "$(dircolors -b ~/.dircolors)" 2>/dev/null || eval "$(dircolors -b)" 2>/dev/null
    else
        eval "$(dircolors -b)" 2>/dev/null
    fi
    
    alias ls="ls --color=auto"
    alias dir="dir --color=auto"
    alias vdir="vdir --color=auto"
    alias grep="grep --color=auto"
    alias fgrep="fgrep --color=auto"
    alias egrep="egrep --color=auto"
    alias diff="diff --color=auto"
    alias ip="ip -color=auto"
fi

# Basic aliases for common commands with safety flags
alias l="ls -CF"
alias ll="ls -alF"
alias la="ls -A"
alias h="history"
alias c="clear"
alias e="$EDITOR"
alias q="exit"
alias :q="exit"  # For vim users
alias path='echo -e ${PATH//:/\\n}'

# Safety aliases to prevent accidental data loss
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"

# Common command shortcuts
alias grep="grep --color=auto"
alias df="df -h"
alias du="du -h"
alias free="free -m"
alias mkdir="mkdir -p"

# ===========================================
# Termux-specific settings
# ===========================================

# Check if running in Termux
if [ -d "/data/data/com.termux" ]; then
    # Termux-specific settings
    export TERMUX=1
    
    # Check for termux-tools
    if command -v termux-info &>/dev/null; then
        export TERMUX_VERSION=$(termux-info 2>/dev/null | grep termux-app | awk '{print $2}')
    fi
    
    # Set up Ubuntu proot paths
    if [ -d "/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/ubuntu" ]; then
        export UBUNTU_PROOT_PATH="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/ubuntu"
    fi
    
    # Try to detect Android version
    if [ -f "/system/build.prop" ]; then
        export ANDROID_VERSION=$(grep "ro.build.version.release" /system/build.prop 2>/dev/null | cut -d= -f2)
    fi
    
    # Set up better keyboard handling for Termux
    if [ -f "$HOME/.termux/termux.properties" ]; then
        if ! grep -q "extra-keys" "$HOME/.termux/termux.properties"; then
            # Suggest better keyboard setup for Termux
            if [ "$VERBOSE_MODULE_LOAD" == "1" ]; then
                echo -e "${YELLOW}Tip: Add extra keys to Termux by creating ~/.termux/termux.properties${RESET}"
                echo -e "${CYAN}Example: extra-keys = [['ESC','/','-','HOME','UP','END','PGUP'],['TAB','CTRL','ALT','LEFT','DOWN','RIGHT','PGDN']]${RESET}"
            fi
        fi
    fi
fi

# ===========================================
# Enhanced Performance Settings
# ===========================================

# Optimize for Termux/mobile environment if detected
if [ -n "$TERMUX_ENVIRONMENT" ] || [ -n "$TERMUX" ]; then
    # Reduce resource usage in mobile environment
    export HISTSIZE=1000
    export HISTFILESIZE=2000
    
    # Adjust options for better performance on mobile
    export LESS="$LESS -m"  # More verbose prompt, better for small screens
    
    # Optimize readline for mobile usage
    if [ -f "$HOME/.inputrc" ]; then
        if ! grep -q "completion-ignore-case" "$HOME/.inputrc"; then
            echo "set completion-ignore-case on" >> "$HOME/.inputrc"
            echo "set show-all-if-ambiguous on" >> "$HOME/.inputrc"
            echo "set mark-symlinked-directories on" >> "$HOME/.inputrc"
            echo "set visible-stats on" >> "$HOME/.inputrc"
            echo "set colored-stats on" >> "$HOME/.inputrc"
        fi
    else
        # Create optimized inputrc for Termux
        cat > "$HOME/.inputrc" << 'EOF'
# Better completion settings for mobile
set completion-ignore-case on
set show-all-if-ambiguous on
set mark-symlinked-directories on
set visible-stats on
set colored-stats on
set enable-keypad on
set bell-style none
EOF
    fi
fi

# ===========================================
# Environment Summary Function
# ===========================================

# Function to display environment information with better formatting
function env_info() {
    echo -e "${GREEN}Environment Information${RESET}"
    printf "%-20s : %s\n" "Shell" "$SHELL ($(bash --version | head -1 | cut -d' ' -f4))"
    printf "%-20s : %s\n" "User" "$(whoami) ($(id -u))"
    printf "%-20s : %s\n" "Hostname" "$(hostname)"
    printf "%-20s : %s\n" "Terminal" "$TERM (${TERM_COLORS} colors, ${TERM_LINES}x${TERM_COLS})"
    printf "%-20s : %s\n" "Locale" "$LANG"
    printf "%-20s : %s\n" "Editor" "$EDITOR"
    
    echo -e "\n${GREEN}Directory Information${RESET}"
    printf "%-20s : %s\n" "Current" "$PWD"
    printf "%-20s : %s\n" "Home" "$HOME"
    
    if [ -n "$TERMUX" ]; then
        echo -e "\n${GREEN}Termux Information${RESET}"
        printf "%-20s : %s\n" "Termux Version" "${TERMUX_VERSION:-Unknown}"
        
        if [ -n "$UBUNTU_PROOT_PATH" ]; then
            printf "%-20s : %s\n" "Ubuntu Path" "$UBUNTU_PROOT_PATH"
        fi
        
        if [ -n "$UBUNTU_VERSION" ]; then
            printf "%-20s : %s\n" "Ubuntu Version" "$UBUNTU_VERSION"
        fi
        
        if [ -n "$ANDROID_VERSION" ]; then
            printf "%-20s : %s\n" "Android Version" "$ANDROID_VERSION"
        fi
    fi
    
    echo -e "\n${GREEN}Shell Options${RESET}"
    printf "%-20s : %s\n" "History Size" "$HISTSIZE entries"
    printf "%-20s : %s\n" "History File" "$HISTFILE"
    
    echo -e "\n${GREEN}Path Information${RESET}"
    echo -e "${CYAN}PATH entries:${RESET}"
    echo -e "${PATH//:/\\n}"
    
    # Show active shell options
    echo -e "\n${GREEN}Active Shell Options:${RESET}"
    shopt | grep -E "^shopt -s" | sort | column -t
    
    # Check for common tools and show versions
    echo -e "\n${GREEN}Installed Tools:${RESET}"
    for tool in git python3 python nodejs npm gcc curl wget; do
        if command -v $tool &>/dev/null; then
            local version=$($tool --version 2>/dev/null | head -1)
            printf "%-10s : %s\n" "$tool" "${version:-installed}"
        fi
    done
}

# Alias for environment info
alias sysinfo="env_info"

# ===========================================
# Session Initialization 
# ===========================================

# Check connection to the outside world
function check_connectivity() {
    # Don't bother if already checked recently
    if [ -n "$_CONNECTIVITY_CHECKED" ]; then
        return
    fi
    
    # Try to ping a reliable host with short timeout
    local connected=0
    for host in 1.1.1.1 8.8.8.8 google.com cloudflare.com; do
        if ping -c 1 -W 1 $host &>/dev/null; then
            connected=1
            break
        fi
    done
    
    # Set flag to avoid checking again in this session
    export _CONNECTIVITY_CHECKED=1
    
    if [ $connected -eq 1 ]; then
        export _INTERNET_AVAILABLE=1
    else
        export _INTERNET_AVAILABLE=0
        if [ "$VERBOSE_MODULE_LOAD" == "1" ]; then
            echo -e "${YELLOW}Warning: No internet connection detected. Some features may be limited.${RESET}"
        fi
    fi
}

# Run connectivity check in the background
(check_connectivity &) &>/dev/null

# Output module load message if verbose
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}Loaded: ${BOLD}Core Settings Module${RESET}"
fi
