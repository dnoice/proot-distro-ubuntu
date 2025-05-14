#!/bin/bash
# ===========================================
# Module Loader
# ===========================================
# The core system that loads all modular bashrc components
# Author: Claude & Me
# Version: 1.1
# Last Updated: 2025-05-14

# ===========================================
# Environment Variables
# ===========================================

# Define paths
BASHRC_MODULES_PATH="${HOME}/.bashrc.d"

# Set default options
VERBOSE_MODULE_LOAD=${VERBOSE_MODULE_LOAD:-0}
DISABLE_WELCOME=${DISABLE_WELCOME:-0}

# Module control options
DISABLED_MODULES=${DISABLED_MODULES:-""}         # Comma-separated list of modules to skip
MODULE_DEPENDENCIES=()                           # Array to track module dependencies
MODULE_LOAD_TIMES=()                             # Array to track module load times
MODULES_UPDATE_CHECK_INTERVAL=7                  # Days between module update checks

# ===========================================
# Module Management Functions
# ===========================================

# Function to check if a module is disabled
function is_module_disabled() {
    local module="$1"
    if [[ "$DISABLED_MODULES" == *"$module"* ]]; then
        return 0  # True, module is disabled
    fi
    return 1  # False, module is not disabled
}

# Function to load a module with dependency and performance tracking
function load_module() {
    local module="$1"
    local module_path="${BASHRC_MODULES_PATH}/${module}"
    
    # Skip if module is disabled
    if is_module_disabled "$module"; then
        if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
            echo -e "${YELLOW}Skipping disabled module: ${BOLD}${module}${RESET}"
        fi
        return 0
    fi
    
    if [ -f "$module_path" ]; then
        if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
            echo -e "${BLUE}Loading module: ${BOLD}${module}${RESET}"
        fi
        
        # Track module load time if benchmarking is enabled
        if [[ "$BASHRC_BENCHMARK" == "1" ]]; then
            local start_time=$(date +%s.%N)
            source "$module_path"
            local status=$?
            local end_time=$(date +%s.%N)
            local load_time=$(echo "$end_time - $start_time" | bc)
            MODULE_LOAD_TIMES+=("$module:$load_time")
        else
            source "$module_path"
            local status=$?
        fi
        
        # Add to loaded modules list
        LOADED_MODULES+=("$module")
        
        # Return the source command's exit status
        return $status
    else
        echo -e "${RED}Warning: Module not found: ${BOLD}${module}${RESET}"
        return 1
    fi
}

# Function to check module health
function check_module_health() {
    local module="$1"
    local module_path="${BASHRC_MODULES_PATH}/${module}"
    
    if [ ! -f "$module_path" ]; then
        echo -e "${RED}✗ Module not found: ${BOLD}${module}${RESET}"
        return 1
    fi
    
    # Basic syntax check
    bash -n "$module_path" &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Syntax error in module: ${BOLD}${module}${RESET}"
        bash -n "$module_path"
        return 1
    fi
    
    # Check for common issues (like missing fi or done)
    if grep -q "then" "$module_path" && ! grep -q "fi" "$module_path"; then
        echo -e "${YELLOW}⚠ Warning: 'then' without 'fi' in module: ${BOLD}${module}${RESET}"
    fi
    
    if grep -q "do" "$module_path" && ! grep -q "done" "$module_path"; then
        echo -e "${YELLOW}⚠ Warning: 'do' without 'done' in module: ${BOLD}${module}${RESET}"
    fi
    
    # Check for module version if available
    local version=$(grep -o "Version: [0-9.]\+" "$module_path" | head -1 | cut -d' ' -f2)
    if [ -n "$version" ]; then
        echo -e "${GREEN}✓ Module ${BOLD}${module}${RESET}${GREEN} (version: $version) passed health check${RESET}"
    else
        echo -e "${GREEN}✓ Module ${BOLD}${module}${RESET}${GREEN} passed health check${RESET}"
    fi
    
    return 0
}

# Function to check for module updates
function check_modules_for_updates() {
    local last_check_file="${BASHRC_MODULES_PATH}/.last_update_check"
    
    # Check if we should run the update check based on the interval
    if [ -f "$last_check_file" ]; then
        local last_check=$(cat "$last_check_file")
        local current_time=$(date +%s)
        local time_diff=$((current_time - last_check))
        local day_diff=$((time_diff / 86400))
        
        if [ "$day_diff" -lt "$MODULES_UPDATE_CHECK_INTERVAL" ]; then
            # Skip check if within interval
            return 0
        fi
    fi
    
    echo -e "${CYAN}Checking for module updates...${RESET}"
    
    # In a real implementation, this would check a repository or server
    # For now, just check for modules with versions and record the check
    for module in "${BASHRC_MODULES_PATH}"/*.sh; do
        if [ -f "$module" ]; then
            local module_name=$(basename "$module")
            local version=$(grep -o "Version: [0-9.]\+" "$module" | head -1 | cut -d' ' -f2)
            
            if [ -n "$version" ]; then
                echo -e "${GREEN}✓ Module ${BOLD}${module_name}${RESET}${GREEN} (version: $version)${RESET}"
            fi
        fi
    done
    
    # Record this check
    date +%s > "$last_check_file"
    echo -e "${GREEN}All modules are up to date.${RESET}"
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

# Initialize arrays for tracking loaded modules
LOADED_MODULES=()

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

# Define the loading order for modules with priorities
# Format: "priority:module_name.sh"
module_priorities=(
    "10:01-core-settings.sh"
    "20:02-prompt.sh"
    "30:03-storage-navigation.sh"
    "40:04-file-operations.sh"
    "50:05-git-integration.sh"
    "60:06-python-development.sh"
    "70:07-system-management.sh"
    "80:08-productivity-tools.sh"
    "90:09-network-utilities.sh"
    "100:10-custom-utilities.sh"
    # Additional modules can be added here with priorities
)

# Sort modules by priority
IFS=$'\n' sorted_modules=($(sort <<<"${module_priorities[*]}"))
unset IFS

# Load all modules in priority order
for module_entry in "${sorted_modules[@]}"; do
    # Extract module name from priority:module format
    module=$(echo "$module_entry" | cut -d':' -f2)
    load_module "$module"
done

# ===========================================
# Post-Loading Actions
# ===========================================

# Display benchmark results if enabled
if [[ "$BASHRC_BENCHMARK" == "1" && ${#MODULE_LOAD_TIMES[@]} -gt 0 ]]; then
    echo -e "${CYAN}Module loading times:${RESET}"
    # Sort modules by load time (slowest first)
    IFS=$'\n' sorted_times=($(
        for time_entry in "${MODULE_LOAD_TIMES[@]}"; do
            module_name=$(echo "$time_entry" | cut -d':' -f1)
            load_time=$(echo "$time_entry" | cut -d':' -f2)
            # Format with 6 decimal places for sorting
            printf "%.6f:%s\n" "$load_time" "$module_name"
        done | sort -rn
    ))
    unset IFS
    
    # Display the sorted times
    for time_entry in "${sorted_times[@]}"; do
        load_time=$(echo "$time_entry" | cut -d':' -f1)
        module_name=$(echo "$time_entry" | cut -d':' -f2)
        printf "${YELLOW}%-30s${RESET} ${GREEN}%s seconds${RESET}\n" "$module_name" "$load_time"
    done
fi

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

# Check for module updates if enabled
if [[ "$BASHRC_MODULE_UPDATE_CHECK" == "1" ]]; then
    check_modules_for_updates
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

# Function to restore original PATH
function restore_path() {
    export PATH="$ORIGINAL_PATH"
    echo -e "${GREEN}PATH restored to original state${RESET}"
}

# Function to deduplicate PATH entries
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
    echo -e "${GREEN}PATH deduplicated${RESET}"
}

# Automatically deduplicate PATH to avoid duplicate entries
deduplicate_path

# ===========================================
# Module Management Commands
# ===========================================

# Function to show available modules
function list_modules() {
    echo -e "${GREEN}Available bashrc modules:${RESET}"
    
    local count=0
    for module in "${BASHRC_MODULES_PATH}"/*.sh; do
        if [ -f "$module" ]; then
            local module_name=$(basename "$module")
            local module_title=$(head -n 3 "$module" | grep -i "# =" | sed 's/# =\+\s*//')
            
            # Check if module is disabled
            if is_module_disabled "$module_name"; then
                echo -e "${RED}✗ ${CYAN}$module_name${RESET} - $module_title ${RED}(DISABLED)${RESET}"
            else
                echo -e "${GREEN}✓ ${CYAN}$module_name${RESET} - $module_title"
            fi
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
        echo -e "To disable modules: ${CYAN}export DISABLED_MODULES=\"module1.sh,module2.sh\"${RESET}"
    fi
}

# Function to reload all modules
function reload_modules() {
    echo -e "${YELLOW}Reloading all bashrc modules...${RESET}"
    
    # Set verbose mode temporarily for this reload
    local original_verbose="$VERBOSE_MODULE_LOAD"
    VERBOSE_MODULE_LOAD=1
    
    # Clear loaded modules list
    LOADED_MODULES=()
    
    # Load all modules again
    for module_entry in "${sorted_modules[@]}"; do
        # Extract module name from priority:module format
        module=$(echo "$module_entry" | cut -d':' -f2)
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

# Function to toggle modules on/off
function toggle_module() {
    local module="$1"
    
    if [ -z "$module" ]; then
        echo -e "${RED}Usage: toggle_module <module_name>${RESET}"
        echo -e "Use ${CYAN}list_modules${RESET} to see available modules"
        return 1
    fi
    
    # Add .sh extension if not provided
    if [[ ! "$module" =~ \.sh$ ]]; then
        module="${module}.sh"
    fi
    
    # Check if module exists
    if [ ! -f "${BASHRC_MODULES_PATH}/${module}" ]; then
        echo -e "${RED}Module not found: ${BOLD}${module}${RESET}"
        return 1
    fi
    
    # Check if module is already disabled
    if is_module_disabled "$module"; then
        # Module is disabled, enable it
        DISABLED_MODULES=$(echo "$DISABLED_MODULES" | sed "s/,\?$module//g")
        echo -e "${GREEN}Module ${BOLD}${module}${RESET}${GREEN} enabled${RESET}"
    else
        # Module is enabled, disable it
        if [ -z "$DISABLED_MODULES" ]; then
            DISABLED_MODULES="$module"
        else
            DISABLED_MODULES="${DISABLED_MODULES},$module"
        fi
        echo -e "${YELLOW}Module ${BOLD}${module}${RESET}${YELLOW} disabled${RESET}"
    fi
    
    # Offer to reload modules
    echo -e "${YELLOW}Reload modules now? [y/N]${RESET}"
    read -r confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        reload_modules
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
    
    # Verify module health after editing
    echo -e "${YELLOW}Verifying module health...${RESET}"
    check_module_health "$module"
    
    # Reload the module after editing
    echo -e "${YELLOW}Reloading module: ${BOLD}${module}${RESET}"
    source "$module_path"
    
    echo -e "${GREEN}Module edited and reloaded: ${BOLD}${module}${RESET}"
}

# Function to run health check on all modules
function health_check() {
    echo -e "${CYAN}Running health check on all modules...${RESET}"
    
    local all_passed=1
    for module in "${BASHRC_MODULES_PATH}"/*.sh; do
        if [ -f "$module" ]; then
            local module_name=$(basename "$module")
            if ! check_module_health "$module_name"; then
                all_passed=0
            fi
        fi
    done
    
    if [ $all_passed -eq 1 ]; then
        echo -e "${GREEN}All modules passed health check!${RESET}"
    else
        echo -e "${YELLOW}Some modules have issues. Fix them with ${CYAN}edit_module <module_name>${RESET}"
    fi
}

# Aliases for module management
alias lsmod="list_modules"
alias reload="reload_modules"
alias bashrc="edit_module"
alias health="health_check"
alias togglemod="toggle_module"
