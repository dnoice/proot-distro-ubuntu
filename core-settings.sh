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

# ===========================================
# Terminal Capability Detection
# ===========================================

# Detect terminal capabilities
TERM_COLORS=$(tput colors 2>/dev/null || echo 0)
TERM_LINES=$(tput lines 2>/dev/null || echo 24)
TERM_COLS=$(tput cols 2>/dev/null || echo 80)

# Adjust settings based on terminal capabilities
if [ "$TERM_COLORS" -ge 256 ]; then
    export COLORTERM="truecolor"
fi

# ===========================================
# Security Settings
# ===========================================

# Set more secure default umask (only user can read/write new files)
umask 077

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
shopt -s histappend

# Write history after each command (synchronize across sessions)
export PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}history -a"

# Set history length
HISTSIZE=10000
HISTFILESIZE=20000

# Add timestamps to history
export HISTTIMEFORMAT="%F %T "

# ===========================================
# Shell Options
# ===========================================

# Check window size after each command
shopt -s checkwinsize

# Use extended pattern matching features
shopt -s extglob

# Enable ** recursive glob for pathname expansion
shopt -s globstar 2> /dev/null

# Case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob

# Autocorrect typos in path names when using `cd`
shopt -s cdspell

# Enable autocd (change directories without using cd)
shopt -s autocd 2> /dev/null

# Correct minor errors in directory names during completion
shopt -s dirspell 2> /dev/null

# When changing directory, add previous directory to stack
shopt -s dirpersist 2> /dev/null

# Make less more friendly for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Set variable identifying the chroot you work in
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# ===========================================
# Programmable Completion
# ===========================================

# Enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# ===========================================
# Default Editor
# ===========================================

# Check for preferred editors in order
if command -v vim &> /dev/null; then
    export EDITOR='vim'
    export VISUAL='vim'
elif command -v nano &> /dev/null; then
    export EDITOR='nano'
    export VISUAL='nano'
fi

# Set pager
export PAGER='less'
export LESS='-R -i -g -c -W'

# ===========================================
# Terminal Colors
# ===========================================

# Set common colors for use in other scripts
export RESET="$(tput sgr0)"
export BLACK="$(tput setaf 0)"
export RED="$(tput setaf 1)"
export GREEN="$(tput setaf 2)"
export YELLOW="$(tput setaf 3)"
export BLUE="$(tput setaf 4)"
export PURPLE="$(tput setaf 5)"
export CYAN="$(tput setaf 6)"
export WHITE="$(tput setaf 7)"
export BOLD="$(tput bold)"
export BOLD_RED="${BOLD}${RED}"
export BOLD_GREEN="${BOLD}${GREEN}"
export BOLD_YELLOW="${BOLD}${YELLOW}"
export BOLD_BLUE="${BOLD}${BLUE}"
export BOLD_PURPLE="${BOLD}${PURPLE}"
export BOLD_CYAN="${BOLD}${CYAN}"
export BOLD_WHITE="${BOLD}${WHITE}"

# ===========================================
# Default PATH Enhancement 
# ===========================================

# Path manipulation function - adds directory to PATH if it exists and isn't already in PATH
function path_add() {
    if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
        PATH="${1}:${PATH}"
    fi
}

# Add user's private bins in order of preference
path_add "$HOME/bin"
path_add "$HOME/.local/bin"
path_add "$HOME/scripts"
path_add "$HOME/.cargo/bin"
path_add "$HOME/go/bin"
path_add "$HOME/.npm/bin"

# Deduplicate PATH entries (this is now handled by the module-loader)
# Just in case module-loader hasn't defined the function yet
if ! type deduplicate_path &>/dev/null; then
    function deduplicate_path() {
        if [ -n "$PATH" ]; then
            old_PATH=$PATH:
            PATH=
            while [ -n "$old_PATH" ]; do
                x=${old_PATH%%:*}
                case $PATH: in
                    *:"$x":*) ;;
                    *) PATH=$PATH:$x ;;
                esac
                old_PATH=${old_PATH#*:}
            done
            PATH=${PATH#:}
        fi
    }
    deduplicate_path
fi

# ===========================================
# Default Aliases
# ===========================================

# Color support for common commands
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls="ls --color=auto"
    alias dir="dir --color=auto"
    alias vdir="vdir --color=auto"
    alias grep="grep --color=auto"
    alias fgrep="fgrep --color=auto"
    alias egrep="egrep --color=auto"
    alias diff="diff --color=auto"
    alias ip="ip -color=auto"
fi

# Basic aliases for common commands
alias l="ls -CF"
alias ll="ls -alF"
alias la="ls -A"
alias h="history"
alias c="clear"
alias e="$EDITOR"
alias q="exit"
alias :q="exit"  # For vim users
alias path="echo -e ${PATH//:/\\n}"

# ===========================================
# Termux-specific settings
# ===========================================

# Check if running in Termux
if [ -d "/data/data/com.termux" ]; then
    # Termux-specific settings
    export TERMUX=1
    
    # Check for termux-tools
    if command -v termux-info &> /dev/null; then
        export TERMUX_VERSION=$(termux-info | grep termux-app | awk '{print $2}')
    fi
    
    # Set up Ubuntu proot paths
    if [ -d "/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/ubuntu" ]; then
        export UBUNTU_PROOT_PATH="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/ubuntu"
    fi
fi

# ===========================================
# Environment Summary Function
# ===========================================

# Function to display environment information
function env_info() {
    echo -e "${GREEN}Environment Information${RESET}"
    echo -e "${CYAN}Shell:${RESET} $SHELL ($(bash --version | head -1 | cut -d' ' -f4))"
    echo -e "${CYAN}User:${RESET} $(whoami) ($(id -u))"
    echo -e "${CYAN}Hostname:${RESET} $(hostname)"
    echo -e "${CYAN}Terminal:${RESET} $TERM (${TERM_COLORS} colors, ${TERM_LINES}x${TERM_COLS})"
    echo -e "${CYAN}Locale:${RESET} $LANG"
    echo -e "${CYAN}Editor:${RESET} $EDITOR"
    
    echo -e "\n${GREEN}Directory Information${RESET}"
    echo -e "${CYAN}Current:${RESET} $PWD"
    echo -e "${CYAN}Home:${RESET} $HOME"
    
    if [ -n "$TERMUX" ]; then
        echo -e "\n${GREEN}Termux Information${RESET}"
        echo -e "${CYAN}Termux Version:${RESET} ${TERMUX_VERSION:-Unknown}"
        if [ -n "$UBUNTU_PROOT_PATH" ]; then
            echo -e "${CYAN}Ubuntu Path:${RESET} $UBUNTU_PROOT_PATH"
        fi
        if [ -n "$UBUNTU_VERSION" ]; then
            echo -e "${CYAN}Ubuntu Version:${RESET} $UBUNTU_VERSION"
        fi
    fi
    
    echo -e "\n${GREEN}Shell Options${RESET}"
    echo -e "${CYAN}History Size:${RESET} $HISTSIZE entries"
    echo -e "${CYAN}History File:${RESET} $HISTFILE"
    
    echo -e "\n${GREEN}Path Information${RESET}"
    echo -e "${CYAN}PATH entries:${RESET}"
    echo -e "${PATH//:/\\n}"
}

# Alias for environment info
alias sysinfo="env_info"

# Output module load message if verbose
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}Loaded: ${BOLD}Core Settings Module${RESET}"
fi
