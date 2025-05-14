#!/bin/bash
# ===========================================
# Core Settings & Environment Configuration
# ===========================================
# Sets up basic environment behavior, history settings, and shell options
# Author: Claude & Me
# Version: 1.0
# Last Updated: 2025-05-14

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# ===========================================
# History Configuration
# ===========================================

# Don't put duplicate lines or lines starting with space in the history
HISTCONTROL=ignoreboth

# Append to the history file, don't overwrite it
shopt -s histappend

# Set history length
HISTSIZE=10000
HISTFILESIZE=20000

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

# Add user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# Add user's private .local/bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# Add custom scripts directory if it exists
if [ -d "$HOME/scripts" ] ; then
    PATH="$HOME/scripts:$PATH"
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

# Output module load message if verbose
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}Loaded: ${BOLD}Core Settings Module${RESET}"
fi
