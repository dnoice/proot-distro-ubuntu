#!/bin/bash
# ===========================================
# System Management & Monitoring
# ===========================================
# Tools for system monitoring, package management, and resource tracking
# Author: Claude & Me
# Version: 1.0
# Last Updated: 2025-05-14

# ===========================================
# Package Management Aliases
# ===========================================

# System updates with more aliases and safety checks
alias au="apt update"
alias aug="apt update && apt upgrade -y"
alias ai="apt install"
alias arm="apt remove"
alias aar="apt autoremove"
alias aac="apt autoclean"
alias aps="apt search"
alias ash="apt show"
alias ali="apt list --installed"
alias purge="apt autoremove && apt autoclean"

# Safe apt update and upgrade
function update() {
    echo -e "${YELLOW}Updating package lists...${RESET}"
    apt update
    
    echo
    if apt list --upgradable | grep -q -v "Listing"; then
        echo -e "${YELLOW}The following packages can be upgraded:${RESET}"
        apt list --upgradable
        
        echo
        echo -e "${YELLOW}Do you want to upgrade these packages? [y/N]${RESET}"
        read -r confirm
        if [[ "$confirm" =~ ^[yY]$ ]]; then
            echo -e "${GREEN}Upgrading packages...${RESET}"
            apt upgrade -y
            echo -e "${GREEN}Packages upgraded successfully!${RESET}"
        else
            echo -e "${YELLOW}Package upgrade cancelled.${RESET}"
        fi
    else
        echo -e "${GREEN}All packages are up to date.${RESET}"
    fi
}

# Install common packages
function install_essentials() {
    echo -e "${YELLOW}Installing essential packages...${RESET}"
    
    # Define package groups
    local base_packages="git curl wget vim nano"
    local dev_packages="build-essential python3 python3-pip python3-venv"
    local utils_packages="tree htop zip unzip"
    
    echo -e "${YELLOW}Select packages to install:${RESET}"
    echo "1. Base packages ($base_packages)"
    echo "2. Development packages ($dev_packages)"
    echo "3. Utility packages ($utils_packages)"
    echo "4. All of the above"
    echo "5. Custom selection"
    read -p "Enter your choice [1-5]: " choice
    
    local packages_to_install=""
    
    case $choice in
        1)
            packages_to_install="$base_packages"
            ;;
        2)
            packages_to_install="$dev_packages"
            ;;
        3)
            packages_to_install="$utils_packages"
            ;;
        4)
            packages_to_install="$base_packages $dev_packages $utils_packages"
            ;;
        5)
            echo -e "${YELLOW}Enter packages to install (space-separated):${RESET}"
            read -r custom_packages
            packages_to_install="$custom_packages"
            ;;
        *)
            echo -e "${RED}Invalid choice${RESET}"
            return 1
            ;;
    esac
    
    # Update package lists first
    echo -e "${YELLOW}Updating package lists...${RESET}"
    apt update
    
    # Install selected packages
    echo -e "${YELLOW}Installing packages: $packages_to_install${RESET}"
    apt install -y $packages_to_install
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Packages installed successfully!${RESET}"
    else
        echo -e "${RED}Some packages failed to install${RESET}"
        return 1
    fi
}

# Package search function with enhanced output
function pkg() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: pkg <package_name> [install|show|search]${RESET}"
        echo "Examples:"
        echo "  pkg nano                 # Show package info"
        echo "  pkg nano install         # Install package"
        echo "  pkg python search        # Search for packages containing 'python'"
        return 1
    fi
    
    local package="$1"
    local action="${2:-show}"
    
    case $action in
        install)
            echo -e "${YELLOW}Installing package: $package${RESET}"
            apt install -y "$package"
            ;;
        show)
            echo -e "${YELLOW}Package information for: $package${RESET}"
            apt show "$package"
            
            # Check if package is installed
            if dpkg -l "$package" &>/dev/null; then
                echo -e "${GREEN}Package is installed.${RESET}"
                echo -e "${YELLOW}Installed files:${RESET}"
                dpkg -L "$package" | head -n 10
                echo -e "${YELLOW}(showing 10 of $(dpkg -L "$package" | wc -l) files)${RESET}"
            else
                echo -e "${RED}Package is not installed.${RESET}"
            fi
            ;;
        search)
            echo -e "${YELLOW}Searching for packages containing: $package${RESET}"
            apt search "$package"
            ;;
        *)
            echo -e "${RED}Unknown action: $action${RESET}"
            echo -e "${YELLOW}Valid actions: install, show, search${RESET}"
            return 1
            ;;
    esac
}

# Function to clean up system and free disk space
function cleanup() {
    echo -e "${YELLOW}Cleaning up system...${RESET}"
    
    # Clean apt cache
    echo -e "${CYAN}Cleaning APT cache...${RESET}"
    apt clean
    apt autoclean
    
    # Remove old packages
    echo -e "${CYAN}Removing unused packages...${RESET}"
    apt autoremove -y
    
    # Clean journal logs if systemd is available
    if command -v journalctl &> /dev/null; then
        echo -e "${CYAN}Cleaning journal logs...${RESET}"
        journalctl --vacuum-time=7d
    fi
    
    # Clean temp files
    echo -e "${CYAN}Cleaning temp files...${RESET}"
    rm -rf /tmp/*
    
    # Clean user cache
    echo -e "${CYAN}Cleaning user cache...${RESET}"
    rm -rf ~/.cache/thumbnails/*
    
    # Show disk usage after cleanup
    echo -e "${GREEN}Cleanup complete. Current disk usage:${RESET}"
    df -h /
}

# ===========================================
# System Monitoring Functions
# ===========================================

# System information
alias df="df -h"
alias du="du -h"
alias free="free -m"
alias cpu="cat /proc/cpuinfo"
alias mem="cat /proc/meminfo"
alias ports="netstat -tulanp"
alias ping="ping -c 4"
alias path='echo -e ${PATH//:/\\n}'
alias now='date +"%T"'
alias today='date +"%Y-%m-%d"'

# Process management
alias psa="ps aux"
alias psg="ps aux | grep -v grep | grep -i -e VSZ -e"
alias psmem='ps aux | sort -nr -k 4 | head -10'
alias pscpu='ps aux | sort -nr -k 3 | head -10'
alias psof="lsof -p"

# Network utilities
alias myip="curl -s ifconfig.me"
alias localip="hostname -I | awk '{print \$1}'"
alias ips="ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}'"
alias ports="netstat -tulanp"
alias listen="lsof -i -P | grep LISTEN"

# Enhanced system monitor with more details and better formatting
function sysmon() {
    local detail_level=${1:-"basic"}
    echo -e "${GREEN}System Monitoring${RESET}"
    
    # System info
    echo -e "${YELLOW}System Information:${RESET}"
    echo -e "Hostname: $(hostname)"
    echo -e "Kernel: $(uname -r)"
    echo -e "Uptime: $(uptime -p)"
    
    # CPU info
    echo
    echo -e "${YELLOW}CPU Usage:${RESET}"
    if [ "$detail_level" = "full" ]; then
        echo -e "CPU Model: $(grep "model name" /proc/cpuinfo | head -1 | cut -d ":" -f2 | sed 's/^[ \t]*//')"
        echo -e "CPU Cores: $(grep -c "processor" /proc/cpuinfo)"
    fi
    top -b -n 1 | head -n 5
    
    # Memory usage
    echo
    echo -e "${YELLOW}Memory Usage:${RESET}"
    free -h
    
    # Disk usage
    echo
    echo -e "${YELLOW}Disk Usage:${RESET}"
    df -h | grep -E '(/mnt|/sdcard|/$)'
    
    # Top processes - using commands that work in proot
    echo
    echo -e "${YELLOW}Top CPU Processes:${RESET}"
    ps -e -o pid,pcpu,comm --sort=-pcpu | head -n 6
    
    # Top memory processes
    echo
    echo -e "${YELLOW}Top Memory Processes:${RESET}"
    ps -e -o pid,pmem,comm --sort=-pmem | head -n 6
    
    # Network info if detail level is full
    if [ "$detail_level" = "full" ]; then
        echo
        echo -e "${YELLOW}Network Interfaces:${RESET}"
        ip -br addr show
        
        echo
        echo -e "${YELLOW}Listening Ports:${RESET}"
        netstat -tulnp 2>/dev/null || echo "netstat not available"
    fi
}

alias sm="sysmon"
alias smf="sysmon full"

# Function to monitor system continuously
function syswatch() {
    local interval=${1:-5}
    local iterations=${2:-0}  # 0 means run indefinitely
    
    echo -e "${YELLOW}Monitoring system every $interval seconds. Press Ctrl+C to stop.${RESET}"
    
    # Ensure the interval is a positive number
    if ! [[ "$interval" =~ ^[0-9]+$ ]] || [ "$interval" -lt 1 ]; then
        echo -e "${RED}Error: Interval must be a positive integer${RESET}"
        return 1
    fi
    
    # Run indefinitely or for a specific number of iterations
    local count=0
    while [ "$iterations" -eq 0 ] || [ "$count" -lt "$iterations" ]; do
        clear
        echo -e "${GREEN}System Monitor - $(date)${RESET}"
        echo -e "${YELLOW}Refresh interval: ${BOLD}$interval${RESET} seconds"
        
        # CPU usage
        echo
        echo -e "${CYAN}CPU Usage:${RESET}"
        top -b -n 1 | head -n 5
        
        # Memory usage
        echo
        echo -e "${CYAN}Memory Usage:${RESET}"
        free -h
        
        # Load average
        echo
        echo -e "${CYAN}Load Average:${RESET}"
        uptime
        
        # Disk usage
        echo
        echo -e "${CYAN}Disk Usage:${RESET}"
        df -h | grep -E '(/mnt|/sdcard|/$)'
        
        # Top processes
        echo
        echo -e "${CYAN}Top CPU Processes:${RESET}"
        ps -e -o pid,pcpu,comm --sort=-pcpu | head -n 5
        
        # Increment counter
        if [ "$iterations" -ne 0 ]; then
            count=$((count + 1))
            echo
            echo -e "${YELLOW}Iteration ${BOLD}$count${RESET}/${BOLD}$iterations${RESET}"
        fi
        
        # Wait for the next iteration
        sleep "$interval"
    done
}

# Function to check running services
function services() {
    echo -e "${YELLOW}Checking running services...${RESET}"
    
    if command -v systemctl &> /dev/null; then
        echo -e "${CYAN}Using systemctl:${RESET}"
        systemctl list-units --type=service --state=running
    elif command -v service &> /dev/null; then
        echo -e "${CYAN}Using service command:${RESET}"
        service --status-all | grep '\[ + \]'
    else
        echo -e "${CYAN}Using process list:${RESET}"
        echo -e "(Note: This is a fallback method and may not show all services)${RESET}"
        ps -e | grep -E 'sshd|apache|nginx|mysql|postgres|cron'
    fi
}

# Function to check system security
function security_check() {
    echo -e "${YELLOW}Performing basic security check...${RESET}"
    
    # Check listening ports
    echo -e "${CYAN}Listening ports:${RESET}"
    netstat -tulnp 2>/dev/null || echo "netstat not available"
    
    # Check for root processes run by non-root users
    echo
    echo -e "${CYAN}Processes with root privileges:${RESET}"
    ps -eo user,pid,args | grep -v grep | grep -E "^root"
    
    # Check for failed login attempts
    if [ -f /var/log/auth.log ]; then
        echo
        echo -e "${CYAN}Recent failed login attempts:${RESET}"
        grep "Failed password" /var/log/auth.log | tail -n 5
    fi
    
    # Check for open SSH sessions
    echo
    echo -e "${CYAN}Current SSH sessions:${RESET}"
    who | grep -i ssh
    
    # Check for unusual SUID binaries
    echo
    echo -e "${CYAN}Unusual SUID binaries:${RESET}"
    find / -perm -4000 -type f -exec ls -la {} \; 2>/dev/null | grep -v -E "/bin/|/sbin/|/usr/bin/|/usr/sbin/"
}

# Output module load message if verbose
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}Loaded: ${BOLD}System Management Module${RESET}"
fi
