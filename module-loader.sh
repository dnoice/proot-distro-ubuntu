#!/bin/bash
# ===========================================
# Module Loader
# ===========================================
# The core system that loads all modular bashrc components
# Author: Claude & Me
# Version: 1.0
# Last Updated: 2025-05-14

# ===========================================
# Environment Variables
# ===========================================

# Define paths
BASHRC_MODULES_PATH="${HOME}/.bashrc.d"

# Set default options
VERBOSE_MODULE_LOAD=${VERBOSE_MODULE_LOAD:-0}
DISABLE_WELCOME=${DISABLE_WELCOME:-0}

# ===========================================
# Module Loading Function
# ===========================================

# Function to load a module
function load_module() {
    local module="$1"
    local module_path="${BASHRC_MODULES_PATH}/${module}"
    
    if [ -f "$module_path" ]; then
        if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
            echo -e "${BLUE}Loading module: ${BOLD}${module}${RESET}"
        fi
        source "$module_path"
    else
        echo -e "${RED}Warning: Module not found: ${BOLD}${module}${RESET}"
    fi
}

# ===========================================
# Module Loading Sequence
# ===========================================

# Create the module directory if it doesn't exist
if [ ! -d "$BASHRC_MODULES_PATH" ]; then
    mkdir -p "$BASHRC_MODULES_PATH"
    
    # Inform the user about the new directory
    echo -e "${GREEN}Created module directory: ${BOLD}${BASHRC_MODULES_PATH}${RESET}"
    echo "This directory will hold all your modular bashrc components."
    echo
fi

# Initialize the early environment and color variables
# (This is necessary to ensure colors are available before loading other modules)
export RESET=$(tput sgr0)
export BLACK=$(tput setaf 0)
export RED=$(tput setaf 1)
export GREEN=$(tput setaf 2)
export YELLOW=$(tput setaf 3)
export BLUE=$(tput setaf 4)
export PURPLE=$(tput setaf 5)
export CYAN=$(tput setaf 6)
export WHITE=$(tput setaf 7)
export BOLD=$(tput bold)
export BOLD_RED="${BOLD}${RED}"
export BOLD_GREEN="${BOLD}${GREEN}"
export BOLD_YELLOW="${BOLD}${YELLOW}"
export BOLD_BLUE="${BOLD}${BLUE}"
export BOLD_PURPLE="${BOLD}${PURPLE}"
export BOLD_CYAN="${BOLD}${CYAN}"
export BOLD_WHITE="${BOLD}${WHITE}"

# Define the loading order for modules
modules=(
    "01-core-settings.sh"
    "02-prompt.sh"
    "03-storage-navigation.sh"
    "04-file-operations.sh"
    "05-git-integration.sh"
    "06-python-development.sh"
    "07-system-management.sh"
    "08-productivity-tools.sh"
    "09-network-utilities.sh"
    "10-custom-utilities.sh"
    # Additional modules can be added here
)

# Load all modules in order
for module in "${modules[@]}"; do
    load_module "$module"
done

# ===========================================
# Post-Loading Actions
# ===========================================

# Display welcome message if not disabled
if [[ "$DISABLE_WELCOME" != "1" ]]; then
    # Check if welcome function exists
    if declare -f welcome > /dev/null; then
        welcome
    else
        # Fallback welcome message if the welcome function is not defined
        echo -e "${GREEN}Welcome to ${BOLD}Ubuntu in Termux${RESET}"
        echo -e "Type ${CYAN}help${RESET} to see available commands"
    fi
fi

# Notify user that all modules are loaded
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}All modules loaded successfully!${RESET}"
fi

# ===========================================
# User Custom Extensions
# ===========================================

# Load user's custom configuration if it exists
if [ -f "${HOME}/.bashrc.custom" ]; then
    if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
        echo -e "${BLUE}Loading custom user configuration...${RESET}"
    fi
    source "${HOME}/.bashrc.custom"
fi

# Save original PATH as a backup
export ORIGINAL_PATH="$PATH"

# Function to restore original PATH
function restore_path() {
    export PATH="$ORIGINAL_PATH"
    echo -e "${GREEN}PATH restored to original state${RESET}"
}

# Function to show available modules
function list_modules() {
    echo -e "${GREEN}Available bashrc modules:${RESET}"
    
    local count=0
    for module in "${BASHRC_MODULES_PATH}"/*.sh; do
        if [ -f "$module" ]; then
            local module_name=$(basename "$module")
            local module_title=$(head -n 3 "$module" | grep -i "# =" | sed 's/# =\+\s*//')
            
            echo -e "${CYAN}$module_name${RESET} - $module_title"
            count=$((count + 1))
        fi
    done
    
    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}No modules found in $BASHRC_MODULES_PATH${RESET}"
    else
        echo
        echo -e "${GREEN}Total modules: $count${RESET}"
        echo -e "Modules are loaded from: ${CYAN}$BASHRC_MODULES_PATH${RESET}"
        echo -e "To enable verbose loading: ${CYAN}export VERBOSE_MODULE_LOAD=1${RESET}"
    fi
}

# Function to reload all modules
function reload_modules() {
    echo -e "${YELLOW}Reloading all bashrc modules...${RESET}"
    
    # Set verbose mode temporarily for this reload
    local original_verbose="$VERBOSE_MODULE_LOAD"
    VERBOSE_MODULE_LOAD=1
    
    # Load all modules again
    for module in "${modules[@]}"; do
        load_module "$module"
    done
    
    # Restore original verbose setting
    VERBOSE_MODULE_LOAD="$original_verbose"
    
    echo -e "${GREEN}All modules reloaded successfully!${RESET}"
}

# Function to enable/disable welcome message
function toggle_welcome() {
    if [[ "$DISABLE_WELCOME" == "1" ]]; then
        DISABLE_WELCOME=0
        echo -e "${GREEN}Welcome message enabled${RESET}"
    else
        DISABLE_WELCOME=1
        echo -e "${YELLOW}Welcome message disabled${RESET}"
    fi
}

# Function to edit a module
function edit_module() {
    local module="$1"
    
    if [ -z "$module" ]; then
        echo -e "${RED}Usage: edit_module <module_name>${RESET}"
        echo -e "Use ${CYAN}list_modules${RESET} to see available modules"
        return 1
    fi
    
    # Add .sh extension if not provided
    if [[ ! "$module" =~ \.sh$ ]]; then
        module="${module}.sh"
    fi
    
    local module_path="${BASHRC_MODULES_PATH}/${module}"
    
    if [ ! -f "$module_path" ]; then
        echo -e "${RED}Module not found: ${BOLD}${module}${RESET}"
        return 1
    fi
    
    # Open module in editor
    if [ -n "$EDITOR" ]; then
        $EDITOR "$module_path"
    elif command -v nano &> /dev/null; then
        nano "$module_path"
    elif command -v vim &> /dev/null; then
        vim "$module_path"
    else
        echo -e "${RED}No editor found. Set \$EDITOR or install nano/vim${RESET}"
        return 1
    fi
    
    # Reload the module after editing
    echo -e "${YELLOW}Reloading module: ${BOLD}${module}${RESET}"
    source "$module_path"
    
    echo -e "${GREEN}Module edited and reloaded: ${BOLD}${module}${RESET}"
}

# Aliases for module management
alias lsmod="list_modules"
alias reload="reload_modules"
alias bashrc="edit_module"
