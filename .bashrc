#!/bin/bash
# ===========================================
# Main Bashrc Configuration for Termux Ubuntu
# ===========================================
# Modular Bash configuration for proot-distro Ubuntu environment in Termux
# FULL DEV STACK CAPABILITIES right from your Android Device
# Author: Claude & Me
# Version: 3.1
# Last Updated: 2025-05-14

# ===========================================
# Core Initialization
# ===========================================

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Backup original PATH early (before any modifications)
# This is critical for being able to restore the path later
export ORIGINAL_PATH="${PATH:-$(getconf PATH)}"

# Set error handling behavior to make the script more robust
set -o pipefail 2>/dev/null || true  # Propagate errors through pipes, but don't fail if unsupported

# Start timing if benchmark option is enabled
if [[ "$BASHRC_BENCHMARK" == "1" ]]; then
    BASHRC_START_TIME=$(date +%s.%N 2>/dev/null || date +%s)
fi

# ===========================================
# Sanity Check & Dependencies
# ===========================================

# Bash version check - we need at least Bash 4.0 for most features
bash_version=$(bash --version 2>/dev/null | head -n1 | grep -o '[0-9]\+\.[0-9]\+' | head -n1)
if [ -n "$bash_version" ]; then
    bash_major=$(echo "$bash_version" | cut -d. -f1)
    bash_minor=$(echo "$bash_version" | cut -d. -f2)

    if [ "$bash_major" -lt 4 ]; then
        echo "Warning: Bash version $bash_version detected. Some features may not work correctly."
        echo "Recommended: Bash 4.0 or higher"
    fi
else
    echo "Warning: Could not determine Bash version. Some features may not work correctly."
fi

# ===========================================
# Environment Detection
# ===========================================

# Detect if we're in Termux environment with better protection against false positives
if [ -d "/data/data/com.termux" ] && [ -f "/data/data/com.termux/files/usr/bin/termux-info" ]; then
    export TERMUX_ENVIRONMENT=1
    # Get more details if available
    if command -v termux-info &>/dev/null; then
        export TERMUX_VERSION=$(termux-info 2>/dev/null | grep "termux-package:" | cut -d ' ' -f 2)
    fi
elif [ -d "/data/data/com.termux" ]; then
    # Partial match without termux-info
    export TERMUX_ENVIRONMENT=1
fi

# Detect if we're in proot-distro Ubuntu with better reliability
if [ -f "/etc/lsb-release" ]; then
    if grep -q "Ubuntu" "/etc/lsb-release"; then
        export UBUNTU_PROOT=1
        export UBUNTU_VERSION=$(grep "DISTRIB_RELEASE" /etc/lsb-release | cut -d= -f2)
        # Detect if we're accessed via proot-distro
        if [ -n "$TERMUX_ENVIRONMENT" ] || [ -n "$PROOT_DISTRO_NAME" ] || [ -f "/proot" ]; then
            export PROOT_DETECTED=1
        fi
    fi
fi

# Detect Android version if we're in Termux
if [ -n "$TERMUX_ENVIRONMENT" ] && [ -f "/system/build.prop" ]; then
    export ANDROID_VERSION=$(grep "ro.build.version.release" /system/build.prop 2>/dev/null | cut -d= -f2)
fi

# ===========================================
# Version Information
# ===========================================

# Bashrc system version info
export BASHRC_SYSTEM_VERSION="3.1"
export BASHRC_SYSTEM_DATE="2025-05-14"

# Function to check for updates with improved error handling
function check_bashrc_updates() {
    if ! command -v curl &>/dev/null; then
        if ! command -v wget &>/dev/null; then
            echo "Neither curl nor wget available. Skipping update check."
            return 1
        fi
    fi
    
    echo "Checking for updates to bashrc system..."
    echo "Current version: $BASHRC_SYSTEM_VERSION"
    
    # This would connect to a version endpoint in a real implementation
    # For now, it's a placeholder for the update check mechanism
    # A real implementation would compare the current version with the latest
    
    # Example of a more robust update check:
    # if command -v curl &>/dev/null; then
    #     latest_version=$(curl -s -m 3 https://example.com/version.txt 2>/dev/null)
    # elif command -v wget &>/dev/null; then
    #     latest_version=$(wget -qO- --timeout=3 https://example.com/version.txt 2>/dev/null)
    # fi
    # 
    # if [ -n "$latest_version" ] && [ "$latest_version" != "$BASHRC_SYSTEM_VERSION" ]; then
    #     echo "New version available: $latest_version"
    #     echo "Run 'update_bashrc' to upgrade"
    # else
    #     echo "No updates available at this time."
    # fi
    
    echo "No updates available at this time."
    return 0
}

# Check for updates if auto-update is enabled
if [[ "$BASHRC_AUTO_UPDATE_CHECK" == "1" ]]; then
    check_bashrc_updates
fi

# ===========================================
# Load Modular Configuration
# ===========================================

# Set module directory path with safeguards for edge cases
if [ -n "$HOME" ]; then
    export BASHRC_MODULES_PATH="${HOME}/.bashrc.d"
else
    # Fall back to a reasonable default if HOME is not set
    export BASHRC_MODULES_PATH="/root/.bashrc.d"
    echo "Warning: HOME not set, using default modules path: $BASHRC_MODULES_PATH"
fi

# Create the modules directory if it doesn't exist
if [ ! -d "$BASHRC_MODULES_PATH" ]; then
    mkdir -p "$BASHRC_MODULES_PATH" 2>/dev/null
    
    # Check if directory creation was successful
    if [ ! -d "$BASHRC_MODULES_PATH" ]; then
        echo "Error: Failed to create modules directory. Using fallback configuration."
        # Fallback if directory creation fails
        PS1='\u@\h:\w\$ '
        alias ls='ls --color=auto'
        alias ll='ls -la'
        return 1
    fi
fi

# Initialize essential colors for error reporting even if module loader fails
if [ -t 1 ]; then  # Only set colors for interactive terminal
    RESET=$(tput sgr0 2>/dev/null || echo "")
    RED=$(tput setaf 1 2>/dev/null || echo "")
    GREEN=$(tput setaf 2 2>/dev/null || echo "")
    YELLOW=$(tput setaf 3 2>/dev/null || echo "")
fi

# Source the module loader if it exists with comprehensive error handling
MODULE_LOADER="${BASHRC_MODULES_PATH}/00-module-loader.sh"
if [ -f "$MODULE_LOADER" ]; then
    # Check for syntax errors before sourcing
    if ! bash -n "$MODULE_LOADER" &>/dev/null; then
        echo "${RED}Error: Syntax error in module loader. Using fallback configuration.${RESET}"
        bash -n "$MODULE_LOADER"  # Show the actual error
        
        # Minimal fallback configuration
        PS1='\u@\h:\w\$ '
        alias ls='ls --color=auto'
        alias ll='ls -la'
    else
        # Attempt to source the module loader
        if ! source "$MODULE_LOADER"; then
            echo "${RED}Error: Failed to load module system. Using fallback configuration.${RESET}"
            
            # Basic fallback configuration to ensure usability
            PS1='\u@\h:\w\$ '
            alias ls='ls --color=auto'
            alias ll='ls -la'
        elif [ "${VERBOSE_MODULE_LOAD:-0}" -eq 1 ]; then
            echo "${GREEN}Module system loaded successfully.${RESET}"
        fi
    fi
else
    echo "${YELLOW}Module loader not found. Running first-time setup...${RESET}"
    
    # Create necessary directories
    mkdir -p "${BASHRC_MODULES_PATH}"
    
    # Show instructions for initial setup
    echo "Please copy your module files to: ${BASHRC_MODULES_PATH}"
    echo "Then run: source ~/.bashrc"
    
    # Create a basic placeholder module loader if it doesn't exist
    if [ ! -f "$MODULE_LOADER" ]; then
        cat > "$MODULE_LOADER" << 'EOF'
#!/bin/bash
# ===========================================
# Module Loader - Placeholder
# ===========================================
# This is a placeholder module loader. Replace with the full version.
# See install.sh for proper installation.

echo "This is a placeholder module loader."
echo "Please install the full version for complete functionality."

# Basic aliases for usability
alias ls='ls --color=auto'
alias ll='ls -la'
EOF
        chmod +x "$MODULE_LOADER"
        echo "Created placeholder module loader. Please install the full version."
    fi
    
    # Basic minimum configuration for usability
    PS1='\u@\h:\w\$ '
    alias ls='ls --color=auto'
    alias ll='ls -la'
fi

# ===========================================
# Post-Initialization Cleanup
# ===========================================

# Display benchmark results if enabled with improved error handling
if [[ "$BASHRC_BENCHMARK" == "1" ]]; then
    BASHRC_END_TIME=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Check if we have bc for floating point arithmetic
    if command -v bc &>/dev/null && [ -n "$BASHRC_START_TIME" ]; then
        BASHRC_TOTAL_TIME=$(echo "$BASHRC_END_TIME - $BASHRC_START_TIME" | bc 2>/dev/null)
        echo "${GREEN}Bashrc loading time: ${BASHRC_TOTAL_TIME} seconds${RESET}"
    else
        # Simple integer calculation as fallback
        BASHRC_TOTAL_TIME=$((BASHRC_END_TIME - BASHRC_START_TIME))
        echo "${GREEN}Bashrc loading time: approximately ${BASHRC_TOTAL_TIME} seconds${RESET}"
    fi
fi

# Function to reset to a clean slate if something goes wrong
function reset_bashrc() {
    echo "${YELLOW}Resetting bashrc configuration to defaults...${RESET}"
    
    # Restore original PATH
    if [ -n "$ORIGINAL_PATH" ]; then
        export PATH="$ORIGINAL_PATH"
    fi
    
    # Basic usable configuration
    PS1='\u@\h:\w\$ '
    alias ls='ls --color=auto'
    alias ll='ls -la'
    alias la='ls -la'
    
    # Source the default system bashrc if available
    if [ -f "/etc/bash.bashrc" ]; then
        source "/etc/bash.bashrc"
    fi
    
    echo "${GREEN}Bashrc reset to default configuration.${RESET}"
    echo "To restore modules, run: source ~/.bashrc"
}

# Clear any leftover environment variables if needed
unset FIRST_RUN
