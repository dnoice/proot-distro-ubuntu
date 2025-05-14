#!/bin/bash
# ===========================================
# Productivity Tools & Task Management
# ===========================================
# Task timer, project management, and productivity utilities
# Author: Claude & Me
# Version: 1.0
# Last Updated: 2025-05-14

# ===========================================
# Task Timer Implementation
# ===========================================

# Initialize timer files
TIMER_FILE="${HOME}/.timer"
TIMER_HISTORY="${HOME}/.timer_history"

# Function to manage task timing
function timer() {
    local cmd="$1"
    local args="${@:2}"
    
    if [ -z "$cmd" ]; then
        echo -e "${GREEN}Task Timer${RESET}"
        echo -e "${YELLOW}Usage:${RESET} timer [start|stop|status|history|report] [task-name]"
        echo
        echo -e "${CYAN}Commands:${RESET}"
        echo "  start <task-name>  : Start timing a task"
        echo "  stop               : Stop current timer"
        echo "  status             : Show current timer status"
        echo "  history [n]        : Show last n tasks (default: 10)"
        echo "  report [days]      : Show summary report for last n days (default: 7)"
        echo "  list [category]    : List tasks by category (if specified)"
        echo "  categories         : Show all used categories"
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
            tail -n "$count" "$TIMER_HISTORY" | while IFS='|' read -r start_time end_time category task duration _; do
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
            
            while IFS='|' read -r start_time end_time category task duration seconds; do
                # Skip header or invalid lines
                if [[ ! "$start_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
                    continue
                fi
                
                # Convert start_time to seconds since epoch
                local start_seconds=$(date -d "$start_time" +%s)
                
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
            done < "$TIMER_HISTORY"
            
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
            
            while IFS='|' read -r start_time _ _ _ _ seconds; do
                # Skip header or invalid lines
                if [[ ! "$start_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
                    continue
                fi
                
                # Extract date part
                local date_part=$(echo "$start_time" | cut -d' ' -f1)
                
                # Convert to seconds since epoch for comparison
                local date_epoch=$(date -d "$date_part" +%s)
                
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
            done < "$TIMER_HISTORY"
            
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
                local dayname=$(date -d "${dates[$i]}" +"%a")
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
            
            while IFS='|' read -r _ _ category task _ _; do
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
            done < "$TIMER_HISTORY"
            
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
            
            while IFS='|' read -r _ _ category _ _ _; do
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
            done < "$TIMER_HISTORY"
            
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
            
        *)
            echo -e "${RED}Unknown command: $cmd${RESET}"
            echo -e "${YELLOW}Usage:${RESET} timer [start|stop|status|history|report|list|categories] [args]"
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
    
    # Initialize project directory
    local project_dir="$HOME/.projects"
    if [ ! -d "$project_dir" ]; then
        mkdir -p "$project_dir"
    fi
    
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
        return 0
    fi
    
    case "$cmd" in
        list)
            echo -e "${YELLOW}Available projects:${RESET}"
            
            # Check if any projects exist
            if [ ! "$(ls -A "$project_dir" 2>/dev/null)" ]; then
                echo -e "${CYAN}No projects found. Create one with 'project create <name>'${RESET}"
                return 0
            fi
            
            # List projects with task counts and completion status
            for project_file in "$project_dir"/*; do
                if [ -f "$project_file" ]; then
                    local project_name=$(basename "$project_file")
                    local total_tasks=$(grep -c "^\[" "$project_file")
                    local completed_tasks=$(grep -c "^\[x\]" "$project_file")
                    local completion_percentage=0
                    
                    if [ "$total_tasks" -gt 0 ]; then
                        completion_percentage=$(( (completed_tasks * 100) / total_tasks ))
                    fi
                    
                    echo -e "${GREEN}$project_name${RESET} - $completed_tasks/$total_tasks tasks completed ($completion_percentage%)"
                fi
            done
            ;;
            
        create)
            local project_name="$1"
            
            if [ -z "$project_name" ]; then
                echo -e "${RED}Error: Project name is required${RESET}"
                return 1
            fi
            
            if [ -f "$project_dir/$project_name" ]; then
                echo -e "${RED}Error: Project '$project_name' already exists${RESET}"
                return 1
            fi
            
            echo "# Project: $project_name" > "$project_dir/$project_name"
            echo "# Created: $(date)" >> "$project_dir/$project_name"
            echo "" >> "$project_dir/$project_name"
            
            echo -e "${GREEN}Project '$project_name' created successfully${RESET}"
            ;;
            
        view)
            local project_name="$1"
            
            if [ -z "$project_name" ]; then
                echo -e "${RED}Error: Project name is required${RESET}"
                return 1
            fi
            
            if [ ! -f "$project_dir/$project_name" ]; then
                echo -e "${RED}Error: Project '$project_name' not found${RESET}"
                return 1
            fi
            
            echo -e "${YELLOW}Project: $project_name${RESET}"
            echo
            
            # Calculate task statistics
            local total_tasks=$(grep -c "^\[" "$project_dir/$project_name")
            local completed_tasks=$(grep -c "^\[x\]" "$project_dir/$project_name")
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
            done < "$project_dir/$project_name"
            
            if [ "$task_id" -eq 0 ]; then
                echo -e "${CYAN}No tasks found. Add tasks with 'project add $project_name <task>'${RESET}"
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
            
            if [ ! -f "$project_dir/$project_name" ]; then
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
            echo "$task_line" >> "$project_dir/$project_name"
            
            echo -e "${GREEN}Task added to project '$project_name'${RESET}"
            ;;
            
        done)
            local project_name="$1"
            local task_id="$2"
            
            if [ -z "$project_name" ] || [ -z "$task_id" ]; then
                echo -e "${RED}Error: Project name and task ID are required${RESET}"
                return 1
            fi
            
            if [ ! -f "$project_dir/$project_name" ]; then
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
            
            while IFS= read -r line; do
                if [[ "$line" == \[*\]* && ! "$line" == \#* ]]; then
                    task_count=$((task_count + 1))
                    
                    if [ "$task_count" -eq "$task_id" ]; then
                        # Replace [] with [x] to mark as completed
                        echo "${line/\[\]/\[x\]}" >> "$temp_file"
                        task_found=1
                    else
                        echo "$line" >> "$temp_file"
                    fi
                else
                    echo "$line" >> "$temp_file"
                fi
            done < "$project_dir/$project_name"
            
            if [ "$task_found" -eq 0 ]; then
                echo -e "${RED}Error: Task ID $task_id not found in project '$project_name'${RESET}"
                rm "$temp_file"
                return 1
            fi
            
            # Replace original file with modified one
            mv "$temp_file" "$project_dir/$project_name"
            
            echo -e "${GREEN}Task $task_id marked as completed in project '$project_name'${RESET}"
            ;;
            
        delete)
            local project_name="$1"
            
            if [ -z "$project_name" ]; then
                echo -e "${RED}Error: Project name is required${RESET}"
                return 1
            fi
            
            if [ ! -f "$project_dir/$project_name" ]; then
                echo -e "${RED}Error: Project '$project_name' not found${RESET}"
                return 1
            fi
            
            echo -e "${YELLOW}Are you sure you want to delete project '$project_name'? [y/N]${RESET}"
            read -r confirm
            
            if [[ "$confirm" =~ ^[yY]$ ]]; then
                rm "$project_dir/$project_name"
                echo -e "${GREEN}Project '$project_name' deleted successfully${RESET}"
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
            
            if [ ! -f "$project_dir/$old_name" ]; then
                echo -e "${RED}Error: Project '$old_name' not found${RESET}"
                return 1
            fi
            
            if [ -f "$project_dir/$new_name" ]; then
                echo -e "${RED}Error: Project '$new_name' already exists${RESET}"
                return 1
            fi
            
            mv "$project_dir/$old_name" "$project_dir/$new_name"
            
            # Update project header in file
            sed -i "s/# Project: $old_name/# Project: $new_name/" "$project_dir/$new_name"
            
            echo -e "${GREEN}Project renamed from '$old_name' to '$new_name'${RESET}"
            ;;
            
        *)
            echo -e "${RED}Unknown command: $cmd${RESET}"
            echo -e "${YELLOW}Usage:${RESET} project [list|create|view|add|done|delete|rename] [args]"
            return 1
            ;;
    esac
}

# ===========================================
# Notes and Quick Reminders
# ===========================================

# Function to manage quick notes
function note() {
    local cmd="$1"
    shift
    
    # Initialize notes directory
    local notes_dir="$HOME/.notes"
    if [ ! -d "$notes_dir" ]; then
        mkdir -p "$notes_dir"
    fi
    
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
        return 0
    fi
    
    case "$cmd" in
        list)
            echo -e "${YELLOW}Quick Notes:${RESET}"
            
            if [ ! "$(ls -A "$notes_dir" 2>/dev/null)" ]; then
                echo -e "${CYAN}No notes found. Create one with 'note add <title> <text>'${RESET}"
                return 0
            fi
            
            for note_file in "$notes_dir"/*; do
                if [ -f "$note_file" ]; then
                    local note_title=$(basename "$note_file")
                    local note_date=$(stat -c %y "$note_file" | cut -d' ' -f1)
                    echo -e "${GREEN}$note_title${RESET} - Created: $note_date"
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
            
            # Save note with title and timestamp
            echo "# $note_title" > "$notes_dir/$note_title"
            echo "# Created: $(date)" >> "$notes_dir/$note_title"
            echo "" >> "$notes_dir/$note_title"
            echo "$note_text" >> "$notes_dir/$note_title"
            
            echo -e "${GREEN}Note '$note_title' saved successfully${RESET}"
            ;;
            
        view)
            local note_title="$1"
            
            if [ -z "$note_title" ]; then
                echo -e "${RED}Error: Note title is required${RESET}"
                return 1
            fi
            
            if [ ! -f "$notes_dir/$note_title" ]; then
                echo -e "${RED}Error: Note '$note_title' not found${RESET}"
                return 1
            fi
            
            echo -e "${YELLOW}Note: $note_title${RESET}"
            echo
            
            # Display note content
            if command -v bat &> /dev/null; then
                bat --style=plain "$notes_dir/$note_title"
            else
                cat "$notes_dir/$note_title"
            fi
            ;;
            
        edit)
            local note_title="$1"
            
            if [ -z "$note_title" ]; then
                echo -e "${RED}Error: Note title is required${RESET}"
                return 1
            fi
            
            if [ ! -f "$notes_dir/$note_title" ]; then
                echo -e "${RED}Error: Note '$note_title' not found${RESET}"
                return 1
            fi
            
            # Open note in text editor
            if [ -n "$EDITOR" ]; then
                $EDITOR "$notes_dir/$note_title"
            elif command -v nano &> /dev/null; then
                nano "$notes_dir/$note_title"
            elif command -v vim &> /dev/null; then
                vim "$notes_dir/$note_title"
            else
                echo -e "${RED}No text editor found. Set \$EDITOR or install nano/vim${RESET}"
                return 1
            fi
            
            echo -e "${GREEN}Note '$note_title' updated${RESET}"
            ;;
            
        delete)
            local note_title="$1"
            
            if [ -z "$note_title" ]; then
                echo -e "${RED}Error: Note title is required${RESET}"
                return 1
            fi
            
            if [ ! -f "$notes_dir/$note_title" ]; then
                echo -e "${RED}Error: Note '$note_title' not found${RESET}"
                return 1
            fi
            
            echo -e "${YELLOW}Are you sure you want to delete note '$note_title'? [y/N]${RESET}"
            read -r confirm
            
            if [[ "$confirm" =~ ^[yY]$ ]]; then
                rm "$notes_dir/$note_title"
                echo -e "${GREEN}Note '$note_title' deleted successfully${RESET}"
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
            for note_file in "$notes_dir"/*; do
                if [ -f "$note_file" ]; then
                    if grep -q -i "$query" "$note_file"; then
                        local note_title=$(basename "$note_file")
                        echo -e "${GREEN}Found in: $note_title${RESET}"
                        
                        # Show matches with surrounding context
                        grep -i --color=always -A 1 -B 1 "$query" "$note_file" | sed 's/^/  /'
                        echo
                        
                        found=1
                    fi
                fi
            done
            
            if [ "$found" -eq 0 ]; then
                echo -e "${CYAN}No matches found for '$query'${RESET}"
            fi
            ;;
            
        *)
            echo -e "${RED}Unknown command: $cmd${RESET}"
            echo -e "${YELLOW}Usage:${RESET} note [list|add|view|edit|delete|search] [args]"
            return 1
            ;;
    esac
}

# Output module load message if verbose
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}Loaded: ${BOLD}Productivity Tools Module${RESET}"
fi
