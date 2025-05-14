#!/bin/bash
# ===========================================
# Custom Utilities & General Functions
# ===========================================
# Miscellaneous utilities for everyday use in Termux environment
# Author: Claude & Me
# Version: 1.0
# Last Updated: 2025-05-14

# ===========================================
# Calculator & Conversion Functions
# ===========================================

# Simple calculator
function calc() {
    local result
    
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: calc <expression>${RESET}"
        echo "Example: calc 2+2"
        echo "         calc '(5+3)*2'"
        echo "         calc 'sqrt(16)'"
        return 1
    fi
    
    if command -v bc &> /dev/null; then
        result=$(echo "scale=10; $*" | bc -l | sed 's/\.0\+$//;s/\.\([0-9]*[1-9]\)0\+$/.\1/')
        printf "= %s\n" "$result"
    elif command -v python3 &> /dev/null; then
        # Fallback to Python if bc is not available
        result=$(python3 -c "from math import *; print($*)")
        printf "= %s\n" "$result"
    else
        echo -e "${RED}Error: Neither bc nor python3 is available${RESET}"
        return 1
    fi
}

# Unit conversion function
function convert() {
    if [ $# -lt 3 ]; then
        echo -e "${YELLOW}Usage: convert <value> <from_unit> <to_unit>${RESET}"
        echo "Examples:"
        echo "  convert 100 kg lb     # Weight conversion"
        echo "  convert 1 km mi       # Distance conversion"
        echo "  convert 30 c f        # Temperature conversion"
        echo "  convert 1 gal l       # Volume conversion"
        echo "  convert 10 usd eur    # Currency conversion"
        return 1
    fi
    
    local value="$1"
    local from_unit=$(echo "$2" | tr '[:upper:]' '[:lower:]')
    local to_unit=$(echo "$3" | tr '[:upper:]' '[:lower:]')
    
    # Check for valid numeric value
    if ! [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        echo -e "${RED}Error: Value must be a number${RESET}"
        return 1
    fi
    
    # Perform conversion based on unit types
    case "$from_unit-$to_unit" in
        # Temperature conversions
        c-f) 
            local result=$(echo "scale=2; ($value * 9/5) + 32" | bc)
            echo "$value °C = $result °F"
            ;;
        f-c) 
            local result=$(echo "scale=2; ($value - 32) * 5/9" | bc)
            echo "$value °F = $result °C"
            ;;
        c-k) 
            local result=$(echo "scale=2; $value + 273.15" | bc)
            echo "$value °C = $result K"
            ;;
        k-c) 
            local result=$(echo "scale=2; $value - 273.15" | bc)
            echo "$value K = $result °C"
            ;;
        f-k) 
            local result=$(echo "scale=2; ($value - 32) * 5/9 + 273.15" | bc)
            echo "$value °F = $result K"
            ;;
        k-f) 
            local result=$(echo "scale=2; ($value - 273.15) * 9/5 + 32" | bc)
            echo "$value K = $result °F"
            ;;
            
        # Length conversions
        km-mi) 
            local result=$(echo "scale=4; $value * 0.621371" | bc)
            echo "$value km = $result mi"
            ;;
        mi-km) 
            local result=$(echo "scale=4; $value * 1.60934" | bc)
            echo "$value mi = $result km"
            ;;
        m-ft) 
            local result=$(echo "scale=4; $value * 3.28084" | bc)
            echo "$value m = $result ft"
            ;;
        ft-m) 
            local result=$(echo "scale=4; $value * 0.3048" | bc)
            echo "$value ft = $result m"
            ;;
        cm-in) 
            local result=$(echo "scale=4; $value * 0.393701" | bc)
            echo "$value cm = $result in"
            ;;
        in-cm) 
            local result=$(echo "scale=4; $value * 2.54" | bc)
            echo "$value in = $result cm"
            ;;
            
        # Weight conversions
        kg-lb) 
            local result=$(echo "scale=4; $value * 2.20462" | bc)
            echo "$value kg = $result lb"
            ;;
        lb-kg) 
            local result=$(echo "scale=4; $value * 0.453592" | bc)
            echo "$value lb = $result kg"
            ;;
        g-oz) 
            local result=$(echo "scale=4; $value * 0.035274" | bc)
            echo "$value g = $result oz"
            ;;
        oz-g) 
            local result=$(echo "scale=4; $value * 28.3495" | bc)
            echo "$value oz = $result g"
            ;;
            
        # Volume conversions
        l-gal) 
            local result=$(echo "scale=4; $value * 0.264172" | bc)
            echo "$value L = $result gal (US)"
            ;;
        gal-l) 
            local result=$(echo "scale=4; $value * 3.78541" | bc)
            echo "$value gal (US) = $result L"
            ;;
        ml-floz) 
            local result=$(echo "scale=4; $value * 0.033814" | bc)
            echo "$value mL = $result fl oz (US)"
            ;;
        floz-ml) 
            local result=$(echo "scale=4; $value * 29.5735" | bc)
            echo "$value fl oz (US) = $result mL"
            ;;
            
        # Area conversions
        m2-ft2|m²-ft²) 
            local result=$(echo "scale=4; $value * 10.7639" | bc)
            echo "$value m² = $result ft²"
            ;;
        ft2-m2|ft²-m²) 
            local result=$(echo "scale=4; $value * 0.092903" | bc)
            echo "$value ft² = $result m²"
            ;;
        ha-acre) 
            local result=$(echo "scale=4; $value * 2.47105" | bc)
            echo "$value ha = $result acres"
            ;;
        acre-ha) 
            local result=$(echo "scale=4; $value * 0.404686" | bc)
            echo "$value acres = $result ha"
            ;;
            
        # Speed conversions
        kph-mph|kmh-mph) 
            local result=$(echo "scale=4; $value * 0.621371" | bc)
            echo "$value km/h = $result mph"
            ;;
        mph-kph|mph-kmh) 
            local result=$(echo "scale=4; $value * 1.60934" | bc)
            echo "$value mph = $result km/h"
            ;;
        ms-mph|m/s-mph) 
            local result=$(echo "scale=4; $value * 2.23694" | bc)
            echo "$value m/s = $result mph"
            ;;
        mph-ms|mph-m/s) 
            local result=$(echo "scale=4; $value * 0.44704" | bc)
            echo "$value mph = $result m/s"
            ;;
            
        # Digital storage conversions
        mb-kb|MB-KB) 
            local result=$(echo "scale=0; $value * 1024" | bc)
            echo "$value MB = $result KB"
            ;;
        gb-mb|GB-MB) 
            local result=$(echo "scale=0; $value * 1024" | bc)
            echo "$value GB = $result MB"
            ;;
        tb-gb|TB-GB) 
            local result=$(echo "scale=0; $value * 1024" | bc)
            echo "$value TB = $result GB"
            ;;
        kb-mb|KB-MB) 
            local result=$(echo "scale=4; $value / 1024" | bc)
            echo "$value KB = $result MB"
            ;;
        mb-gb|MB-GB) 
            local result=$(echo "scale=4; $value / 1024" | bc)
            echo "$value MB = $result GB"
            ;;
        gb-tb|GB-TB) 
            local result=$(echo "scale=4; $value / 1024" | bc)
            echo "$value GB = $result TB"
            ;;
            
        # Time conversions
        min-sec) 
            local result=$(echo "scale=0; $value * 60" | bc)
            echo "$value min = $result sec"
            ;;
        hr-min|h-min) 
            local result=$(echo "scale=0; $value * 60" | bc)
            echo "$value hr = $result min"
            ;;
        day-hr) 
            local result=$(echo "scale=0; $value * 24" | bc)
            echo "$value days = $result hr"
            ;;
        week-day) 
            local result=$(echo "scale=0; $value * 7" | bc)
            echo "$value weeks = $result days"
            ;;
        sec-min) 
            local result=$(echo "scale=2; $value / 60" | bc)
            echo "$value sec = $result min"
            ;;
        min-hr) 
            local result=$(echo "scale=2; $value / 60" | bc)
            echo "$value min = $result hr"
            ;;
        hr-day|h-day) 
            local result=$(echo "scale=2; $value / 24" | bc)
            echo "$value hr = $result days"
            ;;
            
        # Currency conversion requires online service
        usd-*|eur-*|gbp-*|jpy-*|cny-*|inr-*|*-usd|*-eur|*-gbp|*-jpy|*-cny|*-inr)
            if command -v curl &> /dev/null; then
                echo -e "${YELLOW}Fetching current exchange rate...${RESET}"
                local api_response=$(curl -s "https://api.exchangerate-api.com/v4/latest/${from_unit^^}")
                
                if echo "$api_response" | grep -q "error"; then
                    echo -e "${RED}Error: Invalid currency code or service unavailable${RESET}"
                    return 1
                fi
                
                local rate=$(echo "$api_response" | grep -o "\"${to_unit^^}\":[0-9.]*" | cut -d':' -f2)
                
                if [ -z "$rate" ]; then
                    echo -e "${RED}Error: Could not retrieve exchange rate for ${to_unit^^}${RESET}"
                    return 1
                fi
                
                local result=$(echo "scale=4; $value * $rate" | bc)
                echo "$value ${from_unit^^} = $result ${to_unit^^}"
            else
                echo -e "${RED}Error: curl is required for currency conversion${RESET}"
                return 1
            fi
            ;;
            
        *)
            echo -e "${RED}Error: Unsupported conversion: $from_unit to $to_unit${RESET}"
            return 1
            ;;
    esac
}

# Secure password generator
function genpass() {
    local length=${1:-16}
    local include_symbols=${2:-y}
    
    if ! [[ "$length" =~ ^[0-9]+$ ]] || [ "$length" -lt 8 ]; then
        echo -e "${RED}Error: Length must be a number greater than or equal to 8${RESET}"
        return 1
    fi
    
    echo -e "${YELLOW}Generating secure password of length $length...${RESET}"
    
    # Define character sets
    local chars_alpha="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local chars_num="0123456789"
    local chars_special="!@#$%^&*()-_=+[]{}|;:,.<>?"
    
    local charset="$chars_alpha$chars_num"
    if [[ "$include_symbols" =~ ^[yY]$ ]]; then
        charset="$charset$chars_special"
    fi
    
    # Generate password
    local password=""
    if command -v openssl &> /dev/null; then
        password=$(openssl rand -base64 $((length * 2)) | tr -dc "$charset" | head -c "$length")
    else
        # Fallback method if openssl is not available
        for i in $(seq 1 "$length"); do
            local rand_idx=$((RANDOM % ${#charset}))
            password="${password}${charset:$rand_idx:1}"
        done
    fi
    
    # Check password strength
    local strength="weak"
    local score=0
    
    # Score based on length
    if [ ${#password} -ge 12 ]; then
        score=$((score + 2))
    elif [ ${#password} -ge 10 ]; then
        score=$((score + 1))
    fi
    
    # Score based on character types
    if echo "$password" | grep -q '[a-z]'; then
        score=$((score + 1))
    fi
    
    if echo "$password" | grep -q '[A-Z]'; then
        score=$((score + 1))
    fi
    
    if echo "$password" | grep -q '[0-9]'; then
        score=$((score + 1))
    fi
    
    if echo "$password" | grep -q '[^a-zA-Z0-9]'; then
        score=$((score + 2))
    fi
    
    # Determine strength
    if [ $score -ge 6 ]; then
        strength="strong"
    elif [ $score -ge 4 ]; then
        strength="medium"
    fi
    
    # Display password
    echo -e "${GREEN}Generated password: ${BOLD}$password${RESET}"
    echo -e "${CYAN}Strength: $strength${RESET}"
    
    # Copy to clipboard if available
    if command -v xclip &> /dev/null; then
        echo -n "$password" | xclip -selection clipboard
        echo -e "${CYAN}(Password copied to clipboard)${RESET}"
    elif command -v pbcopy &> /dev/null; then
        echo -n "$password" | pbcopy
        echo -e "${CYAN}(Password copied to clipboard)${RESET}"
    elif command -v termux-clipboard-set &> /dev/null; then
        echo -n "$password" | termux-clipboard-set
        echo -e "${CYAN}(Password copied to clipboard)${RESET}"
    fi
}

# ===========================================
# Time & Date Functions
# ===========================================

# Function to show current time in different time zones
function worldtime() {
    # Set default time zones if none specified
    local timezones=("America/New_York" "America/Los_Angeles" "Europe/London" "Europe/Berlin" "Asia/Tokyo" "Australia/Sydney")
    
    # Use provided time zones if available
    if [ $# -gt 0 ]; then
        timezones=("$@")
    fi
    
    echo -e "${YELLOW}Current time around the world:${RESET}"
    echo -e "${GREEN}Local time: $(date '+%Y-%m-%d %H:%M:%S %Z')${RESET}"
    echo
    
    for tz in "${timezones[@]}"; do
        if [ -e "/usr/share/zoneinfo/$tz" ] || [ -e "/etc/localtime" ]; then
            local time=$(TZ="$tz" date '+%Y-%m-%d %H:%M:%S %Z')
            echo -e "${CYAN}$tz:${RESET} $time"
        else
            echo -e "${RED}Invalid timezone: $tz${RESET}"
        fi
    done
}

# Countdown timer
function countdown() {
    local seconds=${1:-60}
    
    if ! [[ "$seconds" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Usage: countdown <seconds>${RESET}"
        return 1
    fi
    
    echo -e "${YELLOW}Countdown timer: $seconds seconds${RESET}"
    
    for (( i=seconds; i>=0; i-- )); do
        printf "\r%02d:%02d" $((i/60)) $((i%60))
        sleep 1
    done
    
    printf "\r${GREEN}Countdown finished!${RESET}                 \n"
    
    # Play sound or notification if available
    if command -v beep &> /dev/null; then
        beep
    elif command -v tput &> /dev/null; then
        tput bel
    elif command -v termux-notification &> /dev/null; then
        termux-notification --title "Countdown" --content "Countdown timer completed!"
    fi
}

# Stopwatch function
function stopwatch() {
    local start_time=$(date +%s)
    local running=1
    
    echo -e "${YELLOW}Stopwatch started. Press Ctrl+C to stop.${RESET}"
    
    # Trap Ctrl+C to stop stopwatch gracefully
    trap 'running=0' INT
    
    while [ $running -eq 1 ]; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local hours=$((elapsed / 3600))
        local minutes=$(( (elapsed % 3600) / 60 ))
        local seconds=$((elapsed % 60))
        
        printf "\r%02d:%02d:%02d" $hours $minutes $seconds
        sleep 1
    done
    
    # Reset trap and newline
    trap - INT
    echo
    
    echo -e "${GREEN}Stopwatch stopped.${RESET}"
    printf "Total time: %02d:%02d:%02d\n" $hours $minutes $seconds
}

# Calendar function with enhanced display
function cal() {
    local month=${1:-$(date +%m)}
    local year=${2:-$(date +%Y)}
    
    # Call the system cal with colors and highlight current day
    if command -v ncal &> /dev/null; then
        # Use ncal if available (better highlighting)
        ncal -m "$month" "$year" -h
    else
        # Fall back to regular cal with grep for highlighting
        command cal -m "$month" "$year" | grep --color=always -E "^|$(date +%e)|$"
    fi
}

# Function to display a perpetual calendar
function pcal() {
    local year=${1:-$(date +%Y)}
    
    if ! [[ "$year" =~ ^[0-9]{4}$ ]]; then
        echo -e "${RED}Usage: pcal <year>${RESET}"
        echo "Example: pcal 2025"
        return 1
    fi
    
    echo -e "${GREEN}Calendar for year $year${RESET}"
    
    # Display calendar for each month
    for month in {1..12}; do
        echo
        echo -e "${CYAN}$(date -d "$year-$month-01" '+%B %Y')${RESET}"
        cal "$month" "$year"
    done
}

# ===========================================
# System Information & Utilities
# ===========================================

# IP lookup function
function iplookup() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: iplookup <ip_address>${RESET}"
        return 1
    fi
    
    echo -e "${YELLOW}Looking up information for IP: $1${RESET}"
    curl -s "https://ipinfo.io/$1/json" | python3 -m json.tool || echo -e "${RED}Failed to retrieve IP information${RESET}"
}

# Enhanced df command with focus on relevant filesystems
function diskspace() {
    echo -e "${YELLOW}Disk space usage:${RESET}"
    
    # Get disk usage with human-readable sizes, sorted by usage
    df -h | grep -v "tmpfs" | grep -v "udev" | sort -r -k 5
}

# Memory usage monitoring
function meminfo() {
    echo -e "${YELLOW}Memory usage information:${RESET}"
    
    # Display memory info from free
    free -h
    
    # Show top memory consumers
    echo
    echo -e "${CYAN}Top memory consumers:${RESET}"
    ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head -n 11
}

# Show help with common commands
function help() {
    echo -e "${GREEN}====== Termux Ubuntu Bash Quick Reference ======${RESET}"
    
    echo -e "${CYAN}NAVIGATION BETWEEN ROOT AND SDCARD${RESET}"
    echo "sdcard               : Quick access to shared storage"
    echo "home                 : Return to root home directory"
    echo "scd <folder>         : Navigate to folder in shared storage"
    echo "sls [folder]         : List contents of shared storage"
    echo "where                : Show current path relative to sdcard"
    
    echo -e "${CYAN}PROJECT NAVIGATION${RESET}"
    echo "p                    : List all projects"
    echo "p <project-name>     : Navigate to project"
    
    echo -e "${CYAN}FILE OPERATIONS${RESET}"
    echo "extract <file>        : Extract archives"
    echo "compress <out> <in>   : Create compressed archive"
    echo "backup <file/dir>     : Create a backup with timestamp"
    echo "fcompare <f1> <f2>    : Compare two files with highlighting"
    echo "fdelete <pattern>     : Find and delete files matching pattern"
    
    echo -e "${CYAN}GIT & GITHUB${RESET}"
    echo "gs, ga, gc, gp, gl    : Basic git commands"
    echo "glg [n]               : Show git log graph"
    echo "gclone <user/repo>    : Clone GitHub repository"
    echo "gupdate               : Update repository intelligently"
    
    echo -e "${CYAN}PRODUCTIVITY${RESET}"
    echo "ts <task>             : Start timing a task"
    echo "te                    : Stop current timer"
    echo "tt                    : Show current timer status"
    echo "tr [days]             : Show timer report for last n days"
    echo "note add <title>      : Add a quick note"
    echo "project list          : List all projects"
    
    echo -e "${CYAN}PYTHON & DEVELOPMENT${RESET}"
    echo "a                     : Activate virtual environment"
    echo "d                     : Deactivate virtual environment"
    echo "py                    : Run Python"
    echo "pipi <package>        : Install Python package"
    echo "pyproject <n>      : Create new Python project structure"
    
    echo -e "${CYAN}UTILITIES${RESET}"
    echo "calc <expr>           : Calculator"
    echo "convert <val> <u> <u> : Unit conversion"
    echo "weather [location]    : Show weather forecast"
    echo "genpass [length]      : Generate secure password"
    echo "countdown <seconds>   : Countdown timer"
    echo "worldtime             : Show time around the world"
    
    echo -e "${CYAN}SYSTEM${RESET}"
    echo "sm, smf               : System monitor (basic/full)"
    echo "update                : Interactive system update"
    echo "myip                  : Show public and local IP address"
    echo "cleanup               : Free up disk space"
    
    echo -e "${CYAN}NETWORK${RESET}"
    echo "ping_host <host>      : Ping with statistics"
    echo "port_check <h> <p>    : Check if port is open"
    echo "dl <url> [file]       : Download file with progress"
    echo "serve [port] [dir]    : Start HTTP server"
}

# Welcome message with system info and tips
function welcome() {
    # Clear screen for cleaner display
    clear
    
    # Get system information
    local kernel=$(uname -r)
    local hostname=$(hostname)
    local uptime=$(uptime -p)
    local memory=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
    local disk=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')
    local cpu_temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "%.1f°C", $1/1000}' 2>/dev/null || echo "N/A")
    
    # Get IP address
    local ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "N/A")
    
    # Terminal width for drawing box
    local width=$(tput cols)
    local box_width=$((width > 80 ? 80 : width))
    
    # Draw top border
    printf "${GREEN}╔"
    printf '═%.0s' $(seq 1 $((box_width - 2)))
    printf "╗${RESET}\n"
    
    # Print header
    printf "${GREEN}║${RESET}${BOLD_CYAN} %-$((box_width - 4))s ${GREEN}║${RESET}\n" "Welcome to Ubuntu proot-distro in Termux"
    
    # Draw separator
    printf "${GREEN}╠"
    printf '═%.0s' $(seq 1 $((box_width - 2)))
    printf "╣${RESET}\n"
    
    # System info
    printf "${GREEN}║${RESET} %-$((box_width - 3))s${GREEN}║${RESET}\n" "$(date)"
    printf "${GREEN}║${RESET} %-$((box_width - 3))s${GREEN}║${RESET}\n" "System: $(uname -srm)"
    printf "${GREEN}║${RESET} %-$((box_width - 3))s${GREEN}║${RESET}\n" "Uptime: $uptime"
    printf "${GREEN}║${RESET} %-$((box_width - 3))s${GREEN}║${RESET}\n" "Memory: $memory"
    printf "${GREEN}║${RESET} %-$((box_width - 3))s${GREEN}║${RESET}\n" "Disk: $disk"
    
    if [ "$ip_addr" != "N/A" ]; then
        printf "${GREEN}║${RESET} %-$((box_width - 3))s${GREEN}║${RESET}\n" "IP Address: $ip_addr"
    fi
    
    # Draw separator
    printf "${GREEN}╠"
    printf '═%.0s' $(seq 1 $((box_width - 2)))
    printf "╣${RESET}\n"
    
    # Quick commands
    printf "${GREEN}║${RESET}${YELLOW} %-$((box_width - 4))s ${GREEN}║${RESET}\n" "Quick commands:"
    printf "${GREEN}║${RESET} %-$((box_width - 3))s${GREEN}║${RESET}\n" "sdcard       - Jump to shared storage"
    printf "${GREEN}║${RESET} %-$((box_width - 3))s${GREEN}║${RESET}\n" "home         - Return to root home directory"
    printf "${GREEN}║${RESET} %-$((box_width - 3))s${GREEN}║${RESET}\n" "p <project>  - Navigate to project"
    printf "${GREEN}║${RESET} %-$((box_width - 3))s${GREEN}║${RESET}\n" "help         - Show all available commands"
    
    # Shared storage info
    local sdcard_available=0
    if [ -d "/sdcard" ] || [ -d "../sdcard" ]; then
        sdcard_available=1
    fi
    
    if [ "$sdcard_available" -eq 1 ]; then
        printf "${GREEN}║${RESET} %-$((box_width - 3))s${GREEN}║${RESET}\n" "Shared storage is accessible with 'sdcard'"
    else
        printf "${GREEN}║${RESET} %-$((box_width - 3))s${GREEN}║${RESET}\n" "Shared storage not found"
    fi
    
    # Draw bottom border
    printf "${GREEN}╚"
    printf '═%.0s' $(seq 1 $((box_width - 2)))
    printf "╝${RESET}\n"
    
    # Show pending system updates if any
    if command -v apt-get &> /dev/null; then
        if [ -x "$(command -v apt-get)" ]; then
            local updates=$(apt-get -s upgrade | grep -P '^\d+ upgraded' | cut -d" " -f1)
            if [ "$updates" -gt 0 ]; then
                echo -e "${YELLOW}$updates package updates available. Run 'update' to install.${RESET}"
                echo
            fi
        fi
    fi
}

# Output module load message if verbose
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}Loaded: ${BOLD}Custom Utilities Module${RESET}"
fi
