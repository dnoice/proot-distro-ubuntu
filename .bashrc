#!/bin/bash
# ===========================================
# Main Bashrc Configuration for Termux Ubuntu
# ===========================================
# Modular Bash configuration for proot-distro Ubuntu environment in Termux
# FULL DEV STACK CAPABILITIES right from your Android Device
# Author: [Your Name]
# Version: 3.2
# Last Updated: 2025-05-15

# ===========================================
# Core Initialization
# ===========================================

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Backup original PATH early (before any modifications)
export ORIGINAL_PATH="$PATH"

# Start timing if benchmark option is enabled
if [[ "$BASHRC_BENCHMARK" == "1" ]]; then
    BASHRC_START_TIME=$(date +%s.%N)
fi

# ===========================================
# Sanity Check & Dependencies
# ===========================================

# Bash version check - we need at least Bash 4.0 for most features
bash_version=$(bash --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+' | head -n1)
bash_major=$(echo "$bash_version" | cut -d. -f1)
bash_minor=$(echo "$bash_version" | cut -d. -f2)

if [ "$bash_major" -lt 4 ]; then
    echo "Warning: Bash version $bash_version detected. Some features may not work correctly."
    echo "Recommended: Bash 4.0 or higher"
fi

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
    export UBUNTU_VERSION=$(grep "DISTRIB_RELEASE" /etc/lsb-release | cut -d= -f2)
fi

# ===========================================
# Version Information
# ===========================================

# Bashrc system version info
export BASHRC_SYSTEM_VERSION="3.2"
export BASHRC_SYSTEM_DATE="2025-05-15"

# Function to check for updates (if curl is available)
function check_bashrc_updates() {
    if command -v curl &>/dev/null; then
        # This would connect to a version endpoint in a real implementation
        # For now, it's a placeholder for the update check mechanism
        echo "Checking for updates to bashrc system..."
        echo "Current version: $BASHRC_SYSTEM_VERSION"
        echo "No updates available at this time."
    else
        echo "curl not available. Skipping update check."
    fi
}

# Check for updates if auto-update is enabled
if [[ "$BASHRC_AUTO_UPDATE_CHECK" == "1" ]]; then
    check_bashrc_updates
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
    # Attempt to source the module loader with error handling
    if ! source "${BASHRC_MODULES_PATH}/00-module-loader.sh"; then
        echo "Error: Failed to load module system. Using fallback configuration."
        
        # Basic fallback configuration to ensure usability
        PS1='\u@\h:\w\$ '
        alias ls='ls --color=auto'
        alias ll='ls -la'
    fi
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

# Display benchmark results if enabled
if [[ "$BASHRC_BENCHMARK" == "1" ]]; then
    BASHRC_END_TIME=$(date +%s.%N)
    BASHRC_TOTAL_TIME=$(echo "$BASHRC_END_TIME - $BASHRC_START_TIME" | bc)
    echo "Bashrc loading time: ${BASHRC_TOTAL_TIME} seconds"
fi

# Clear any leftover environment variables if needed
unset FIRST_RUN
