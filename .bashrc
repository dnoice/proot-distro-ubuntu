#!/bin/bash
# ===========================================
# Main Bashrc Configuration for Termux Ubuntu
# ===========================================
# Modular Bash configuration for proot-distro Ubuntu environment in Termux
# FULL DEV STACK CAPABILITIES right from your Android Device
# Author: Claude & Me
# Version: 3.0
# Last Updated: 2025-05-14

# ===========================================
# Core Initialization
# ===========================================

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# ===========================================
# Environment Detection
# ===========================================

# Detect if we're in Termux environment
if [ -d "/data/data/com.termux" ]; then
    export TERMUX_ENVIRONMENT=1
fi

# Detect if we're in proot-distro Ubuntu
if [ -f "/etc/lsb-release" ] && grep -q "Ubuntu" "/etc/lsb-release"; then
    export UBUNTU_PROOT=1
fi

# ===========================================
# Load Modular Configuration
# ===========================================

# Set module directory path
export BASHRC_MODULES_PATH="${HOME}/.bashrc.d"

# Create the modules directory if it doesn't exist
if [ ! -d "$BASHRC_MODULES_PATH" ]; then
    mkdir -p "$BASHRC_MODULES_PATH"
fi

# Source the module loader if it exists
if [ -f "${BASHRC_MODULES_PATH}/00-module-loader.sh" ]; then
    source "${BASHRC_MODULES_PATH}/00-module-loader.sh"
else
    echo "Module loader not found. Running first-time setup..."
    
    # Create necessary directories
    mkdir -p "${BASHRC_MODULES_PATH}"
    
    # Show instructions for initial setup
    echo "Please copy your module files to: ${BASHRC_MODULES_PATH}"
    echo "Then run: source ~/.bashrc"
fi

# ===========================================
# Post-Initialization Cleanup
# ===========================================

# Clear any leftover environment variables if needed
unset FIRST_RUN
