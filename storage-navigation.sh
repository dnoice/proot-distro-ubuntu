#!/bin/bash
# ===========================================
# Storage Navigation
# ===========================================
# Specialized functions for navigating between Ubuntu root and Android shared storage
# Author: Claude & You
# Version: 1.0
# Last Updated: 2025-05-14

# ===========================================
# Shared Storage Detection & Path Management
# ===========================================

# Function to detect available shared storage paths
function detect_shared_storage() {
    # List of potential shared storage locations in order of preference
    local potential_paths=(
        "/sdcard"
        "../sdcard"
        "/storage/emulated/0"
        "../storage/emulated/0"
        "/storage/self/primary"
        "../storage/self/primary"
        "/mnt/sdcard"
        "../mnt/sdcard"
    )
    
    # Check each potential path
    for path in "${potential_paths[@]}"; do
        if [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    # No valid path found
    echo ""
    return 1
}

# Detect and store the shared storage path
SHARED_STORAGE_PATH=$(detect_shared_storage)

# Function to convert path to display format (prettier output)
function format_storage_path() {
    local path="$1"
    local formatted_path
    
    # Convert full path to more readable format if inside shared storage
    if [[ "$path" == *"sdcard"* || "$path" == *"storage/emulated"* || "$path" == *"storage/self"* ]]; then
        # Extract the portion after sdcard/ or emulated/0/ etc.
        if [[ "$path" == *"sdcard/"* ]]; then
            formatted_path="📱 sdcard/$(echo "$path" | sed 's|.*/sdcard/||')"
        elif [[ "$path" == *"storage/emulated/0/"* ]]; then
            formatted_path="📱 sdcard/$(echo "$path" | sed 's|.*/storage/emulated/0/||')"
        elif [[ "$path" == *"storage/self/primary/"* ]]; then
            formatted_path="📱 sdcard/$(echo "$path" | sed 's|.*/storage/self/primary/||')"
        else
            formatted_path="📱 sdcard"
        fi
    else
        formatted_path="$path"
    fi
    
    echo "$formatted_path"
}

# ===========================================
# Storage Navigation Functions
# ===========================================

# Function to access shared storage from anywhere
function sdcard() {
    if [ -z "$SHARED_STORAGE_PATH" ]; then
        echo -e "${RED}Error: Shared storage not found${RESET}"
        return 1
    fi
    
    local target="$SHARED_STORAGE_PATH"
    
    # Navigate to a subdirectory if specified
    if [ ! -z "$1" ]; then
        target="$target/$1"
        if [ ! -d "$target" ]; then
            echo -e "${RED}Error: Directory '$1' not found in shared storage${RESET}"
            echo -e "${YELLOW}Available directories in shared storage:${RESET}"
            ls -la "$SHARED_STORAGE_PATH" | grep "^d" | awk '{print $9}'
            return 1
        fi
    fi
    
    cd "$target" || return 1
    local formatted_path=$(format_storage_path "$PWD")
    echo -e "${GREEN}Changed to ${BOLD}$formatted_path${RESET}"
}

# Function to return to root home directory
function home() {
    cd /root || return 1
    echo -e "${GREEN}Changed to root home directory${RESET}"
}

# Function to navigate to a specific directory in sdcard
function scd() {
    if [ -z "$SHARED_STORAGE_PATH" ]; then
        echo -e "${RED}Error: Shared storage not found${RESET}"
        return 1
    fi
    
    if [ -z "$1" ]; then
        sdcard
        return $?
    fi
    
    local target="$SHARED_STORAGE_PATH/$1"
    
    if [ ! -d "$target" ]; then
        echo -e "${RED}Directory not found in shared storage: $1${RESET}"
        echo -e "${YELLOW}Available directories in shared storage:${RESET}"
        ls -la "$SHARED_STORAGE_PATH" | grep "^d" | awk '{print $9}'
        return 1
    fi
    
    cd "$target" || return 1
    local formatted_path=$(format_storage_path "$PWD")
    echo -e "${GREEN}Changed to ${BOLD}$formatted_path${RESET}"
}

# Function to easily list sdcard contents
function sls() {
    if [ -z "$SHARED_STORAGE_PATH" ]; then
        echo -e "${RED}Error: Shared storage not found${RESET}"
        return 1
    fi
    
    local target="$SHARED_STORAGE_PATH"
    
    if [ ! -z "$1" ]; then
        target="$target/$1"
        if [ ! -d "$target" ]; then
            echo -e "${RED}Error: Directory '$1' not found in shared storage${RESET}"
            return 1
        fi
    fi
    
    local formatted_path=$(format_storage_path "$target")
    echo -e "${CYAN}Contents of ${BOLD}$formatted_path${RESET}:"
    
    if command -v exa &> /dev/null; then
        # Use exa for better output if available
        exa -la "$target"
    else
        # Fall back to standard ls
        ls -la "$target"
    fi
}

# Function to show file path with relation to sdcard if applicable
function where() {
    local formatted_path=""
    
    if [[ "$PWD" == *"sdcard"* || "$PWD" == *"storage/emulated"* || "$PWD" == *"storage/self"* ]]; then
        formatted_path=$(format_storage_path "$PWD")
        echo -e "${GREEN}Current path: ${BOLD_GREEN}$formatted_path${RESET}"
        
        # Show absolute path as well
        echo -e "${YELLOW}Absolute path: ${RESET}$PWD"
        
        # Provide a useful copy command to access this path later
        if [[ "$PWD" == *"sdcard/"* ]]; then
            local relative_path=$(echo "$PWD" | sed 's|.*/sdcard/||')
            echo -e "${CYAN}Access this path again with: ${RESET}${BOLD}sdcard $relative_path${RESET}"
        elif [[ "$PWD" == *"storage/emulated/0/"* ]]; then
            local relative_path=$(echo "$PWD" | sed 's|.*/storage/emulated/0/||')
            echo -e "${CYAN}Access this path again with: ${RESET}${BOLD}sdcard $relative_path${RESET}"
        elif [[ "$PWD" == *"storage/self/primary/"* ]]; then
            local relative_path=$(echo "$PWD" | sed 's|.*/storage/self/primary/||')
            echo -e "${CYAN}Access this path again with: ${RESET}${BOLD}sdcard $relative_path${RESET}"
        fi
    else
        echo -e "${GREEN}Current path: ${BOLD_GREEN}$PWD${RESET}"
    fi
}

# Function to find files in shared storage
function sfind() {
    if [ -z "$SHARED_STORAGE_PATH" ]; then
        echo -e "${RED}Error: Shared storage not found${RESET}"
        return 1
    fi
    
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: sfind <pattern> [max_depth]${RESET}"
        echo "Example: sfind '*.pdf' 3"
        return 1
    fi
    
    local pattern="$1"
    local max_depth=${2:-3}  # Default to depth of 3
    
    echo -e "${CYAN}Searching for ${BOLD}$pattern${RESET} in shared storage (max depth: $max_depth)...${RESET}"
    
    find "$SHARED_STORAGE_PATH" -maxdepth "$max_depth" -name "$pattern" 2>/dev/null | while read -r file; do
        # Format the path for display
        local relative_path=$(echo "$file" | sed "s|$SHARED_STORAGE_PATH/||")
        echo "📄 $relative_path"
    done
}

# Function to sync files between root and shared storage
function ssync() {
    if [ -z "$SHARED_STORAGE_PATH" ]; then
        echo -e "${RED}Error: Shared storage not found${RESET}"
        return 1
    fi
    
    if [ "$#" -lt 2 ]; then
        echo -e "${YELLOW}Usage: ssync <source> <destination> [options]${RESET}"
        echo "Examples:"
        echo "  ssync myfile.txt sdcard/backup/"
        echo "  ssync /root/projects sdcard/projects/ -av"
        echo "  ssync sdcard/downloads/ /root/downloads/"
        return 1
    fi
    
    local source="$1"
    local dest="$2"
    shift 2  # Remove first two arguments
    local options="$@"  # Remaining arguments as rsync options
    
    # Process source path
    if [[ "$source" == "sdcard/"* ]]; then
        source="$SHARED_STORAGE_PATH/${source#sdcard/}"
    fi
    
    # Process destination path
    if [[ "$dest" == "sdcard/"* ]]; then
        dest="$SHARED_STORAGE_PATH/${dest#sdcard/}"
    fi
    
    # Ensure destination directory exists
    local dest_dir=$(dirname "$dest")
    mkdir -p "$dest_dir"
    
    # Default options if none provided
    if [ -z "$options" ]; then
        options="-av"
    fi
    
    echo -e "${CYAN}Syncing ${BOLD}$source${RESET} to ${BOLD}$dest${RESET}...${RESET}"
    
    # Use rsync if available, otherwise fall back to cp
    if command -v rsync &> /dev/null; then
        rsync $options "$source" "$dest"
    else
        cp -r "$source" "$dest"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Sync completed successfully!${RESET}"
    else
        echo -e "${RED}Sync failed!${RESET}"
        return 1
    fi
}

# Function to create a directory in shared storage and navigate to it
function smkdir() {
    if [ -z "$SHARED_STORAGE_PATH" ]; then
        echo -e "${RED}Error: Shared storage not found${RESET}"
        return 1
    fi
    
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: smkdir <directory_name>${RESET}"
        return 1
    fi
    
    local new_dir="$SHARED_STORAGE_PATH/$1"
    
    echo -e "${CYAN}Creating directory ${BOLD}$1${RESET} in shared storage...${RESET}"
    mkdir -p "$new_dir"
    
    if [ $? -eq 0 ]; then
        cd "$new_dir" || return 1
        echo -e "${GREEN}Created and moved to new directory${RESET}"
        # Format the path for display
        local formatted_path=$(format_storage_path "$PWD")
        echo -e "${GREEN}Current path: ${BOLD}$formatted_path${RESET}"
    else
        echo -e "${RED}Failed to create directory${RESET}"
        return 1
    fi
}

# ===========================================
# File Operations on Shared Storage
# ===========================================

# Function to copy files to shared storage with progress
function scopy() {
    if [ -z "$SHARED_STORAGE_PATH" ]; then
        echo -e "${RED}Error: Shared storage not found${RESET}"
        return 1
    fi
    
    if [ "$#" -lt 2 ]; then
        echo -e "${YELLOW}Usage: scopy <source_file_or_dir> <destination_in_sdcard>${RESET}"
        echo "Example: scopy myfile.txt Documents/"
        return 1
    fi
    
    local source="$1"
    local dest="$SHARED_STORAGE_PATH/$2"
    
    # Create destination directory if it doesn't exist
    local dest_dir=$(dirname "$dest")
    if [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir"
    fi
    
    echo -e "${CYAN}Copying ${BOLD}$source${RESET} to ${BOLD}$(format_storage_path "$dest")${RESET}...${RESET}"
    
    # Choose the best copy method available
    if command -v rsync &> /dev/null; then
        rsync -av --progress "$source" "$dest"
    else
        cp -v "$source" "$dest"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Copy completed successfully!${RESET}"
    else
        echo -e "${RED}Copy failed!${RESET}"
        return 1
    fi
}

# Function to move files to shared storage
function smove() {
    if [ -z "$SHARED_STORAGE_PATH" ]; then
        echo -e "${RED}Error: Shared storage not found${RESET}"
        return 1
    fi
    
    if [ "$#" -lt 2 ]; then
        echo -e "${YELLOW}Usage: smove <source_file_or_dir> <destination_in_sdcard>${RESET}"
        echo "Example: smove myfile.txt Downloads/"
        return 1
    fi
    
    local source="$1"
    local dest="$SHARED_STORAGE_PATH/$2"
    
    # Create destination directory if it doesn't exist
    local dest_dir=$(dirname "$dest")
    if [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir"
    fi
    
    echo -e "${CYAN}Moving ${BOLD}$source${RESET} to ${BOLD}$(format_storage_path "$dest")${RESET}...${RESET}"
    
    # Move the file
    mv -v "$source" "$dest"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Move completed successfully!${RESET}"
    else
        echo -e "${RED}Move failed!${RESET}"
        return 1
    fi
}

# Output module load message if verbose
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}Loaded: ${BOLD}Storage Navigation Module${RESET}"
    if [ -n "$SHARED_STORAGE_PATH" ]; then
        echo -e "${CYAN}Shared storage detected at: ${BOLD}$SHARED_STORAGE_PATH${RESET}"
    else
        echo -e "${YELLOW}Warning: No shared storage path detected${RESET}"
    fi
fi
