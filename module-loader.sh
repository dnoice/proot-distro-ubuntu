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
# Error Handling Improvement
# ===========================================

# Set error handling behavior to make the script more robust
set -o pipefail  # Propagate errors through pipes
trap 'echo "Error: Module loader encountered an error on line $LINENO" >&2' ERR

# ===========================================
# Module Management Functions
# ===========================================

# Function to check if a module is disabled (with improved pattern matching)
function is_module_disabled() {
    local module="$1"
    if [[ ",$DISABLED_MODULES," == *",$module,"* ]]; then
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
    
    # Check if the module exists
    if [ ! -f "$module_path" ]; then
        echo -e "${RED}Warning: Module not found: ${BOLD}${module}${RESET}"
        return 1
    fi
    
    # Verify script syntax before loading to prevent errors
    if ! bash -n "$module_path" &>/dev/null; then
        echo -e "${RED}Error: Syntax error in module: ${BOLD}${module}${RESET}"
        return 1
    fi
    
    # Load the module with performance tracking if enabled
    if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
        echo -e "${BLUE}Loading module: ${BOLD}${module}${RESET}"
    fi
    
    # Track module load time if benchmarking is enabled
    if [[ "$BASHRC_BENCHMARK" == "1" ]]; then
        local start_time=$(date +%s.%N)
        source "$module_path"
        local status=$?
        local end_time=$(date +%s.%N)
        local load_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
        MODULE_LOAD_TIMES+=("$module:$load_time")
    else
        source "$module_path"
        local status=$?
    fi
    
    # Add to loaded modules list if successful
    if [ $status -eq 0 ]; then
        LOADED_MODULES+=("$module")
    else
        echo -e "${RED}Failed to load module: ${BOLD}${module}${RESET}"
    fi
    
    # Return the source command's exit status
    return $status
}

# Function to check module health with improved diagnostics
function check_module_health() {
    local module="$1"
    local module_path="${BASHRC_MODULES_PATH}/${module}"
    local issues_found=0
    
    if [ ! -f "$module_path" ]; then
        echo -e "${RED}✗ Module not found: ${BOLD}${module}${RESET}"
        return 1
    fi
    
    # Basic syntax check
    bash -n "$module_path" &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Syntax error in module: ${BOLD}${module}${RESET}"
        bash -n "$module_path"
        issues_found=1
    fi
    
    # Check for common issues that can cause subtle bugs
    if grep -q "then" "$module_path" && ! grep -q "fi" "$module_path"; then
        echo -e "${YELLOW}⚠ Warning: 'then' without 'fi' in module: ${BOLD}${module}${RESET}"
        issues_found=1
    fi
    
    if grep -q "do" "$module_path" && ! grep -q "done" "$module_path"; then
        echo -e "${YELLOW}⚠ Warning: 'do' without 'done' in module: ${BOLD}${module}${RESET}"
        issues_found=1
    fi
    
    # Check for unbound variables that could cause issues
    if grep -q "\$[A-Za-z_][A-Za-z0-9_]*" "$module_path"; then
        local potentially_unbound=$(grep -o "\$[A-Za-z_][A-Za-z0-9_]*" "$module_path" | sort | uniq)
        # This is just a warning as not all variables need to be initialized
        if [ "$VERBOSE_MODULE_LOAD" == "1" ]; then
            echo -e "${YELLOW}ℹ Module ${BOLD}${module}${RESET}${YELLOW} uses variables: ${potentially_unbound}${RESET}"
        fi
    fi
    
    # Check for potential security issues like eval usage
    if grep -q "eval[ \t]" "$module_path"; then
        echo -e "${YELLOW}⚠ Warning: Module ${BOLD}${module}${RESET}${YELLOW} uses 'eval' which can be risky${RESET}"
        issues_found=1
    fi
    
    # Check for module version if available
    local version=$(grep -o "Version: [0-9.]\+" "$module_path" | head -1 | cut -d' ' -f2)
    
    if [ $issues_found -eq 0 ]; then
        if [ -n "$version" ]; then
            echo -e "${GREEN}✓ Module ${BOLD}${module}${RESET}${GREEN} (version: $version) passed health check${RESET}"
        else
            echo -e "${GREEN}✓ Module ${BOLD}${module}${RESET}${GREEN} passed health check${RESET}"
        fi
        return 0
    else
        return 1
    fi
}

# Function to check for module updates with caching improvement
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
    
    # Create a temporary file to hold module versions
    local temp_version_file=$(mktemp)
    local updates_available=0
    
    # In a real implementation, this would check a repository or server
    # For now, just check for modules with versions and record the check
    for module in "${BASHRC_MODULES_PATH}"/*.sh; do
        if [ -f "$module" ]; then
            local module_name=$(basename "$module")
            local version=$(grep -o "Version: [0-9.]\+" "$module" | head -1 | cut -d' ' -f2)
            
            if [ -n "$version" ]; then
                echo "$module_name:$version" >> "$temp_version_file"
                echo -e "${GREEN}✓ Module ${BOLD}${module_name}${RESET}${GREEN} (version: $version)${RESET}"
            fi
        fi
    done
    
    # Compare with previous versions if available
    local version_history_file="${BASHRC_MODULES_PATH}/.module_versions"
    if [ -f "$version_history_file" ]; then
        while IFS=: read -r mod_name mod_version; do
            local current_version=$(grep "^$mod_name:" "$temp_version_file" | cut -d: -f2)
            if [ -n "$current_version" ] && [ "$current_version" != "$mod_version" ]; then
                echo -e "${YELLOW}Module ${BOLD}${mod_name}${RESET}${YELLOW} updated from $mod_version to $current_version${RESET}"
                updates_available=1
            fi
        done < "$version_history_file"
    fi
    
    # Save current versions for future comparison
    mv "$temp_version_file" "$version_history_file"
    
    # Record this check
    date +%s > "$last_check_file"
    
    if [ $updates_available -eq 0 ]; then
        echo -e "${GREEN}All modules are up to date.${RESET}"
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

# Initialize arrays for tracking loaded modules
LOADED_MODULES=()

# Initialize the early environment and color variables
# (This is necessary to ensure colors are available before loading other modules)
if [ -t 1 ]; then  # Only set colors for interactive terminal
    export RESET=$(tput sgr0 2>/dev/null || echo "")
    export BLACK=$(tput setaf 0 2>/dev/null || echo "")
    export RED=$(tput setaf 1 2>/dev/null || echo "")
    export GREEN=$(tput setaf 2 2>/dev/null || echo "")
    export YELLOW=$(tput setaf 3 2>/dev/null || echo "")
    export BLUE=$(tput setaf 4 2>/dev/null || echo "")
    export PURPLE=$(tput setaf 5 2>/dev/null || echo "")
    export CYAN=$(tput setaf 6 2>/dev/null || echo "")
    export WHITE=$(tput setaf 7 2>/dev/null || echo "")
    export BOLD=$(tput bold 2>/dev/null || echo "")
    export BOLD_RED="${BOLD}${RED}"
    export BOLD_GREEN="${BOLD}${GREEN}"
    export BOLD_YELLOW="${BOLD}${YELLOW}"
    export BOLD_BLUE="${BOLD}${BLUE}"
    export BOLD_PURPLE="${BOLD}${PURPLE}"
    export BOLD_CYAN="${BOLD}${CYAN}"
    export BOLD_WHITE="${BOLD}${WHITE}"
else
    # Define empty colors for non-interactive sessions
    export RESET="" BLACK="" RED="" GREEN="" YELLOW="" BLUE="" PURPLE="" CYAN="" WHITE="" BOLD=""
    export BOLD_RED="" BOLD_GREEN="" BOLD_YELLOW="" BOLD_BLUE="" BOLD_PURPLE="" BOLD_CYAN="" BOLD_WHITE=""
fi

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

# Sort modules by priority with improved error handling
if [ ${#module_priorities[@]} -gt 0 ]; then
    IFS=$'\n' sorted_modules=($(sort <<<"${module_priorities[*]}" 2>/dev/null))
    unset IFS
    
    if [ ${#sorted_modules[@]} -eq 0 ]; then
        # Fallback if sort fails
        sorted_modules=("${module_priorities[@]}")
    fi
else
    # Auto-discover modules if priorities not defined
    sorted_modules=()
    for module in "${BASHRC_MODULES_PATH}"/*.sh; do
        if [ -f "$module" ] && [[ "$module" != *"00-module-loader.sh" ]]; then
            sorted_modules+=("999:$(basename "$module")")
        fi
    done
    
    # Sort the discovered modules
    if [ ${#sorted_modules[@]} -gt 0 ]; then
        IFS=$'\n' sorted_modules=($(sort <<<"${sorted_modules[*]}" 2>/dev/null))
        unset IFS
    fi
fi

# Load all modules in priority order with progress tracking
total_modules=${#sorted_modules[@]}
loaded_count=0
failed_count=0

for module_entry in "${sorted_modules[@]}"; do
    # Extract module name from priority:module format
    module=$(echo "$module_entry" | cut -d':' -f2)
    
    # Load the module
    if load_module "$module"; then
        loaded_count=$((loaded_count + 1))
    else
        failed_count=$((failed_count + 1))
    fi
    
    # Show progress if verbose
    if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
        echo -e "${CYAN}Progress: $loaded_count/$total_modules modules loaded${RESET}"
    fi
done

# ===========================================
# Post-Loading Actions
# ===========================================

# Display benchmark results if enabled
if [[ "$BASHRC_BENCHMARK" == "1" && ${#MODULE_LOAD_TIMES[@]} -gt 0 ]]; then
    echo -e "${CYAN}Module loading times:${RESET}"
    
    # Calculate total loading time
    total_load_time=0
    for time_entry in "${MODULE_LOAD_TIMES[@]}"; do
        load_time=$(echo "$time_entry" | cut -d':' -f2)
        total_load_time=$(echo "$total_load_time + $load_time" | bc 2>/dev/null || echo "$total_load_time")
    done
    
    # Sort modules by load time (slowest first) with improved error handling
    IFS=$'\n' sorted_times=($(
        for time_entry in "${MODULE_LOAD_TIMES[@]}"; do
            module_name=$(echo "$time_entry" | cut -d':' -f1)
            load_time=$(echo "$time_entry" | cut -d':' -f2)
            # Format with 6 decimal places for sorting
            printf "%.6f:%s\n" "$load_time" "$module_name" 2>/dev/null || echo "0:$module_name"
        done | sort -rn 2>/dev/null
    ))
    unset IFS
    
    # Display the sorted times
    if [ ${#sorted_times[@]} -gt 0 ]; then
        for time_entry in "${sorted_times[@]}"; do
            load_time=$(echo "$time_entry" | cut -d':' -f1)
            module_name=$(echo "$time_entry" | cut -d':' -f2)
            # Calculate percentage of total time
            if [ $(echo "$total_load_time > 0" | bc 2>/dev/null || echo "0") -eq 1 ]; then
                percent=$(echo "scale=1; 100 * $load_time / $total_load_time" | bc 2>/dev/null || echo "?")
                printf "${YELLOW}%-30s${RESET} ${GREEN}%s seconds (%.1f%%)${RESET}\n" "$module_name" "$load_time" "$percent"
            else
                printf "${YELLOW}%-30s${RESET} ${GREEN}%s seconds${RESET}\n" "$module_name" "$load_time"
            fi
        done
        
        echo -e "${GREEN}Total loading time: $total_load_time seconds${RESET}"
    fi
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
    if [ $failed_count -eq 0 ]; then
        echo -e "${GREEN}All $loaded_count modules loaded successfully!${RESET}"
    else
        echo -e "${YELLOW}$loaded_count modules loaded, $failed_count modules failed to load${RESET}"
    fi
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
    if [ -n "$ORIGINAL_PATH" ]; then
        export PATH="$ORIGINAL_PATH"
        echo -e "${GREEN}PATH restored to original state${RESET}"
    else
        echo -e "${YELLOW}Original PATH not found${RESET}"
    fi
}

# Function to deduplicate PATH entries with improved algorithm
function deduplicate_path() {
    if [ -n "$PATH" ]; then
        # Create an associative array to track unique entries
        declare -A path_entries
        local new_path=""
        
        # Split PATH and keep only unique entries while preserving order
        IFS=':' read -ra PATHS <<< "$PATH"
        for p in "${PATHS[@]}"; do
            if [ -n "$p" ] && [ -z "${path_entries[$p]}" ]; then
                path_entries[$p]=1
                new_path="${new_path:+$new_path:}$p"
            fi
        done
        
        # Set the new PATH
        if [ -n "$new_path" ]; then
            export PATH="$new_path"
            if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
                echo -e "${GREEN}PATH deduplicated${RESET}"
            fi
        fi
    fi
}

# Automatically deduplicate PATH to avoid duplicate entries
deduplicate_path

# ===========================================
# Module Management Commands
# ===========================================

# Function to show available modules with improved formatting
function list_modules() {
    echo -e "${GREEN}Available bashrc modules:${RESET}"
    
    local count=0
    local enabled_count=0
    local disabled_count=0
    
    printf "%-40s %-30s %-10s\n" "MODULE" "DESCRIPTION" "STATUS"
    printf "%-40s %-30s %-10s\n" "$(printf '%0.s-' {1..40})" "$(printf '%0.s-' {1..30})" "$(printf '%0.s-' {1..10})"
    
    for module in "${BASHRC_MODULES_PATH}"/*.sh; do
        if [ -f "$module" ]; then
            local module_name=$(basename "$module")
            local module_title=$(head -n 5 "$module" | grep -i "# [A-Za-z]" | head -1 | sed 's/# *//')
            
            # If no title found, try to extract from a line with "====="
            if [ -z "$module_title" ]; then
                module_title=$(head -n 5 "$module" | grep -i "# =" | head -1 | sed 's/# =\+\s*//')
            fi
            
            # Still no title? Use a default
            if [ -z "$module_title" ]; then
                module_title="Module $module_name"
            fi
            
            # Truncate title if too long
            if [ ${#module_title} -gt 30 ]; then
                module_title="${module_title:0:27}..."
            fi
            
            # Check if module is disabled
            local status
            if is_module_disabled "$module_name"; then
                status="${RED}DISABLED${RESET}"
                disabled_count=$((disabled_count + 1))
            else
                status="${GREEN}ENABLED${RESET}"
                enabled_count=$((enabled_count + 1))
            fi
            
            printf "%-40s %-30s %-10s\n" "$module_name" "$module_title" "$status"
            count=$((count + 1))
        fi
    done
    
    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}No modules found in $BASHRC_MODULES_PATH${RESET}"
    else
        echo
        echo -e "${GREEN}Total modules: $count (${GREEN}$enabled_count enabled${RESET}, ${RED}$disabled_count disabled${RESET})${RESET}"
        echo -e "Modules directory: ${CYAN}$BASHRC_MODULES_PATH${RESET}"
        echo
        echo -e "${CYAN}Commands:${RESET}"
        echo -e "  ${YELLOW}reload${RESET}     - Reload all modules"
        echo -e "  ${YELLOW}togglemod${RESET}  - Enable/disable a module"
        echo -e "  ${YELLOW}bashrc${RESET}     - Edit a module"
        echo -e "  ${YELLOW}health${RESET}     - Check module health"
        
        if [ $disabled_count -gt 0 ]; then
            echo
            echo -e "${YELLOW}Tip: To enable verbose loading: export VERBOSE_MODULE_LOAD=1${RESET}"
        fi
    fi
}

# Function to reload all modules with progress indication
function reload_modules() {
    echo -e "${YELLOW}Reloading all bashrc modules...${RESET}"
    
    # Set verbose mode temporarily for this reload
    local original_verbose="$VERBOSE_MODULE_LOAD"
    VERBOSE_MODULE_LOAD=1
    
    # Clear loaded modules list and load times
    LOADED_MODULES=()
    MODULE_LOAD_TIMES=()
    
    # Start timing if benchmarking is enabled
    local reload_start_time
    if [[ "$BASHRC_BENCHMARK" == "1" ]]; then
        reload_start_time=$(date +%s.%N)
    fi
    
    # Load all modules again
    local loaded_count=0
    local failed_count=0
    local total_modules=${#sorted_modules[@]}
    
    for module_entry in "${sorted_modules[@]}"; do
        # Extract module name from priority:module format
        module=$(echo "$module_entry" | cut -d':' -f2)
        
        # Show progress
        echo -ne "${CYAN}[${loaded_count}/${total_modules}] Reloading modules...${RESET}\r"
        
        # Load the module
        if load_module "$module"; then
            loaded_count=$((loaded_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
    done
    
    # Clear the progress line
    echo -ne "$(printf '%*s' $(tput cols) '')\r"
    
    # End timing if benchmarking is enabled
    if [[ "$BASHRC_BENCHMARK" == "1" ]]; then
        local reload_end_time=$(date +%s.%N)
        local reload_total_time=$(echo "$reload_end_time - $reload_start_time" | bc 2>/dev/null || echo "?")
        echo -e "${GREEN}Reload completed in $reload_total_time seconds${RESET}"
    fi
    
    # Restore original verbose setting
    VERBOSE_MODULE_LOAD="$original_verbose"
    
    # Show summary
    if [ $failed_count -eq 0 ]; then
        echo -e "${GREEN}All $loaded_count modules reloaded successfully!${RESET}"
    else
        echo -e "${YELLOW}$loaded_count modules reloaded, $failed_count modules failed to load${RESET}"
        echo -e "${YELLOW}Run 'health' to diagnose issues${RESET}"
    fi
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

# Function to toggle modules on/off with improved user experience
function toggle_module() {
    local module="$1"
    
    if [ -z "$module" ]; then
        # List modules in an interactive format
        echo -e "${YELLOW}Available modules:${RESET}"
        local i=0
        local modules=()
        
        for mod_file in "${BASHRC_MODULES_PATH}"/*.sh; do
            if [ -f "$mod_file" ]; then
                local mod_name=$(basename "$mod_file")
                local status
                
                if is_module_disabled "$mod_name"; then
                    status="${RED}DISABLED${RESET}"
                else
                    status="${GREEN}ENABLED${RESET}"
                fi
                
                printf "%2d) %-30s %s\n" $i "$mod_name" "$status"
                modules[$i]="$mod_name"
                i=$((i + 1))
            fi
        done
        
        if [ $i -eq 0 ]; then
            echo -e "${RED}No modules found.${RESET}"
            return 1
        fi
        
        echo
        echo -e "${YELLOW}Enter module number to toggle, or 'q' to quit:${RESET}"
        read -r selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -lt $i ]; then
            module="${modules[$selection]}"
        elif [[ "$selection" == "q" ]]; then
            return 0
        else
            echo -e "${RED}Invalid selection${RESET}"
            return 1
        fi
    else
        # Add .sh extension if not provided
        if [[ ! "$module" =~ \.sh$ ]]; then
            module="${module}.sh"
        fi
    fi
    
    # Check if module exists
    if [ ! -f "${BASHRC_MODULES_PATH}/${module}" ]; then
        echo -e "${RED}Module not found: ${BOLD}${module}${RESET}"
        return 1
    fi
    
    # Check if module is already disabled
    if is_module_disabled "$module"; then
        # Module is disabled, enable it
        DISABLED_MODULES=$(echo ",$DISABLED_MODULES," | sed "s/,$module,/,/" | sed 's/^,//' | sed 's/,$//')
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

# Function to edit a module with syntax checking
function edit_module() {
    local module="$1"
    
    if [ -z "$module" ]; then
        # List modules in an interactive format
        echo -e "${YELLOW}Available modules to edit:${RESET}"
        local i=0
        local modules=()
        
        for mod_file in "${BASHRC_MODULES_PATH}"/*.sh; do
            if [ -f "$mod_file" ]; then
                local mod_name=$(basename "$mod_file")
                printf "%2d) %s\n" $i "$mod_name"
                modules[$i]="$mod_name"
                i=$((i + 1))
            fi
        done
        
        if [ $i -eq 0 ]; then
            echo -e "${RED}No modules found.${RESET}"
            return 1
        fi
        
        echo
        echo -e "${YELLOW}Enter module number to edit, or 'q' to quit:${RESET}"
        read -r selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -lt $i ]; then
            module="${modules[$selection]}"
        elif [[ "$selection" == "q" ]]; then
            return 0
        else
            echo -e "${RED}Invalid selection${RESET}"
            return 1
        fi
    else
        # Add .sh extension if not provided
        if [[ ! "$module" =~ \.sh$ ]]; then
            module="${module}.sh"
        fi
    fi
    
    local module_path="${BASHRC_MODULES_PATH}/${module}"
    
    if [ ! -f "$module_path" ]; then
        echo -e "${RED}Module not found: ${BOLD}${module}${RESET}"
        return 1
    fi
    
    # Create a backup before editing
    local backup_path="${module_path}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$module_path" "$backup_path"
    
    # Open module in editor
    local editor_success=0
    if [ -n "$EDITOR" ]; then
        $EDITOR "$module_path" || editor_success=1
    elif command -v nano &> /dev/null; then
        nano "$module_path" || editor_success=1
    elif command -v vim &> /dev/null; then
        vim "$module_path" || editor_success=1
    else
        echo -e "${RED}No editor found. Set \$EDITOR or install nano/vim${RESET}"
        return 1
    fi
    
    if [ $editor_success -ne 0 ]; then
        echo -e "${RED}Editor exited with an error.${RESET}"
        echo -e "${YELLOW}Restoring backup...${RESET}"
        mv "$backup_path" "$module_path"
        return 1
    fi
    
    # Verify module health after editing
    echo -e "${YELLOW}Verifying module health...${RESET}"
    if ! check_module_health "$module"; then
        echo -e "${RED}Module has syntax errors after editing.${RESET}"
        echo -e "${YELLOW}Would you like to:${RESET}"
        echo "1. Fix it now (reopen editor)"
        echo "2. Restore the backup"
        echo "3. Keep it anyway"
        read -r fix_choice
        
        case "$fix_choice" in
            1)
                echo -e "${YELLOW}Reopening editor...${RESET}"
                $EDITOR "$module_path" || nano "$module_path" || vim "$module_path"
                ;;
            2)
                echo -e "${YELLOW}Restoring backup...${RESET}"
                mv "$backup_path" "$module_path"
                return 1
                ;;
            *)
                echo -e "${YELLOW}Keeping modified module despite errors.${RESET}"
                ;;
        esac
    else
        # Remove backup if everything is fine
        rm -f "$backup_path"
    fi
    
    # Reload the module after editing
    echo -e "${YELLOW}Reloading module: ${BOLD}${module}${RESET}"
    source "$module_path"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Module edited and reloaded: ${BOLD}${module}${RESET}"
    else
        echo -e "${RED}Failed to reload module after editing.${RESET}"
        echo -e "${YELLOW}Changes are saved but not active. Run 'reload' to attempt reload.${RESET}"
        return 1
    fi
}

# Function to run health check on all modules with detailed reporting
function health_check() {
    echo -e "${CYAN}Running health check on all modules...${RESET}"
    
    local all_passed=1
    local checked=0
    local passed=0
    local failed=0
    
    # Show a header
    printf "%-40s %-20s %-40s\n" "MODULE" "STATUS" "ISSUES"
    printf "%-40s %-20s %-40s\n" "$(printf '%0.s-' {1..40})" "$(printf '%0.s-' {1..20})" "$(printf '%0.s-' {1..40})"
    
    for module in "${BASHRC_MODULES_PATH}"/*.sh; do
        if [ -f "$module" ]; then
            local module_name=$(basename "$module")
            checked=$((checked + 1))
            
            # Capture output to variable for analysis
            local check_output=$(check_module_health "$module_name" 2>&1)
            local check_status=$?
            
            if [ $check_status -eq 0 ]; then
                printf "%-40s ${GREEN}%-20s${RESET} %-40s\n" "$module_name" "PASSED" ""
                passed=$((passed + 1))
            else
                # Extract issue from output
                local issue=$(echo "$check_output" | grep -E "Error|Warning" | head -1 | sed 's/.*Error: //' | sed 's/.*Warning: //')
                
                # Truncate issue if too long
                if [ ${#issue} -gt 40 ]; then
                    issue="${issue:0:37}..."
                fi
                
                printf "%-40s ${RED}%-20s${RESET} %-40s\n" "$module_name" "FAILED" "$issue"
                all_passed=0
                failed=$((failed + 1))
            fi
        fi
    done
    
    echo
    if [ $all_passed -eq 1 ]; then
        echo -e "${GREEN}All modules passed health check!${RESET}"
    else
        echo -e "${YELLOW}Health check complete: ${GREEN}$passed passed${RESET}, ${RED}$failed failed${RESET} of $checked modules.${RESET}"
        echo -e "${YELLOW}Fix issues with 'edit_module <module_name>' or use 'togglemod' to disable problematic modules.${RESET}"
    fi
}

# Aliases for module management
alias lsmod="list_modules"
alias reload="reload_modules"
alias bashrc="edit_module"
alias health="health_check"
alias togglemod="toggle_module"
