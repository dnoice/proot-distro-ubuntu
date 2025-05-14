#!/bin/bash
# ===========================================
# Productivity Tools & Task Management
# ===========================================
# Task timer, project management, and productivity utilities
# Version: 1.2
# Last Updated: 2025-05-14

# ===========================================
# Configuration Options
# ===========================================

# User-configurable options (can be overridden in .bashrc.custom)
TIMER_FILE="${TIMER_FILE:-${HOME}/.timer}"
TIMER_HISTORY="${TIMER_HISTORY:-${HOME}/.timer_history}"
PROJECT_DIR="${PROJECT_DIR:-${HOME}/.projects}"
NOTES_DIR="${NOTES_DIR:-${HOME}/.notes}"
PRODUCTIVITY_BACKUP_DIR="${PRODUCTIVITY_BACKUP_DIR:-${HOME}/.backups/productivity}"
PRODUCTIVITY_AUTO_BACKUP=${PRODUCTIVITY_AUTO_BACKUP:-1}  # Auto-backup on exit (0=off, 1=on)
PRODUCTIVITY_BACKUP_INTERVAL=${PRODUCTIVITY_BACKUP_INTERVAL:-7}  # Days between auto-backups

# ===========================================
# Initialization Functions
# ===========================================

# Initialize required directories
function _init_productivity_dirs() {
    # Create directories if they don't exist
    for dir in "$PROJECT_DIR" "$NOTES_DIR" "$PRODUCTIVITY_BACKUP_DIR"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            if [ $? -ne 0 ]; then
                echo -e "${RED}Error: Failed to create directory: $dir${RESET}"
                return 1
            fi
        fi
    done
    
    # Ensure timer history file exists
    if [ ! -f "$TIMER_HISTORY" ]; then
        touch "$TIMER_HISTORY"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Failed to create timer history file: $TIMER_HISTORY${RESET}"
            return 1
        fi
        # Add header to timer history
        echo "start_time|end_time|category|task|duration|seconds" > "$TIMER_HISTORY"
    fi
    
    return 0
}

# Create an automatic backup of productivity data
function _backup_productivity_data() {
    # Skip if auto-backup is disabled
    if [ "$PRODUCTIVITY_AUTO_BACKUP" -ne 1 ]; then
        return 0
    fi
    
    # Check if we need to make a backup based on interval
    local last_backup_file="${PRODUCTIVITY_BACKUP_DIR}/.last_backup"
    
    if [ -f "$last_backup_file" ]; then
        local last_backup=$(cat "$last_backup_file")
        local current_time=$(date +%s)
        local time_diff=$((current_time - last_backup))
        local day_diff=$((time_diff / 86400))
        
        if [ "$day_diff" -lt "$PRODUCTIVITY_BACKUP_INTERVAL" ]; then
            # Skip backup if within interval
            return 0
        fi
    fi
    
    # Create backup directory if it doesn't exist
    if [ ! -d "$PRODUCTIVITY_BACKUP_DIR" ]; then
        mkdir -p "$PRODUCTIVITY_BACKUP_DIR"
    fi
    
    # Create timestamp for backup
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${PRODUCTIVITY_BACKUP_DIR}/productivity_backup_${timestamp}.tar.gz"
    
    # Create temporary directory for files to backup
    local temp_dir=$(mktemp -d)
    
    # Copy files to temporary directory
    if [ -f "$TIMER_HISTORY" ]; then
        cp "$TIMER_HISTORY" "$temp_dir/"
    fi
    
    if [ -d "$PROJECT_DIR" ]; then
        mkdir -p "$temp_dir/projects"
        cp -r "$PROJECT_DIR"/* "$temp_dir/projects/" 2>/dev/null
    fi
    
    if [ -d "$NOTES_DIR" ]; then
        mkdir -p "$temp_dir/notes"
        cp -r "$NOTES_DIR"/* "$temp_dir/notes/" 2>/dev/null
    fi
    
    # Create tar archive
    tar -czf "$backup_file" -C "$temp_dir" .
    
    # Check if backup was successful
    if [ $? -eq 0 ]; then
        # Update last backup timestamp
        echo "$current_time" > "$last_backup_file"
        
        if [ "$VERBOSE_MODULE_LOAD" == "1" ]; then
            echo -e "${GREEN}Productivity data backed up to: $backup_file${RESET}"
        fi
        
        # Clean up old backups (keep only last 5)
        local old_backups=$(ls -t "${PRODUCTIVITY_BACKUP_DIR}"/productivity_backup_*.tar.gz 2>/dev/null | tail -n +6)
        if [ -n "$old_backups" ]; then
            rm -f $old_backups
        fi
    else
        if [ "$VERBOSE_MODULE_LOAD" == "1" ]; then
            echo -e "${YELLOW}Warning: Failed to back up productivity data${RESET}"
        fi
    fi
    
    # Clean up temporary directory
    rm -rf "$temp_dir"
}

# Restore productivity data from backup
function productivity_restore() {
    # List available backups
    if [ $# -eq 0 ]; then
        echo -e "${YELLOW}Available productivity backups:${RESET}"
        if [ ! -d "$PRODUCTIVITY_BACKUP_DIR" ] || [ -z "$(ls -A "$PRODUCTIVITY_BACKUP_DIR" 2>/dev/null)" ]; then
            echo -e "${CYAN}No backups found.${RESET}"
            return 1
        fi
        
        ls -lt "${PRODUCTIVITY_BACKUP_DIR}"/productivity_backup_*.tar.gz 2>/dev/null | 
            awk '{print $6, $7, $8, $9}' | 
            nl -w2 -s') '
        
        echo -e "${YELLOW}Usage: productivity_restore <number> [--force]${RESET}"
        return 0
    fi
    
    # Check if argument is a number
    local backup_num="$1"
    local force_restore=0
    
    if [[ "$2" == "--force" ]]; then
        force_restore=1
    fi
    
    if ! [[ "$backup_num" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Please provide a valid backup number${RESET}"
        productivity_restore
        return 1
    fi
    
    # Get backup file
    local backup_file=$(ls -t "${PRODUCTIVITY_BACKUP_DIR}"/productivity_backup_*.tar.gz 2>/dev/null | sed -n "${backup_num}p")
    
    if [ -z "$backup_file" ]; then
        echo -e "${RED}Error: Backup #$backup_num not found${RESET}"
        productivity_restore
        return 1
    fi
    
    echo -e "${YELLOW}Preparing to restore from: ${CYAN}$backup_file${RESET}"
    
    # Ask for confirmation unless --force is provided
    if [ "$force_restore" -ne 1 ]; then
        echo -e "${RED}Warning: This will overwrite your current productivity data!${RESET}"
        echo -e "${YELLOW}Continue? [y/N]${RESET}"
        read -r confirm
        
        if [[ ! "$confirm" =~ ^[yY]$ ]]; then
            echo -e "${YELLOW}Restore cancelled.${RESET}"
            return 1
        fi
    fi
    
    # Create temporary directory for extraction
    local temp_dir=$(mktemp -d)
    
    # Extract backup
    tar -xzf "$backup_file" -C "$temp_dir"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to extract backup${RESET}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Restore timer history
    if [ -f "$temp_dir/timer_history" ]; then
        cp "$temp_dir/timer_history" "$TIMER_HISTORY"
    fi
    
    # Restore projects
    if [ -d "$temp_dir/projects" ]; then
        # Create backup of current projects
        if [ -d "$PROJECT_DIR" ]; then
            local timestamp=$(date +"%Y%m%d_%H%M%S")
            mkdir -p "${HOME}/.backups"
            mv "$PROJECT_DIR" "${HOME}/.backups/projects_backup_${timestamp}"
        fi
        
        # Restore from backup
        mkdir -p "$PROJECT_DIR"
        cp -r "$temp_dir/projects/"* "$PROJECT_DIR/" 2>/dev/null
    fi
    
    # Restore notes
    if [ -d "$temp_dir/notes" ]; then
        # Create backup of current notes
        if [ -d "$NOTES_DIR" ]; then
            local timestamp=$(date +"%Y%m%d_%H%M%S")
            mkdir -p "${HOME}/.backups"
            mv "$NOTES_DIR" "${HOME}/.backups/notes_backup_${timestamp}"
        fi
        
        # Restore from backup
        mkdir -p "$NOTES_DIR"
        cp -r "$temp_dir/notes/"* "$NOTES_DIR/" 2>/dev/null
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}Productivity data restored successfully!${RESET}"
    
    # Show data summary
    echo -e "${CYAN}Restored data summary:${RESET}"
    echo -e "Timer history: $(grep -c "" "$TIMER_HISTORY") entries"
    echo -e "Projects: $(find "$PROJECT_DIR" -maxdepth 1 -type f | wc -l) projects"
    echo -e "Notes: $(find "$NOTES_DIR" -maxdepth 1 -type f | wc -l) notes"
}

# Register backup function to run on shell exit
trap _backup_productivity_data EXIT

# ===========================================
# Task Timer Implementation
# ===========================================

# Function to manage task timing
function timer() {
    local cmd="$1"
    local args="${@:2}"
    
    # Initialize directories
    _init_productivity_dirs

    if [ -z "$cmd" ]; then
        echo -e "${GREEN}Task Timer${RESET}"
        echo -e "${YELLOW}Usage:${RESET} timer [start|stop|status|history|report] [task-name]"
        echo
        echo -e "${CYAN}Commands:${RESET}"
        echo "  start <task-name>  : Start timing a task (use 'category: task name' format for categorization)"
        echo "  stop               : Stop current timer"
        echo "  status             : Show current timer status"
        echo "  history [n]        : Show last n tasks (default: 10)"
        echo "  report [days]      : Show summary report for last n days (default: 7)"
        echo "  list [category]    : List tasks by category (if specified)"
        echo "  categories         : Show all used categories"
        echo "  clean              : Clean up old timer history (keeps last 30 days)"
        echo
        echo -e "${CYAN}Aliases:${RESET}"
        echo "  ts <task-name>     : timer start"
        echo "  te                 : timer stop"
        echo "  tt                 : timer status"
        echo "  th [n]             : timer history"
        echo "  tr [days]          : timer report"
        return 0
    fi
    
    # Create history file if it doesn't exist
    if [ ! -f "$TIMER_HISTORY" ] && [[ "$cmd" != "help" ]]; then
        touch "$TIMER_HISTORY"
        echo "start_time|end_time|category|task|duration|seconds" > "$TIMER_HISTORY"
    fi
    
    case "$cmd" in
        start)
            if [ -z "$args" ]; then
                echo -e "${RED}Error: Please specify a task name${RESET}"
                return 1
            fi
            
            # Check if timer is already running
            if [ -f "$TIMER_FILE" ]; then
                local start_data=$(cat "$TIMER_FILE")
                local task_name=$(echo "$start_data" | cut -d' ' -f2-)
                echo -e "${YELLOW}Timer already running for task: $task_name${RESET}"
                echo -e "${YELLOW}Do you want to stop it and start a new timer? [y/N]${RESET}"
                read -r confirm
                if [[ "$confirm" =~ ^[yY]$ ]]; then
                    timer stop
                else
                    return 1
                fi
            fi
            
            # Extract category if present (format: category:task)
            local task_name="$args"
            local category=""
            
            if [[ "$args" == *":"* ]]; then
                category=$(echo "$args" | cut -d':' -f1)
                task_name=$(echo "$args" | cut -d':' -f2-)
                # Remove leading space if any
                task_name="${task_name# }"
            fi
            
            # Save start time, category, and task name
            echo "$(date +%s) $category $task_name" > "$TIMER_FILE"
            
            if [ -n "$category" ]; then
                echo -e "${GREEN}Timer started for task: ${RESET}${CYAN}$category${RESET}:${YELLOW}$task_name${RESET}"
            else
                echo -e "${GREEN}Timer started for task: ${RESET}${YELLOW}$task_name${RESET}"
            fi
            ;;
            
        stop)
            if [ ! -f "$TIMER_FILE" ]; then
                echo -e "${RED}No timer is running${RESET}"
                return 1
            fi
            
            local start_data=$(cat "$TIMER_FILE")
            local start_time=$(echo "$start_data" | cut -d' ' -f1)
            local category=$(echo "$start_data" | cut -d' ' -f2)
            local task_name=$(echo "$start_data" | cut -d' ' -f3-)
            
            # If no category was specified (indicated by no ":" in task_name)
            if [[ "$category" != *":"* ]] && [[ "$task_name" == "" ]]; then
                task_name="$category"
                category=""
            fi
            
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            # Format duration nicely
            local hours=$((duration / 3600))
            local minutes=$(((duration % 3600) / 60))
            local seconds=$((duration % 60))
            
            if [ -n "$category" ]; then
                echo -e "${GREEN}Task completed: ${RESET}${CYAN}$category${RESET}:${YELLOW}$task_name${RESET}"
            else
                echo -e "${GREEN}Task completed: ${RESET}${YELLOW}$task_name${RESET}"
            fi
            
            printf "Time spent: %02d:%02d:%02d\n" $hours $minutes $seconds
            
            # Log to history file with category field
            echo "$(date -d @$start_time "+%Y-%m-%d %H:%M:%S")|$(date -d @$end_time "+%Y-%m-%d %H:%M:%S")|$category|$task_name|$hours:$minutes:$seconds|$duration" >> "$TIMER_HISTORY"
            
            # Remove timer file
            rm "$TIMER_FILE"
            ;;
            
        status)
            if [ ! -f "$TIMER_FILE" ]; then
                echo -e "${RED}No timer is running${RESET}"
                return 1
            fi
            
            local start_data=$(cat "$TIMER_FILE")
            local start_time=$(echo "$start_data" | cut -d' ' -f1)
            local category=$(echo "$start_data" | cut -d' ' -f2)
            local task_name=$(echo "$start_data" | cut -d' ' -f3-)
            
            # If no category was specified
            if [[ "$category" != *":"* ]] && [[ "$task_name" == "" ]]; then
                task_name="$category"
                category=""
            fi
            
            local current_time=$(date +%s)
            local duration=$((current_time - start_time))
            
            # Format duration nicely
            local hours=$((duration / 3600))
            local minutes=$(((duration % 3600) / 60))
            local seconds=$((duration % 60))
            
            # Format start time
            local start_time_formatted=$(date -d @$start_time "+%Y-%m-%d %H:%M:%S")
            
            if [ -n "$category" ]; then
                echo -e "${GREEN}Current task: ${RESET}${CYAN}$category${RESET}:${YELLOW}$task_name${RESET}"
            else
                echo -e "${GREEN}Current task: ${RESET}${YELLOW}$task_name${RESET}"
            fi
            
            echo -e "Started at: $start_time_formatted"
            printf "Time spent so far: %02d:%02d:%02d\n" $hours $minutes $seconds
            ;;
            
        history)
            if [ ! -f "$TIMER_HISTORY" ]; then
                echo -e "${RED}No timer history found${RESET}"
                return 1
            fi
            
            local count=${args:-10}
            
            echo -e "${GREEN}Recent tasks:${RESET}"
            echo -e "${CYAN}START TIME          | END TIME            | CATEGORY    | TASK                 | DURATION${RESET}"
            tail -n "+2" "$TIMER_HISTORY" | tail -n "$count" | while IFS='|' read -r start_time end_time category task duration _; do
                # Format category with color if present
                local category_display=""
                if [ -n "$category" ]; then
                    category_display="${CYAN}$category${RESET}"
                fi
                
                printf "%-19s | %-19s | %-11s | %-20s | %s\n" "$start_time" "$end_time" "$category_display" "$task" "$duration"
            done
            ;;
            
        report)
            if [ ! -f "$TIMER_HISTORY" ]; then
                echo -e "${RED}No timer history found${RESET}"
                return 1
            fi
            
            local days=${args:-7}
            local today=$(date +%s)
            local since=$((today - days * 86400))
            local since_date=$(date -d @$since "+%Y-%m-%d")
            
            echo -e "${GREEN}Timer report for the last $days days (since $since_date):${RESET}"
            
            # Calculate total time by task
            echo -e "${CYAN}Time spent by task:${RESET}"
            local total_seconds=0
            local task_times=()
            local task_seconds=()
            local task_categories=()
            
            # Skip header line
            tail -n "+2" "$TIMER_HISTORY" | while IFS='|' read -r start_time end_time category task duration seconds; do
                # Skip header or invalid lines
                if [[ ! "$start_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
                    continue
                fi
                
                # Convert start_time to seconds since epoch
                local start_seconds=$(date -d "$start_time" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$start_time" +%s 2>/dev/null)
                
                # Skip if before our time range
                if [ "$start_seconds" -lt "$since" ]; then
                    continue
                fi
                
                # Create combined key for category and task
                local task_key
                if [ -n "$category" ]; then
                    task_key="$category:$task"
                else
                    task_key="$task"
                fi
                
                # Accumulate time for this task
                local found=0
                for i in "${!task_times[@]}"; do
                    if [ "${task_times[$i]}" = "$task_key" ]; then
                        task_seconds[$i]=$((task_seconds[$i] + seconds))
                        found=1
                        break
                    fi
                done
                
                if [ "$found" -eq 0 ]; then
                    task_times+=("$task_key")
                    task_seconds+=("$seconds")
                    task_categories+=("$category")
                fi
                
                total_seconds=$((total_seconds + seconds))
            done
            
            # Sort tasks by time spent (most to least)
            for ((i=0; i<${#task_times[@]}; i++)); do
                for ((j=i+1; j<${#task_times[@]}; j++)); do
                    if [ "${task_seconds[$i]}" -lt "${task_seconds[$j]}" ]; then
                        # Swap tasks
                        local temp_task="${task_times[$i]}"
                        local temp_seconds="${task_seconds[$i]}"
                        local temp_category="${task_categories[$i]}"
                        
                        task_times[$i]="${task_times[$j]}"
                        task_seconds[$i]="${task_seconds[$j]}"
                        task_categories[$i]="${task_categories[$j]}"
                        
                        task_times[$j]="$temp_task"
                        task_seconds[$j]="$temp_seconds"
                        task_categories[$j]="$temp_category"
                    fi
                done
            done
            
            # Display report
            local total_hours=$((total_seconds / 3600))
            local total_minutes=$(((total_seconds % 3600) / 60))
            
            echo -e "${YELLOW}Total time tracked: ${total_hours}h ${total_minutes}m${RESET}"
            echo
            
            for i in "${!task_times[@]}"; do
                local hours=$((task_seconds[$i] / 3600))
                local minutes=$(((task_seconds[$i] % 3600) / 60))
                local percentage=0
                if [ "$total_seconds" -gt 0 ]; then
                    percentage=$(( (task_seconds[$i] * 100) / total_seconds ))
                fi
                
                # Get task and category for display
                local display_task="${task_times[$i]}"
                local category="${task_categories[$i]}"
                
                # If category exists, format with color
                if [ -n "$category" ]; then
                    printf "${CYAN}%-10s${RESET} | %-20s %2dh %2dm (%3d%%)\n" "$category" "${display_task#*:}" $hours $minutes $percentage
                else
                    printf "%-33s %2dh %2dm (%3d%%)\n" "$display_task" $hours $minutes $percentage
                fi
            done
            
            # Calculate time by category
            if grep -q "|[^|]*|" "$TIMER_HISTORY"; then
                echo
                echo -e "${CYAN}Time spent by category:${RESET}"
                
                local category_times=()
                local category_seconds=()
                
                for i in "${!task_categories[@]}"; do
                    local category="${task_categories[$i]}"
                    if [ -z "$category" ]; then
                        category="(uncategorized)"
                    fi
                    
                    # Accumulate time for this category
                    local found=0
                    for j in "${!category_times[@]}"; do
                        if [ "${category_times[$j]}" = "$category" ]; then
                            category_seconds[$j]=$((category_seconds[$j] + task_seconds[$i]))
                            found=1
                            break
                        fi
                    done
                    
                    if [ "$found" -eq 0 ]; then
                        category_times+=("$category")
                        category_seconds+=("${task_seconds[$i]}")
                    fi
                done
                
                # Sort categories by time spent
                for ((i=0; i<${#category_times[@]}; i++)); do
                    for ((j=i+1; j<${#category_times[@]}; j++)); do
                        if [ "${category_seconds[$i]}" -lt "${category_seconds[$j]}" ]; then
                            # Swap categories
                            local temp_category="${category_times[$i]}"
                            local temp_seconds="${category_seconds[$i]}"
                            
                            category_times[$i]="${category_times[$j]}"
                            category_seconds[$i]="${category_seconds[$j]}"
                            
                            category_times[$j]="$temp_category"
                            category_seconds[$j]="$temp_seconds"
                        fi
                    done
                done
                
                # Display category report
                for i in "${!category_times[@]}"; do
                    local hours=$((category_seconds[$i] / 3600))
                    local minutes=$(((category_seconds[$i] % 3600) / 60))
                    local percentage=0
                    if [ "$total_seconds" -gt 0 ]; then
                        percentage=$(( (category_seconds[$i] * 100) / total_seconds ))
                    fi
                    
                    if [ "${category_times[$i]}" = "(uncategorized)" ]; then
                        printf "%-20s %2dh %2dm (%3d%%)\n" "${category_times[$i]}" $hours $minutes $percentage
                    else
                        printf "${CYAN}%-20s${RESET} %2dh %2dm (%3d%%)\n" "${category_times[$i]}" $hours $minutes $percentage
                    fi
                done
            fi
            
            # Daily breakdown
            echo
            echo -e "${CYAN}Daily breakdown:${RESET}"
            
            # Get all unique dates
            local dates=()
            local date_seconds=()
            
            tail -n "+2" "$TIMER_HISTORY" | while IFS='|' read -r start_time _ _ _ _ seconds; do
                # Skip header or invalid lines
                if [[ ! "$start_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
                    continue
                fi
                
                # Extract date part
                local date_part=$(echo "$start_time" | cut -d' ' -f1)
                
                # Convert to seconds since epoch for comparison
                local date_epoch=$(date -d "$date_part" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$date_part" +%s 2>/dev/null)
                
                # Skip if before our time range
                if [ "$date_epoch" -lt "$since" ]; then
                    continue
                fi
                
                # Accumulate time for this date
                local found=0
                for i in "${!dates[@]}"; do
                    if [ "${dates[$i]}" = "$date_part" ]; then
                        date_seconds[$i]=$((date_seconds[$i] + seconds))
                        found=1
                        break
                    fi
                done
                
                if [ "$found" -eq 0 ]; then
                    dates+=("$date_part")
                    date_seconds+=("$seconds")
                fi
            done
            
            # Sort dates (newest first)
            for ((i=0; i<${#dates[@]}; i++)); do
                for ((j=i+1; j<${#dates[@]}; j++)); do
                    if [[ "${dates[$i]}" < "${dates[$j]}" ]]; then
                        # Swap dates
                        local temp_date="${dates[$i]}"
                        local temp_seconds="${date_seconds[$i]}"
                        dates[$i]="${dates[$j]}"
                        date_seconds[$i]="${date_seconds[$j]}"
                        dates[$j]="$temp_date"
                        date_seconds[$j]="$temp_seconds"
                    fi
                done
            done
            
            # Display daily breakdown
            for i in "${!dates[@]}"; do
                local hours=$((date_seconds[$i] / 3600))
                local minutes=$(((date_seconds[$i] % 3600) / 60))
                local dayname=$(date -d "${dates[$i]}" +"%a" 2>/dev/null || date -j -f "%Y-%m-%d" "${dates[$i]}" +"%a" 2>/dev/null)
                printf "%s (%s): %2dh %2dm\n" "${dates[$i]}" "$dayname" $hours $minutes
            done
            ;;
            
        list)
            if [ ! -f "$TIMER_HISTORY" ]; then
                echo -e "${RED}No timer history found${RESET}"
                return 1
            fi
            
            local filter_category="$args"
            
            echo -e "${GREEN}Task list:${RESET}"
            
            # Collect unique tasks with their categories
            local tasks=()
            local categories=()
            
            tail -n "+2" "$TIMER_HISTORY" | while IFS='|' read -r _ _ category task _ _; do
                # Skip header or invalid lines
                if [[ ! "$_" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
                    continue
                fi
                
                # Skip if not matching the filter category
                if [ -n "$filter_category" ] && [ "$category" != "$filter_category" ]; then
                    continue
                fi
                
                # Check if task already exists in our list
                local found=0
                for i in "${!tasks[@]}"; do
                    if [ "${tasks[$i]}" = "$task" ] && [ "${categories[$i]}" = "$category" ]; then
                        found=1
                        break
                    fi
                done
                
                if [ "$found" -eq 0 ]; then
                    tasks+=("$task")
                    categories+=("$category")
                fi
            done
            
            # Group by category
            local unique_categories=()
            
            for category in "${categories[@]}"; do
                if [[ ! " ${unique_categories[*]} " =~ " ${category} " ]]; then
                    unique_categories+=("$category")
                fi
            done
            
            # Sort categories alphabetically
            IFS=$'\n' unique_categories=($(sort <<<"${unique_categories[*]}"))
            unset IFS
            
            # Display tasks grouped by category
            for category in "${unique_categories[@]}"; do
                # Display category header
                if [ -n "$category" ]; then
                    echo -e "${CYAN}Category: $category${RESET}"
                else
                    echo -e "${CYAN}Uncategorized tasks:${RESET}"
                fi
                
                # Display tasks in this category
                local found=0
                for i in "${!tasks[@]}"; do
                    if [ "${categories[$i]}" = "$category" ]; then
                        echo "  - ${tasks[$i]}"
                        found=1
                    fi
                done
                
                if [ "$found" -eq 0 ]; then
                    echo "  (no tasks)"
                fi
                
                echo
            done
            ;;
            
        categories)
            if [ ! -f "$TIMER_HISTORY" ]; then
                echo -e "${RED}No timer history found${RESET}"
                return 1
            fi
            
            echo -e "${GREEN}Task categories:${RESET}"
            
            # Collect unique categories
            local unique_categories=()
            
            tail -n "+2" "$TIMER_HISTORY" | while IFS='|' read -r _ _ category _ _ _; do
                # Skip header or invalid lines
                if [[ ! "$_" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
                    continue
                fi
                
                # Skip empty categories
                if [ -z "$category" ]; then
                    continue
                fi
                
                if [[ ! " ${unique_categories[*]} " =~ " ${category} " ]]; then
                    unique_categories+=("$category")
                fi
            done
            
            # Sort categories alphabetically
            IFS=$'\n' unique_categories=($(sort <<<"${unique_categories[*]}"))
            unset IFS
            
            # Display categories
            if [ ${#unique_categories[@]} -eq 0 ]; then
                echo -e "${YELLOW}No categories found in task history${RESET}"
            else
                for category in "${unique_categories[@]}"; do
                    echo -e "${CYAN}$category${RESET}"
                done
            fi
            ;;
            
        clean)
            if [ ! -f "$TIMER_HISTORY" ]; then
                echo -e "${RED}No timer history found${RESET}"
                return 1
            fi
            
            echo -e "${YELLOW}Cleaning up timer history...${RESET}"
            
            # Create a backup first
            cp "$TIMER_HISTORY" "${TIMER_HISTORY}.bak"
            echo -e "${CYAN}Backup saved to ${TIMER_HISTORY}.bak${RESET}"
            
            # Calculate date 30 days ago
            local cutoff_date=$(date -d "30 days ago" "+%Y-%m-%d" 2>/dev/null || date -v-30d "+%Y-%m-%d" 2>/dev/null)
            
            # Keep header line and recent entries
            local header=$(head -n 1 "$TIMER_HISTORY")
            local recent_entries=$(tail -n +2 "$TIMER_HISTORY" | grep -v "^start_time" | awk -F"|" -v cutoff="$cutoff_date" '$1 >= cutoff')
            
            # Write back to file
            echo "$header" > "$TIMER_HISTORY"
            echo "$recent_entries" >> "$TIMER_HISTORY"
            
            # Get line count
            local line_count=$(grep -c "" "$TIMER_HISTORY")
            
            echo -e "${GREEN}Timer history cleaned. Kept $((line_count - 1)) entries from the last 30 days.${RESET}"
            ;;
            
        *)
            echo -e "${RED}Unknown command: $cmd${RESET}"
            echo -e "${YELLOW}Usage:${RESET} timer [start|stop|status|history|report|list|categories|clean] [args]"
            return 1
            ;;
    esac
}

# Timer aliases
alias ts="timer start"
alias te="timer stop"
alias tt="timer status"
alias th="timer history"
alias tr="timer report"

# ===========================================
# Project Management Functions
# ===========================================

# Function to create and manage project tasks
function project() {
    local cmd="$1"
    shift
    
    # Initialize directories
    _init_productivity_dirs
    
    if [ -z "$cmd" ]; then
        echo -e "${GREEN}Project Management${RESET}"
        echo -e "${YELLOW}Usage:${RESET} project [command] [args]"
        echo
        echo -e "${CYAN}Commands:${RESET}"
        echo "  list              : List all projects"
        echo "  create <name>     : Create a new project"
        echo "  view <name>       : View a project's tasks"
        echo "  add <project> <task> [priority] : Add task to project (priority: high/medium/low)"
        echo "  done <project> <task_id> : Mark task as completed"
        echo "  delete <project>  : Delete a project"
        echo "  rename <old> <new> : Rename a project"
        echo "  backup            : Backup all projects"
        echo "  restore <file>    : Restore projects from backup"
        return 0
    fi
    
    case "$cmd" in
        list)
            echo -e "${YELLOW}Available projects:${RESET}"
            
            # Check if any projects exist
            if [ ! "$(ls -A "$PROJECT_DIR" 2>/dev/null)" ]; then
                echo -e "${CYAN}No projects found. Create one with 'project create <name>'${RESET}"
                return 0
            fi
            
            # List projects with task counts and completion status
            for project_file in "$PROJECT_DIR"/*; do
                if [ -f "$project_file" ]; then
                    local project_name=$(basename "$project_file")
                    local total_tasks=$(grep -c "^\[" "$project_file")
                    local completed_tasks=$(grep -c "^\[x\]" "$project_file")
                    local completion_percentage=0
                    
                    if [ "$total_tasks" -gt 0 ]; then
                        completion_percentage=$(( (completed_tasks * 100) / total_tasks ))
                    fi
                    
                    # Check if project has a due date
                    local due_date=""
                    if grep -q "^# Due:" "$project_file"; then
                        due_date=$(grep "^# Due:" "$project_file" | sed 's/^# Due: //')
                        
                        # Calculate days until due date
                        local today=$(date +%s)
                        local due_epoch=$(date -d "$due_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$due_date" +%s 2>/dev/null)
                        local days_left=$(( (due_epoch - today) / 86400 ))
                        
                        if [ "$days_left" -lt 0 ]; then
                            due_date="${RED}$due_date (${days_left#-} days overdue)${RESET}"
                        elif [ "$days_left" -lt 3 ]; then
                            due_date="${YELLOW}$due_date ($days_left days left)${RESET}"
                        else
                            due_date="${GREEN}$due_date ($days_left days left)${RESET}"
                        fi
                    fi
                    
                    # Format the status based on completion percentage
                    local status_color="${GREEN}"
                    if [ "$completion_percentage" -lt 30 ]; then
                        status_color="${RED}"
                    elif [ "$completion_percentage" -lt 70 ]; then
                        status_color="${YELLOW}"
                    fi
                    
                    echo -ne "${GREEN}$project_name${RESET} - $completed_tasks/$total_tasks tasks completed (${status_color}$completion_percentage%${RESET})"
                    
                    if [ -n "$due_date" ]; then
                        echo -e " - Due: $due_date"
                    else
                        echo
                    fi
                fi
            done
            ;;
            
        create)
            local project_name="$1"
            
            if [ -z "$project_name" ]; then
                echo -e "${RED}Error: Project name is required${RESET}"
                return 1
            fi
            
            if [ -f "$PROJECT_DIR/$project_name" ]; then
                echo -e "${RED}Error: Project '$project_name' already exists${RESET}"
                return 1
            fi
            
            # Check if we should add a due date
            local due_date=""
            echo -e "${YELLOW}Add a due date for this project? [y/N]${RESET}"
            read -r add_due_date
            
            if [[ "$add_due_date" =~ ^[yY]$ ]]; then
                echo -e "${YELLOW}Enter due date (YYYY-MM-DD format, or 'today', 'tomorrow', '+7days'):${RESET}"
                read -r due_date_input
                
                # Process due date input
                case "$due_date_input" in
                    today)
                        due_date=$(date "+%Y-%m-%d")
                        ;;
                    tomorrow)
                        due_date=$(date -d "tomorrow" "+%Y-%m-%d" 2>/dev/null || date -v+1d "+%Y-%m-%d" 2>/dev/null)
                        ;;
                    +[0-9]*days)
                        local days=${due_date_input#+}
                        days=${days%days}
                        due_date=$(date -d "+$days days" "+%Y-%m-%d" 2>/dev/null || date -v+${days}d "+%Y-%m-%d" 2>/dev/null)
                        ;;
                    *)
                        due_date="$due_date_input"
                        ;;
                esac
            fi
            
            # Create project file
            echo "# Project: $project_name" > "$PROJECT_DIR/$project_name"
            echo "# Created: $(date)" >> "$PROJECT_DIR/$project_name"
            
            if [ -n "$due_date" ]; then
                echo "# Due: $due_date" >> "$PROJECT_DIR/$project_name"
            fi
            
            echo "" >> "$PROJECT_DIR/$project_name"
            
            echo -e "${GREEN}Project '$project_name' created successfully${RESET}"
            
            # Ask if user wants to add initial tasks
            echo -e "${YELLOW}Add initial tasks to this project? [y/N]${RESET}"
            read -r add_tasks
            
            if [[ "$add_tasks" =~ ^[yY]$ ]]; then
                local keep_adding=1
                
                while [ $keep_adding -eq 1 ]; do
                    echo -e "${YELLOW}Enter task description (or leave empty to stop):${RESET}"
                    read -r task_desc
                    
                    if [ -z "$task_desc" ]; then
                        keep_adding=0
                        continue
                    fi
                    
                    echo -e "${YELLOW}Priority (high/medium/low, default: medium):${RESET}"
                    read -r priority
                    
                    # Set default priority
                    if [ -z "$priority" ]; then
                        priority="medium"
                    fi
                    
                    # Add task to project
                    project add "$project_name" "$task_desc" "$priority"
                done
            fi
            ;;
            
        view)
            local project_name="$1"
            
            if [ -z "$project_name" ]; then
                echo -e "${RED}Error: Project name is required${RESET}"
                return 1
            fi
            
            if [ ! -f "$PROJECT_DIR/$project_name" ]; then
                echo -e "${RED}Error: Project '$project_name' not found${RESET}"
                return 1
            fi
            
            echo -e "${YELLOW}Project: $project_name${RESET}"
            echo
            
            # Show due date if present
            if grep -q "^# Due:" "$PROJECT_DIR/$project_name"; then
                local due_date=$(grep "^# Due:" "$PROJECT_DIR/$project_name" | sed 's/^# Due: //')
                
                # Calculate days until due date
                local today=$(date +%s)
                local due_epoch=$(date -d "$due_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$due_date" +%s 2>/dev/null)
                local days_left=$(( (due_epoch - today) / 86400 ))
                
                if [ "$days_left" -lt 0 ]; then
                    echo -e "${RED}Due: $due_date (${days_left#-} days overdue)${RESET}"
                elif [ "$days_left" -lt 3 ]; then
                    echo -e "${YELLOW}Due: $due_date ($days_left days left)${RESET}"
                else
                    echo -e "${GREEN}Due: $due_date ($days_left days left)${RESET}"
                fi
                
                echo
            fi
            
            # Calculate task statistics
            local total_tasks=$(grep -c "^\[" "$PROJECT_DIR/$project_name")
            local completed_tasks=$(grep -c "^\[x\]" "$PROJECT_DIR/$project_name")
            local pending_tasks=$((total_tasks - completed_tasks))
            local completion_percentage=0
            
            if [ "$total_tasks" -gt 0 ]; then
                completion_percentage=$(( (completed_tasks * 100) / total_tasks ))
            fi
            
            echo -e "${CYAN}Tasks: $total_tasks total, $completed_tasks completed, $pending_tasks pending ($completion_percentage% done)${RESET}"
            echo
            
            # Display tasks with color coding
            local task_id=0
            while IFS= read -r line; do
                if [[ "$line" == \#* || -z "$line" ]]; then
                    # Skip comments and empty lines
                    continue
                elif [[ "$line" == \[x\]* ]]; then
                    # Completed task
                    task_id=$((task_id + 1))
                    echo -e "${GREEN}$task_id. $line${RESET}"
                elif [[ "$line" == \[\]\ \*HIGH\*:* ]]; then
                    # High priority task
                    task_id=$((task_id + 1))
                    echo -e "${RED}$task_id. ${line/\[\] \*HIGH\*:/\[\] }${RESET}"
                elif [[ "$line" == \[\]\ \*MEDIUM\*:* ]]; then
                    # Medium priority task
                    task_id=$((task_id + 1))
                    echo -e "${YELLOW}$task_id. ${line/\[\] \*MEDIUM\*:/\[\] }${RESET}"
                elif [[ "$line" == \[\]\ \*LOW\*:* ]]; then
                    # Low priority task
                    task_id=$((task_id + 1))
                    echo -e "${BLUE}$task_id. ${line/\[\] \*LOW\*:/\[\] }${RESET}"
                elif [[ "$line" == \[\]* ]]; then
                    # Normal task
                    task_id=$((task_id + 1))
                    echo -e "$task_id. $line"
                fi
            done < "$PROJECT_DIR/$project_name"
            
            if [ "$task_id" -eq 0 ]; then
                echo -e "${CYAN}No tasks found. Add tasks with 'project add $project_name <task>'${RESET}"
            fi
            
            # Check for git integration if git module is loaded
            if declare -f _is_git_repo > /dev/null && type _is_git_repo &>/dev/null; then
                # Look for a git repo name in the project file
                if grep -q "^# Git:" "$PROJECT_DIR/$project_name"; then
                    local git_repo=$(grep "^# Git:" "$PROJECT_DIR/$project_name" | sed 's/^# Git: //')
                    
                    echo
                    echo -e "${CYAN}Git repository: $git_repo${RESET}"
                    
                    # Check if the repository exists locally
                    if [ -d "$git_repo" ] && (cd "$git_repo" && _is_git_repo &>/dev/null); then
                        echo -e "${GREEN}Found local repository.${RESET}"
                        
                        # Show git status if available
                        if type git_status_brief &>/dev/null; then
                            (cd "$git_repo" && git_status_brief)
                        elif command -v git &>/dev/null; then
                            (cd "$git_repo" && echo -e "${YELLOW}Status:${RESET} $(git status -s)")
                        fi
                    else
                        echo -e "${YELLOW}Repository not found locally.${RESET}"
                    fi
                fi
            fi
            ;;
            
        add)
            local project_name="$1"
            local task_desc="$2"
            local priority="${3:-}"
            
            if [ -z "$project_name" ] || [ -z "$task_desc" ]; then
                echo -e "${RED}Error: Project name and task description are required${RESET}"
                return 1
            fi
            
            if [ ! -f "$PROJECT_DIR/$project_name" ]; then
                echo -e "${RED}Error: Project '$project_name' not found${RESET}"
                return 1
            fi
            
            # Format task based on priority
            local task_line=""
            case "$priority" in
                high|HIGH)
                    task_line="[] *HIGH*: $task_desc"
                    ;;
                medium|MEDIUM)
                    task_line="[] *MEDIUM*: $task_desc"
                    ;;
                low|LOW)
                    task_line="[] *LOW*: $task_desc"
                    ;;
                *)
                    task_line="[] $task_desc"
                    ;;
            esac
            
            # Add task to project file
            echo "$task_line" >> "$PROJECT_DIR/$project_name"
            
            echo -e "${GREEN}Task added to project '$project_name'${RESET}"
            
            # Start timer for this task?
            echo -e "${YELLOW}Start timer for this task? [y/N]${RESET}"
            read -r start_timer
            
            if [[ "$start_timer" =~ ^[yY]$ ]]; then
                # Use project name as category
                timer start "$project_name:$task_desc"
            fi
            ;;
            
        done)
            local project_name="$1"
            local task_id="$2"
            
            if [ -z "$project_name" ] || [ -z "$task_id" ]; then
                echo -e "${RED}Error: Project name and task ID are required${RESET}"
                return 1
            fi
            
            if [ ! -f "$PROJECT_DIR/$project_name" ]; then
                echo -e "${RED}Error: Project '$project_name' not found${RESET}"
                return 1
            fi
            
            # Validate task ID
            if ! [[ "$task_id" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}Error: Task ID must be a number${RESET}"
                return 1
            fi
            
            # Find and mark task as completed
            local temp_file=$(mktemp)
            local task_count=0
            local task_found=0
            local task_text=""
            
            while IFS= read -r line; do
                if [[ "$line" == \[*\]* && ! "$line" == \#* ]]; then
                    task_count=$((task_count + 1))
                    
                    if [ "$task_count" -eq "$task_id" ]; then
                        # Extract task text for timer completion
                        if [[ "$line" == *":"* ]]; then
                            task_text=$(echo "$line" | sed -E 's/\[[^\]]*\] \*[A-Z]+\*: (.*)/\1/')
                        else
                            task_text=$(echo "$line" | sed -E 's/\[[^\]]*\] (.*)/\1/')
                        fi
                        
                        # Replace [] with [x] to mark as completed
                        line="${line/\[\]/\[x\]}"
                        task_found=1
                    fi
                fi
                
                echo "$line" >> "$temp_file"
            done < "$PROJECT_DIR/$project_name"
            
            if [ "$task_found" -eq 0 ]; then
                echo -e "${RED}Error: Task ID $task_id not found in project '$project_name'${RESET}"
                rm "$temp_file"
                return 1
            fi
            
            # Replace original file with modified one
            mv "$temp_file" "$PROJECT_DIR/$project_name"
            
            echo -e "${GREEN}Task $task_id marked as completed in project '$project_name'${RESET}"
            
            # Stop timer if running for this task
            if [ -f "$TIMER_FILE" ]; then
                local start_data=$(cat "$TIMER_FILE")
                local timer_category=$(echo "$start_data" | cut -d' ' -f2)
                local timer_task=$(echo "$start_data" | cut -d' ' -f3-)
                
                # If timer is running for this project and task, offer to stop it
                if [[ "$timer_category" == "$project_name" && "$timer_task" == *"$task_text"* ]]; then
                    echo -e "${YELLOW}Timer is running for this task. Stop it? [Y/n]${RESET}"
                    read -r stop_timer
                    
                    if [[ ! "$stop_timer" =~ ^[nN]$ ]]; then
                        timer stop
                    fi
                fi
            fi
            ;;
            
        delete)
            local project_name="$1"
            
            if [ -z "$project_name" ]; then
                echo -e "${RED}Error: Project name is required${RESET}"
                return 1
            fi
            
            if [ ! -f "$PROJECT_DIR/$project_name" ]; then
                echo -e "${RED}Error: Project '$project_name' not found${RESET}"
                return 1
            fi
            
            echo -e "${YELLOW}Are you sure you want to delete project '$project_name'? [y/N]${RESET}"
            read -r confirm
            
            if [[ "$confirm" =~ ^[yY]$ ]]; then
                # Create a backup first
                local backup_dir="${PRODUCTIVITY_BACKUP_DIR}/projects"
                mkdir -p "$backup_dir"
                cp "$PROJECT_DIR/$project_name" "$backup_dir/${project_name}.$(date +%Y%m%d_%H%M%S).bak"
                
                # Delete the project
                rm "$PROJECT_DIR/$project_name"
                echo -e "${GREEN}Project '$project_name' deleted successfully${RESET}"
                echo -e "${CYAN}(A backup was saved to $backup_dir)${RESET}"
            else
                echo -e "${YELLOW}Project deletion cancelled${RESET}"
            fi
            ;;
            
        rename)
            local old_name="$1"
            local new_name="$2"
            
            if [ -z "$old_name" ] || [ -z "$new_name" ]; then
                echo -e "${RED}Error: Old and new project names are required${RESET}"
                return 1
            fi
            
            if [ ! -f "$PROJECT_DIR/$old_name" ]; then
                echo -e "${RED}Error: Project '$old_name' not found${RESET}"
                return 1
            fi
            
            if [ -f "$PROJECT_DIR/$new_name" ]; then
                echo -e "${RED}Error: Project '$new_name' already exists${RESET}"
                return 1
            fi
            
            mv "$PROJECT_DIR/$old_name" "$PROJECT_DIR/$new_name"
            
            # Update project header in file
            sed -i "s/# Project: $old_name/# Project: $new_name/" "$PROJECT_DIR/$new_name" 2>/dev/null || 
                sed -i '' "s/# Project: $old_name/# Project: $new_name/" "$PROJECT_DIR/$new_name"
            
            echo -e "${GREEN}Project renamed from '$old_name' to '$new_name'${RESET}"
            ;;
            
        backup)
            echo -e "${YELLOW}Backing up all projects...${RESET}"
            
            local timestamp=$(date +"%Y%m%d_%H%M%S")
            local backup_dir="${PRODUCTIVITY_BACKUP_DIR}/projects"
            local backup_file="${backup_dir}/projects_backup_${timestamp}.tar.gz"
            
            # Create backup directory if it doesn't exist
            mkdir -p "$backup_dir"
            
            # Create tar archive of all projects
            tar -czf "$backup_file" -C "$PROJECT_DIR" .
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Projects backed up successfully to: $backup_file${RESET}"
                
                # Show statistics
                local project_count=$(find "$PROJECT_DIR" -type f | wc -l)
                local backup_size=$(du -h "$backup_file" | cut -f1)
                
                echo -e "${CYAN}Backed up $project_count projects ($backup_size)${RESET}"
            else
                echo -e "${RED}Backup failed${RESET}"
                return 1
            fi
            ;;
            
        restore)
            local backup_file="$1"
            
            if [ -z "$backup_file" ]; then
                echo -e "${YELLOW}Available project backups:${RESET}"
                
                local backup_dir="${PRODUCTIVITY_BACKUP_DIR}/projects"
                
                if [ ! -d "$backup_dir" ] || [ -z "$(ls -A "$backup_dir" 2>/dev/null)" ]; then
                    echo -e "${CYAN}No backups found.${RESET}"
                    return 1
                fi
                
                ls -lt "${backup_dir}" | grep "projects_backup_" | awk '{print $6, $7, $8, $9}' | nl -w2 -s') '
                
                echo -e "${YELLOW}Usage: project restore <backup_file_or_number>${RESET}"
                return 0
            fi
            
            # Check if input is a number
            if [[ "$backup_file" =~ ^[0-9]+$ ]]; then
                local backup_dir="${PRODUCTIVITY_BACKUP_DIR}/projects"
                local selected_backup=$(ls -t "${backup_dir}" | grep "projects_backup_" | sed -n "${backup_file}p")
                
                if [ -z "$selected_backup" ]; then
                    echo -e "${RED}Error: Backup #$backup_file not found${RESET}"
                    return 1
                fi
                
                backup_file="${backup_dir}/${selected_backup}"
            fi
            
            # Verify backup file exists
            if [ ! -f "$backup_file" ]; then
                echo -e "${RED}Error: Backup file not found: $backup_file${RESET}"
                return 1
            fi
            
            echo -e "${YELLOW}Restoring projects from: $backup_file${RESET}"
            echo -e "${RED}Warning: This will overwrite existing projects with the same name!${RESET}"
            echo -e "${YELLOW}Continue? [y/N]${RESET}"
            read -r confirm
            
            if [[ ! "$confirm" =~ ^[yY]$ ]]; then
                echo -e "${YELLOW}Restore cancelled.${RESET}"
                return 1
            fi
            
            # Create a backup of current projects
            local timestamp=$(date +"%Y%m%d_%H%M%S")
            local current_backup="${PRODUCTIVITY_BACKUP_DIR}/projects/current_projects_${timestamp}.tar.gz"
            
            tar -czf "$current_backup" -C "$PROJECT_DIR" . 2>/dev/null
            
            if [ $? -eq 0 ]; then
                echo -e "${CYAN}Current projects backed up to: $current_backup${RESET}"
            fi
            
            # Extract backup to projects directory
            tar -xzf "$backup_file" -C "$PROJECT_DIR"
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Projects restored successfully!${RESET}"
                
                # Show project count
                local project_count=$(find "$PROJECT_DIR" -type f | wc -l)
                echo -e "${CYAN}Restored $project_count projects${RESET}"
            else
                echo -e "${RED}Restore failed${RESET}"
                return 1
            fi
            ;;
            
        *)
            echo -e "${RED}Unknown command: $cmd${RESET}"
            echo -e "${YELLOW}Usage:${RESET} project [list|create|view|add|done|delete|rename|backup|restore] [args]"
            return 1
            ;;
    esac
}

# Project management alias
alias p="project"
alias pl="project list"
alias pv="project view"
alias pa="project add"
alias pd="project done"

# ===========================================
# Notes and Quick Reminders
# ===========================================

# Function to manage quick notes
function note() {
    local cmd="$1"
    shift
    
    # Initialize directories
    _init_productivity_dirs
    
    if [ -z "$cmd" ]; then
        echo -e "${GREEN}Quick Notes${RESET}"
        echo -e "${YELLOW}Usage:${RESET} note [command] [args]"
        echo
        echo -e "${CYAN}Commands:${RESET}"
        echo "  list              : List all notes"
        echo "  add <title> <text> : Add a new note"
        echo "  view <title>      : View a note"
        echo "  edit <title>      : Edit a note"
        echo "  delete <title>    : Delete a note"
        echo "  search <query>    : Search notes for text"
        echo "  export <format>   : Export notes (format: text, md, html)"
        echo "  tag <title> <tags>: Add tags to a note (comma-separated)"
        echo "  bytag <tag>       : List notes with a specific tag"
        return 0
    fi
    
    case "$cmd" in
        list)
            echo -e "${YELLOW}Quick Notes:${RESET}"
            
            if [ ! "$(ls -A "$NOTES_DIR" 2>/dev/null)" ]; then
                echo -e "${CYAN}No notes found. Create one with 'note add <title> <text>'${RESET}"
                return 0
            fi
            
            # Count total notes
            local note_count=$(find "$NOTES_DIR" -type f | wc -l)
            echo -e "${CYAN}Found $note_count notes:${RESET}"
            echo
            
            for note_file in "$NOTES_DIR"/*; do
                if [ -f "$note_file" ]; then
                    local note_title=$(basename "$note_file")
                    local note_date=$(stat -c %y "$note_file" 2>/dev/null || stat -f "%Sm" "$note_file" 2>/dev/null)
                    local note_date_formatted=$(date -d "${note_date}" "+%Y-%m-%d %H:%M" 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "${note_date:0:19}" "+%Y-%m-%d %H:%M" 2>/dev/null)
                    
                    # Extract first line of content for preview
                    local preview=$(head -n 3 "$note_file" | tail -n 1 | cut -c 1-50)
                    if [ ${#preview} -eq 50 ]; then
                        preview="${preview}..."
                    fi
                    
                    # Check for tags
                    local tags=""
                    if grep -q "^# Tags:" "$note_file"; then
                        tags=$(grep "^# Tags:" "$note_file" | sed 's/^# Tags: //')
                        tags="${YELLOW}[${tags}]${RESET}"
                    fi
                    
                    echo -e "${GREEN}$note_title${RESET} - $note_date_formatted $tags"
                    echo -e "  ${CYAN}${preview}${RESET}"
                fi
            done
            ;;
            
        add)
            local note_title="$1"
            local note_text="$2"
            
            if [ -z "$note_title" ]; then
                echo -e "${RED}Error: Note title is required${RESET}"
                return 1
            fi
            
            if [ -z "$note_text" ]; then
                # No text provided, enter interactive mode
                echo -e "${YELLOW}Enter note text (Ctrl+D to save):${RESET}"
                note_text=$(cat)
            fi
            
            # Ask for tags
            local tags=""
            echo -e "${YELLOW}Enter tags (comma-separated, or leave empty):${RESET}"
            read -r tags
            
            # Save note with title and timestamp
            echo "# $note_title" > "$NOTES_DIR/$note_title"
            echo "# Created: $(date)" >> "$NOTES_DIR/$note_title"
            
            if [ -n "$tags" ]; then
                echo "# Tags: $tags" >> "$NOTES_DIR/$note_title"
            fi
            
            echo "" >> "$NOTES_DIR/$note_title"
            echo "$note_text" >> "$NOTES_DIR/$note_title"
            
            echo -e "${GREEN}Note '$note_title' saved successfully${RESET}"
            
            # Ask if this note is related to a project
            echo -e "${YELLOW}Link this note to a project? [y/N]${RESET}"
            read -r link_project
            
            if [[ "$link_project" =~ ^[yY]$ ]]; then
                # List available projects
                echo -e "${CYAN}Available projects:${RESET}"
                
                local projects=()
                local i=0
                
                for project_file in "$PROJECT_DIR"/*; do
                    if [ -f "$project_file" ]; then
                        local project_name=$(basename "$project_file")
                        projects[$i]="$project_name"
                        echo -e "$i: $project_name"
                        i=$((i + 1))
                    fi
                done
                
                if [ $i -eq 0 ]; then
                    echo -e "${YELLOW}No projects found. Create one with 'project create <name>'${RESET}"
                else
                    echo -e "${YELLOW}Enter project number:${RESET}"
                    read -r project_num
                    
                    if [[ "$project_num" =~ ^[0-9]+$ ]] && [ "$project_num" -lt $i ]; then
                        local selected_project="${projects[$project_num]}"
                        
                        # Add note reference to project
                        echo "" >> "$PROJECT_DIR/$selected_project"
                        echo "# Note: $note_title" >> "$PROJECT_DIR/$selected_project"
                        
                        # Add project reference to note
                        echo "" >> "$NOTES_DIR/$note_title"
                        echo "# Related Project: $selected_project" >> "$NOTES_DIR/$note_title"
                        
                        echo -e "${GREEN}Linked note to project '$selected_project'${RESET}"
                    else
                        echo -e "${RED}Invalid project number${RESET}"
                    fi
                fi
            fi
            ;;
            
        view)
            local note_title="$1"
            
            if [ -z "$note_title" ]; then
                echo -e "${RED}Error: Note title is required${RESET}"
                return 1
            fi
            
            # Try to find note by prefix if exact match not found
            if [ ! -f "$NOTES_DIR/$note_title" ]; then
                local matched_note=""
                for note_file in "$NOTES_DIR"/*; do
                    if [[ "$(basename "$note_file")" == "$note_title"* ]]; then
                        matched_note="$(basename "$note_file")"
                        break
                    fi
                done
                
                if [ -n "$matched_note" ]; then
                    note_title="$matched_note"
                    echo -e "${YELLOW}Found matching note: $note_title${RESET}"
                else
                    echo -e "${RED}Error: Note '$note_title' not found${RESET}"
                    return 1
                fi
            fi
            
            echo -e "${YELLOW}Note: $note_title${RESET}"
            echo
            
            # Display note content
            if command -v bat &> /dev/null; then
                bat --style=plain "$NOTES_DIR/$note_title"
            else
                cat "$NOTES_DIR/$note_title"
            fi
            
            # Check for related project
            if grep -q "^# Related Project:" "$NOTES_DIR/$note_title"; then
                local related_project=$(grep "^# Related Project:" "$NOTES_DIR/$note_title" | sed 's/^# Related Project: //')
                
                echo
                echo -e "${CYAN}Related project: $related_project${RESET}"
                
                if [ -f "$PROJECT_DIR/$related_project" ]; then
                    echo -e "${YELLOW}View related project? [y/N]${RESET}"
                    read -r view_project
                    
                    if [[ "$view_project" =~ ^[yY]$ ]]; then
                        project view "$related_project"
                    fi
                else
                    echo -e "${YELLOW}(Project no longer exists)${RESET}"
                fi
            fi
            ;;
            
        edit)
            local note_title="$1"
            
            if [ -z "$note_title" ]; then
                echo -e "${RED}Error: Note title is required${RESET}"
                return 1
            fi
            
            # Try to find note by prefix if exact match not found
            if [ ! -f "$NOTES_DIR/$note_title" ]; then
                local matched_note=""
                for note_file in "$NOTES_DIR"/*; do
                    if [[ "$(basename "$note_file")" == "$note_title"* ]]; then
                        matched_note="$(basename "$note_file")"
                        break
                    fi
                done
                
                if [ -n "$matched_note" ]; then
                    note_title="$matched_note"
                    echo -e "${YELLOW}Found matching note: $note_title${RESET}"
                else
                    echo -e "${RED}Error: Note '$note_title' not found${RESET}"
                    return 1
                fi
            fi
            
            # Create a backup before editing
            cp "$NOTES_DIR/$note_title" "$NOTES_DIR/$note_title.bak"
            
            # Open note in text editor
            if [ -n "$EDITOR" ]; then
                $EDITOR "$NOTES_DIR/$note_title"
            elif command -v nano &> /dev/null; then
                nano "$NOTES_DIR/$note_title"
            elif command -v vim &> /dev/null; then
                vim "$NOTES_DIR/$note_title"
            else
                echo -e "${RED}No text editor found. Set \$EDITOR or install nano/vim${RESET}"
                return 1
            fi
            
            # Update modification time in the file
            sed -i "s/^# Modified:.*$/# Modified: $(date)/" "$NOTES_DIR/$note_title" 2>/dev/null || 
                sed -i '' "s/^# Modified:.*$/# Modified: $(date)/" "$NOTES_DIR/$note_title" 2>/dev/null
            
            # If no modification timestamp exists, add one
            if ! grep -q "^# Modified:" "$NOTES_DIR/$note_title"; then
                # Find the position after "# Created:" line
                local created_line=$(grep -n "^# Created:" "$NOTES_DIR/$note_title" | cut -d: -f1)
                if [ -n "$created_line" ]; then
                    # Insert the modification line after the creation line
                    sed -i "${created_line}a\\# Modified: $(date)" "$NOTES_DIR/$note_title" 2>/dev/null || 
                        sed -i '' "${created_line}a\\
# Modified: $(date)" "$NOTES_DIR/$note_title"
                fi
            fi
            
            echo -e "${GREEN}Note '$note_title' updated${RESET}"
            ;;
            
        delete)
            local note_title="$1"
            
            if [ -z "$note_title" ]; then
                echo -e "${RED}Error: Note title is required${RESET}"
                return 1
            fi
            
            # Try to find note by prefix if exact match not found
            if [ ! -f "$NOTES_DIR/$note_title" ]; then
                local matched_note=""
                for note_file in "$NOTES_DIR"/*; do
                    if [[ "$(basename "$note_file")" == "$note_title"* ]]; then
                        matched_note="$(basename "$note_file")"
                        break
                    fi
                done
                
                if [ -n "$matched_note" ]; then
                    note_title="$matched_note"
                    echo -e "${YELLOW}Found matching note: $note_title${RESET}"
                else
                    echo -e "${RED}Error: Note '$note_title' not found${RESET}"
                    return 1
                fi
            fi
            
            echo -e "${YELLOW}Are you sure you want to delete note '$note_title'? [y/N]${RESET}"
            read -r confirm
            
            if [[ "$confirm" =~ ^[yY]$ ]]; then
                # Create a backup before deleting
                local backup_dir="${PRODUCTIVITY_BACKUP_DIR}/notes"
                mkdir -p "$backup_dir"
                cp "$NOTES_DIR/$note_title" "$backup_dir/${note_title}.$(date +%Y%m%d_%H%M%S).bak"
                
                # Remove note references from projects
                for project_file in "$PROJECT_DIR"/*; do
                    if [ -f "$project_file" ] && grep -q "^# Note: $note_title" "$project_file"; then
                        sed -i "/^# Note: $note_title/d" "$project_file" 2>/dev/null || 
                            sed -i '' "/^# Note: $note_title/d" "$project_file"
                    fi
                done
                
                # Delete the note
                rm "$NOTES_DIR/$note_title"
                echo -e "${GREEN}Note '$note_title' deleted successfully${RESET}"
                echo -e "${CYAN}(A backup was saved to $backup_dir)${RESET}"
            else
                echo -e "${YELLOW}Note deletion cancelled${RESET}"
            fi
            ;;
            
        search)
            local query="$1"
            
            if [ -z "$query" ]; then
                echo -e "${RED}Error: Search query is required${RESET}"
                return 1
            fi
            
            echo -e "${YELLOW}Searching notes for: $query${RESET}"
            echo
            
            local found=0
            for note_file in "$NOTES_DIR"/*; do
                if [ -f "$note_file" ]; then
                    if grep -q -i "$query" "$note_file"; then
                        local note_title=$(basename "$note_file")
                        echo -e "${GREEN}Found in: $note_title${RESET}"
                        
                        # Extract tags if any
                        local tags=""
                        if grep -q "^# Tags:" "$note_file"; then
                            tags=$(grep "^# Tags:" "$note_file" | sed 's/^# Tags: //')
                            echo -e "${YELLOW}Tags: ${tags}${RESET}"
                        fi
                        
                        # Show matches with surrounding context
                        grep -i --color=always -A 1 -B 1 "$query" "$note_file" | sed 's/^/  /'
                        echo
                        
                        found=1
                    fi
                fi
            done
            
            if [ "$found" -eq 0 ]; then
                echo -e "${CYAN}No matches found for '$query'${RESET}"
            else
                echo -e "${YELLOW}View any of these notes? [y/N]${RESET}"
                read -r view_note
                
                if [[ "$view_note" =~ ^[yY]$ ]]; then
                    echo -e "${YELLOW}Enter note title:${RESET}"
                    read -r selected_note
                    
                    if [ -n "$selected_note" ]; then
                        note view "$selected_note"
                    fi
                fi
            fi
            ;;
            
        export)
            local format="$1"
            local output_file="$2"
            
            if [ -z "$format" ]; then
                echo -e "${RED}Error: Export format is required (text, md, html)${RESET}"
                return 1
            fi
            
            if [ -z "$output_file" ]; then
                output_file="notes_export_$(date +%Y%m%d).${format}"
            fi
            
            echo -e "${YELLOW}Exporting notes to $format format...${RESET}"
            
            case "$format" in
                text)
                    # Simple text export
                    {
                        echo "Notes Export - $(date)"
                        echo "===================="
                        echo
                        
                        for note_file in "$NOTES_DIR"/*; do
                            if [ -f "$note_file" ]; then
                                echo "===== $(basename "$note_file") ====="
                                cat "$note_file"
                                echo
                                echo "-------------------"
                                echo
                            fi
                        done
                    } > "$output_file"
                    ;;
                    
                md|markdown)
                    # Markdown export
                    {
                        echo "# Notes Export - $(date)"
                        echo
                        
                        # Generate table of contents
                        echo "## Table of Contents"
                        echo
                        
                        for note_file in "$NOTES_DIR"/*; do
                            if [ -f "$note_file" ]; then
                                local note_title=$(basename "$note_file")
                                echo "- [${note_title}](#${note_title//' '/'-'})"
                            fi
                        done
                        
                        echo
                        
                        # Export note content
                        for note_file in "$NOTES_DIR"/*; do
                            if [ -f "$note_file" ]; then
                                local note_title=$(basename "$note_file")
                                echo "## ${note_title}"
                                
                                # Extract metadata
                                if grep -q "^# Created:" "$note_file"; then
                                    local created=$(grep "^# Created:" "$note_file" | sed 's/^# Created: //')
                                    echo "*Created: ${created}*"
                                fi
                                
                                if grep -q "^# Modified:" "$note_file"; then
                                    local modified=$(grep "^# Modified:" "$note_file" | sed 's/^# Modified: //')
                                    echo "*Modified: ${modified}*"
                                fi
                                
                                if grep -q "^# Tags:" "$note_file"; then
                                    local tags=$(grep "^# Tags:" "$note_file" | sed 's/^# Tags: //')
                                    echo "*Tags: ${tags}*"
                                fi
                                
                                echo
                                
                                # Skip metadata lines and output content
                                sed -n '/^[^#]/,$p' "$note_file"
                                
                                echo
                                echo "---"
                                echo
                            fi
                        done
                    } > "$output_file"
                    ;;
                    
                html)
                    # HTML export
                    {
                        echo "<!DOCTYPE html>"
                        echo "<html>"
                        echo "<head>"
                        echo "  <meta charset=\"utf-8\">"
                        echo "  <title>Notes Export - $(date +%Y-%m-%d)</title>"
                        echo "  <style>"
                        echo "    body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }"
                        echo "    h1 { color: #333; }"
                        echo "    h2 { color: #0066cc; margin-top: 30px; }"
                        echo "    .note { border: 1px solid #ddd; padding: 20px; margin-bottom: 20px; border-radius: 5px; }"
                        echo "    .metadata { color: #666; font-style: italic; margin-bottom: 10px; }"
                        echo "    .tags { background-color: #f0f0f0; padding: 5px; border-radius: 3px; display: inline-block; }"
                        echo "    .content { white-space: pre-wrap; }"
                        echo "    .toc { background-color: #f8f8f8; padding: 15px; border-radius: 5px; }"
                        echo "    .toc ul { list-style-type: none; padding-left: 20px; }"
                        echo "    .toc a { text-decoration: none; color: #0066cc; }"
                        echo "    .toc a:hover { text-decoration: underline; }"
                        echo "  </style>"
                        echo "</head>"
                        echo "<body>"
                        echo "  <h1>Notes Export - $(date)</h1>"
                        
                        # Generate table of contents
                        echo "  <div class=\"toc\">"
                        echo "    <h2>Table of Contents</h2>"
                        echo "    <ul>"
                        
                        for note_file in "$NOTES_DIR"/*; do
                            if [ -f "$note_file" ]; then
                                local note_title=$(basename "$note_file")
                                echo "      <li><a href=\"#${note_title//[^a-zA-Z0-9]/-}\">${note_title}</a></li>"
                            fi
                        done
                        
                        echo "    </ul>"
                        echo "  </div>"
                        
                        # Export note content
                        for note_file in "$NOTES_DIR"/*; do
                            if [ -f "$note_file" ]; then
                                local note_title=$(basename "$note_file")
                                local note_id="${note_title//[^a-zA-Z0-9]/-}"
                                
                                echo "  <div class=\"note\" id=\"${note_id}\">"
                                echo "    <h2>${note_title}</h2>"
                                echo "    <div class=\"metadata\">"
                                
                                # Extract metadata
                                if grep -q "^# Created:" "$note_file"; then
                                    local created=$(grep "^# Created:" "$note_file" | sed 's/^# Created: //')
                                    echo "      Created: ${created}<br>"
                                fi
                                
                                if grep -q "^# Modified:" "$note_file"; then
                                    local modified=$(grep "^# Modified:" "$note_file" | sed 's/^# Modified: //')
                                    echo "      Modified: ${modified}<br>"
                                fi
                                
                                if grep -q "^# Tags:" "$note_file"; then
                                    local tags=$(grep "^# Tags:" "$note_file" | sed 's/^# Tags: //')
                                    echo "      <span class=\"tags\">Tags: ${tags}</span>"
                                fi
                                
                                echo "    </div>"
                                
                                echo "    <div class=\"content\">"
                                # Skip metadata lines and output content, escape HTML special chars
                                sed -n '/^[^#]/,$p' "$note_file" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
                                echo "    </div>"
                                echo "  </div>"
                            fi
                        done
                        
                        echo "</body>"
                        echo "</html>"
                    } > "$output_file"
                    ;;
                    
                *)
                    echo -e "${RED}Error: Unsupported export format: $format${RESET}"
                    echo -e "${YELLOW}Supported formats: text, md, html${RESET}"
                    return 1
                    ;;
            esac
            
            echo -e "${GREEN}Notes exported to $output_file${RESET}"
            
            # Show file info
            local file_size=$(du -h "$output_file" | cut -f1)
            local file_count=$(find "$NOTES_DIR" -type f | wc -l)
            
            echo -e "${CYAN}Exported $file_count notes ($file_size)${RESET}"
            ;;
            
        tag)
            local note_title="$1"
            local tags="$2"
            
            if [ -z "$note_title" ] || [ -z "$tags" ]; then
                echo -e "${RED}Error: Note title and tags are required${RESET}"
                return 1
            fi
            
            # Try to find note by prefix if exact match not found
            if [ ! -f "$NOTES_DIR/$note_title" ]; then
                local matched_note=""
                for note_file in "$NOTES_DIR"/*; do
                    if [[ "$(basename "$note_file")" == "$note_title"* ]]; then
                        matched_note="$(basename "$note_file")"
                        break
                    fi
                done
                
                if [ -n "$matched_note" ]; then
                    note_title="$matched_note"
                    echo -e "${YELLOW}Found matching note: $note_title${RESET}"
                else
                    echo -e "${RED}Error: Note '$note_title' not found${RESET}"
                    return 1
                fi
            fi
            
            # Check if tags already exist
            if grep -q "^# Tags:" "$NOTES_DIR/$note_title"; then
                # Update existing tags
                sed -i "s/^# Tags:.*$/# Tags: $tags/" "$NOTES_DIR/$note_title" 2>/dev/null || 
                    sed -i '' "s/^# Tags:.*$/# Tags: $tags/" "$NOTES_DIR/$note_title"
                
                echo -e "${GREEN}Tags updated for note '$note_title'${RESET}"
            else
                # Find the position after "# Created:" line
                local created_line=$(grep -n "^# Created:" "$NOTES_DIR/$note_title" | cut -d: -f1)
                if [ -n "$created_line" ]; then
                    # Insert the tags line after the creation line
                    sed -i "${created_line}a\\# Tags: $tags" "$NOTES_DIR/$note_title" 2>/dev/null || 
                        sed -i '' "${created_line}a\\
# Tags: $tags" "$NOTES_DIR/$note_title"
                else
                    # If "# Created:" line not found, add tags at the top
                    sed -i "1i\\# Tags: $tags" "$NOTES_DIR/$note_title" 2>/dev/null || 
                        sed -i '' "1i\\
# Tags: $tags" "$NOTES_DIR/$note_title"
                fi
                
                echo -e "${GREEN}Tags added to note '$note_title'${RESET}"
            fi
            ;;
            
        bytag)
            local tag="$1"
            
            if [ -z "$tag" ]; then
                echo -e "${RED}Error: Tag is required${RESET}"
                return 1
            fi
            
            echo -e "${YELLOW}Notes with tag '$tag':${RESET}"
            echo
            
            local found=0
            for note_file in "$NOTES_DIR"/*; do
                if [ -f "$note_file" ]; then
                    # Look for tag in Tags section
                    if grep -q "^# Tags:.*\b$tag\b" "$note_file"; then
                        local note_title=$(basename "$note_file")
                        local tags=$(grep "^# Tags:" "$note_file" | sed 's/^# Tags: //')
                        
                        # Show note title and preview
                        echo -e "${GREEN}$note_title${RESET} - ${YELLOW}[${tags}]${RESET}"
                        
                        # Extract first line of content for preview
                        local preview=$(sed -n '/^[^#]/p' "$note_file" | head -n 1 | cut -c 1-50)
                        if [ ${#preview} -eq 50 ]; then
                            preview="${preview}..."
                        fi
                        
                        echo -e "  ${CYAN}${preview}${RESET}"
                        echo
                        
                        found=1
                    fi
                fi
            done
            
            if [ "$found" -eq 0 ]; then
                echo -e "${CYAN}No notes found with tag '$tag'${RESET}"
            else
                echo -e "${YELLOW}View any of these notes? [y/N]${RESET}"
                read -r view_note
                
                if [[ "$view_note" =~ ^[yY]$ ]]; then
                    echo -e "${YELLOW}Enter note title:${RESET}"
                    read -r selected_note
                    
                    if [ -n "$selected_note" ]; then
                        note view "$selected_note"
                    fi
                fi
            fi
            ;;
            
        *)
            echo -e "${RED}Unknown command: $cmd${RESET}"
            echo -e "${YELLOW}Usage:${RESET} note [list|add|view|edit|delete|search|export|tag|bytag] [args]"
            return 1
            ;;
    esac
}

# ===========================================
# Module Health Check & Auto-run Functions
# ===========================================

# Function to check the health of this module
function _productivity_tools_sh_health_check() {
    local health_status=0
    
    # Check if required directories can be created
    _init_productivity_dirs || health_status=1
    
    # Check if timer history file is accessible
    if [ -f "$TIMER_HISTORY" ]; then
        if ! grep -q "start_time\|end_time" "$TIMER_HISTORY" 2>/dev/null; then
            echo -e "${YELLOW}Warning: Timer history file may be corrupted${RESET}"
            echo -e "${CYAN}Consider running: echo 'start_time|end_time|category|task|duration|seconds' > '$TIMER_HISTORY'${RESET}"
            health_status=1
        fi
    else
        echo -e "${YELLOW}Warning: Timer history file not found${RESET}"
    fi
    
    # Check if backup directory is writable
    if [ ! -w "$PRODUCTIVITY_BACKUP_DIR" ] && [ -d "$PRODUCTIVITY_BACKUP_DIR" ]; then
        echo -e "${YELLOW}Warning: Backup directory is not writable: $PRODUCTIVITY_BACKUP_DIR${RESET}"
        health_status=1
    fi
    
    # Check if any project file is corrupted
    if [ -d "$PROJECT_DIR" ]; then
        for project_file in "$PROJECT_DIR"/*; do
            if [ -f "$project_file" ]; then
                if ! grep -q "^# Project:" "$project_file"; then
                    echo -e "${YELLOW}Warning: Project file may be corrupted: $(basename "$project_file")${RESET}"
                    health_status=1
                fi
            fi
        done
    fi
    
    # Check for running timer
    if [ -f "$TIMER_FILE" ]; then
        local start_data=$(cat "$TIMER_FILE")
        local start_time=$(echo "$start_data" | cut -d' ' -f1)
        local task_name=$(echo "$start_data" | cut -d' ' -f2-)
        
        # Check if timer file is valid
        if [ -z "$start_time" ] || ! [[ "$start_time" =~ ^[0-9]+$ ]]; then
            echo -e "${YELLOW}Warning: Timer file appears to be corrupted${RESET}"
            health_status=1
        else
            local current_time=$(date +%s)
            local duration=$((current_time - start_time))
            
            # Check for suspiciously long running timer (> 12 hours)
            if [ $duration -gt 43200 ]; then
                echo -e "${YELLOW}Warning: Timer has been running for over 12 hours${RESET}"
                echo -e "${CYAN}Current task: $task_name${RESET}"
                echo -e "${CYAN}Consider stopping with 'timer stop'${RESET}"
            fi
        fi
    fi
    
    return $health_status
}

# Run the health check if this is not being sourced by module loader
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _productivity_tools_sh_health_check
fi

# Output module load message if verbose
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}Loaded: ${BOLD}Productivity Tools Module${RESET} (v1.2)"
fi
