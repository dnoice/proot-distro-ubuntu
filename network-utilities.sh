#!/bin/bash
# ===========================================
# Network Utilities & Web Tools
# ===========================================
# Network diagnostics, monitoring, and web-related functions for Termux proot-distro Ubuntu
# Version: 1.2
# Last Updated: 2025-05-14

# ===========================================
# Configuration Options
# ===========================================

# User-configurable options (can be overridden in .bashrc.custom)
NETWORK_TOOLS_TIMEOUT=${NETWORK_TOOLS_TIMEOUT:-10}           # Default timeout in seconds
NETWORK_DOWNLOAD_DIR=${NETWORK_DOWNLOAD_DIR:-"$HOME/downloads"} # Default download directory
NETWORK_SPEEDTEST_SERVER=${NETWORK_SPEEDTEST_SERVER:-""}     # Custom speedtest server (empty for auto)
NETWORK_DEFAULT_PORT_RANGE=${NETWORK_DEFAULT_PORT_RANGE:-"1-1024"} # Default port range for scanning
NETWORK_SAFE_MODE=${NETWORK_SAFE_MODE:-1}                    # Add safety checks (0=off, 1=on)
NETWORK_MAX_PING_COUNT=${NETWORK_MAX_PING_COUNT:-10}         # Maximum ping count
NETWORK_USER_AGENT=${NETWORK_USER_AGENT:-"Mozilla/5.0 (Linux; Android 11; Termux) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Mobile Safari/537.36"}

# ===========================================
# Initialization Functions
# ===========================================

# Initialize required directories
function _init_network_dirs() {
    # Create download directory if it doesn't exist
    if [ ! -d "$NETWORK_DOWNLOAD_DIR" ]; then
        mkdir -p "$NETWORK_DOWNLOAD_DIR"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Failed to create directory: $NETWORK_DOWNLOAD_DIR${RESET}"
            return 1
        fi
    fi
    
    return 0
}

# Check for network connectivity (with timeout)
function _check_internet_connectivity() {
    local timeout=${1:-$NETWORK_TOOLS_TIMEOUT}
    local test_hosts=("google.com" "cloudflare.com" "1.1.1.1")
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 2 "$host" &>/dev/null; then
            return 0  # Successfully pinged one of the hosts
        fi
    done
    
    return 1  # Failed to reach any host
}

# Detect available network tools (Termux specific)
function _detect_network_tools() {
    # Initialize tool availability variables
    HAVE_CURL=0
    HAVE_WGET=0
    HAVE_NMAP=0
    HAVE_DIG=0
    HAVE_WHOIS=0
    HAVE_NETSTAT=0
    HAVE_SS=0
    HAVE_TRACEROUTE=0
    HAVE_HOST=0
    HAVE_IP=0
    HAVE_SPEEDTEST_CLI=0
    HAVE_TERMUX_API=0
    
    # Check for each tool
    command -v curl &>/dev/null && HAVE_CURL=1
    command -v wget &>/dev/null && HAVE_WGET=1
    command -v nmap &>/dev/null && HAVE_NMAP=1
    command -v dig &>/dev/null && HAVE_DIG=1
    command -v whois &>/dev/null && HAVE_WHOIS=1
    command -v netstat &>/dev/null && HAVE_NETSTAT=1
    command -v ss &>/dev/null && HAVE_SS=1
    command -v traceroute &>/dev/null && HAVE_TRACEROUTE=1
    command -v host &>/dev/null && HAVE_HOST=1
    command -v ip &>/dev/null && HAVE_IP=1
    command -v speedtest-cli &>/dev/null && HAVE_SPEEDTEST_CLI=1
    
    # Check for Termux API
    command -v termux-battery-status &>/dev/null && HAVE_TERMUX_API=1
    
    # Report missing critical tools if in verbose mode
    if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
        local missing_tools=()
        
        [ "$HAVE_CURL" -eq 0 ] && [ "$HAVE_WGET" -eq 0 ] && missing_tools+=("curl/wget")
        [ "$HAVE_DIG" -eq 0 ] && [ "$HAVE_HOST" -eq 0 ] && missing_tools+=("dig/host")
        
        if [ ${#missing_tools[@]} -gt 0 ]; then
            echo -e "${YELLOW}Warning: Missing recommended network tools: ${missing_tools[*]}${RESET}"
            echo -e "${CYAN}Install with: pkg install ${missing_tools[*]} in Termux${RESET}"
        fi
    fi
}

# Initialize network tools detection
_detect_network_tools

# ===========================================
# Network Information & Diagnostics
# ===========================================

# Get public IP address with enhanced formatting
function myip() {
    echo -e "${YELLOW}Fetching public IP address...${RESET}"
    
    # Check for internet connectivity first
    if ! _check_internet_connectivity; then
        echo -e "${RED}Error: No internet connection detected${RESET}"
        echo -e "${YELLOW}Local network information:${RESET}"
        ip -brief address show 2>/dev/null || echo -e "${RED}No IP tool available${RESET}"
        return 1
    }
    
    local ip_address
    local ip_info
    local success=0
    
    # Try different services in case one is down
    if [ $HAVE_CURL -eq 1 ]; then
        ip_address=$(curl -s --max-time 5 ifconfig.me)
        [ -n "$ip_address" ] && success=1
        
        if [ $success -eq 0 ]; then
            ip_address=$(curl -s --max-time 5 icanhazip.com)
            [ -n "$ip_address" ] && success=1
        fi
        
        if [ $success -eq 0 ]; then
            ip_address=$(curl -s --max-time 5 ipecho.net/plain)
            [ -n "$ip_address" ] && success=1
        fi
    elif [ $HAVE_WGET -eq 1 ]; then
        ip_address=$(wget -qO- --timeout=5 ifconfig.me)
        [ -n "$ip_address" ] && success=1
        
        if [ $success -eq 0 ]; then
            ip_address=$(wget -qO- --timeout=5 icanhazip.com)
            [ -n "$ip_address" ] && success=1
        fi
        
        if [ $success -eq 0 ]; then
            ip_address=$(wget -qO- --timeout=5 ipecho.net/plain)
            [ -n "$ip_address" ] && success=1
        fi
    else
        echo -e "${RED}Error: Neither curl nor wget available${RESET}"
        echo -e "${CYAN}Run 'pkg install curl' in Termux to install${RESET}"
        return 1
    fi
    
    if [ $success -eq 1 ]; then
        echo -e "${GREEN}Public IP: ${BOLD}$ip_address${RESET}"
        
        # Get additional IP information
        if [ $HAVE_CURL -eq 1 ]; then
            if ip_info=$(curl -s --max-time 5 "https://ipinfo.io/$ip_address/json"); then
                # Parse the JSON response (basic parsing, no jq dependency)
                local city=$(echo "$ip_info" | grep -o '"city": *"[^"]*"' | cut -d'"' -f4)
                local region=$(echo "$ip_info" | grep -o '"region": *"[^"]*"' | cut -d'"' -f4)
                local country=$(echo "$ip_info" | grep -o '"country": *"[^"]*"' | cut -d'"' -f4)
                local org=$(echo "$ip_info" | grep -o '"org": *"[^"]*"' | cut -d'"' -f4)
                local timezone=$(echo "$ip_info" | grep -o '"timezone": *"[^"]*"' | cut -d'"' -f4)
                
                [ -n "$city" ] && [ -n "$region" ] && [ -n "$country" ] && echo -e "${CYAN}Location: $city, $region, $country${RESET}"
                [ -n "$org" ] && echo -e "${CYAN}Provider: $org${RESET}"
                [ -n "$timezone" ] && echo -e "${CYAN}Timezone: $timezone${RESET}"
            fi
        fi
    else
        echo -e "${RED}Failed to retrieve public IP address${RESET}"
        return 1
    fi
    
    # Show local IP addresses (Termux/Android specific)
    echo
    echo -e "${YELLOW}Local network interfaces:${RESET}"
    
    # In Termux, interface names are different from standard Linux
    if [ $HAVE_IP -eq 1 ]; then
        ip -brief address show | grep -v '^lo'
    else
        # Fallback to ifconfig if available
        if command -v ifconfig &>/dev/null; then
            ifconfig | grep -E 'inet (addr)?[:]?([0-9]*\.){3}[0-9]*' | 
                grep -v '127.0.0.1' | awk '{print $2}' | 
                sed 's/addr://' | sed "s/^/${CYAN}Interface: ${RESET}/"
        else
            echo -e "${YELLOW}No network tools available. Install with:${RESET}"
            echo -e "${CYAN}pkg install iproute2${RESET}"
        fi
    fi
    
    # Show DNS servers from Termux/Android
    echo
    echo -e "${YELLOW}DNS Servers:${RESET}"
    if [ -f /etc/resolv.conf ]; then
        grep nameserver /etc/resolv.conf | awk '{print $2}'
    elif [ $HAVE_TERMUX_API -eq 1 ]; then
        # Try to get DNS info from Termux API if available
        termux-wifi-connectioninfo | grep DNS
    else
        echo -e "${YELLOW}Could not determine DNS servers${RESET}"
    fi
}

# Enhanced ping with statistics
function ping_host() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: ping_host <hostname_or_ip> [count] [interval]${RESET}"
        echo "  count: Number of packets to send (default: 5, max: ${NETWORK_MAX_PING_COUNT})"
        echo "  interval: Seconds between pings (default: 1)"
        return 1
    fi
    
    local host="$1"
    local count=${2:-5}
    local interval=${3:-1}
    
    # Safety check for count
    if ! [[ "$count" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Count must be a number${RESET}"
        return 1
    fi
    
    # Safety check for interval
    if ! [[ "$interval" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo -e "${RED}Error: Interval must be a number${RESET}"
        return 1
    fi
    
    # Limit count for safety
    if [ $count -gt $NETWORK_MAX_PING_COUNT ]; then
        echo -e "${YELLOW}Warning: Limiting ping count to $NETWORK_MAX_PING_COUNT${RESET}"
        count=$NETWORK_MAX_PING_COUNT
    fi
    
    echo -e "${YELLOW}Pinging $host ($count packets, ${interval}s interval)...${RESET}"
    
    # Check if host is valid
    if ! ping -c 1 -W 2 "$host" &>/dev/null; then
        echo -e "${RED}Warning: Host $host may be unreachable${RESET}"
        echo -e "${YELLOW}Continue anyway? [y/N]${RESET}"
        read -r proceed
        if [[ ! "$proceed" =~ ^[yY]$ ]]; then
            return 1
        fi
    fi
    
    # Display DNS resolution if applicable
    if [[ ! "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ ! "$host" =~ ^[0-9a-fA-F:]+$ ]]; then
        echo -e "${CYAN}Resolving hostname...${RESET}"
        
        if [ $HAVE_DIG -eq 1 ]; then
            dig +short "$host" | sed "s/^/${CYAN}IP: ${RESET}/"
        elif [ $HAVE_HOST -eq 1 ]; then
            host "$host" | grep "has address" | sed "s/^.*has address /${CYAN}IP: ${RESET}/"
        elif command -v nslookup &>/dev/null; then
            nslookup "$host" | grep "Address" | tail -n +2 | sed "s/^Address: /${CYAN}IP: ${RESET}/"
        fi
    fi
    
    # Run ping with progress indicator
    echo -e "${YELLOW}Progress: ${RESET}"
    
    local success_count=0
    local total_time=0
    local min_time=9999
    local max_time=0
    local current=0
    
    while [ $current -lt $count ]; do
        echo -ne "\r[${current}/${count}] "
        
        # Run a single ping and extract the time
        local ping_output=$(ping -c 1 -W 2 "$host" 2>/dev/null)
        local exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            success_count=$((success_count + 1))
            local time_ms=$(echo "$ping_output" | grep "time=" | sed -E 's/.*time=([0-9.]+) ms.*/\1/')
            
            if [ -n "$time_ms" ]; then
                # Update statistics - need busybox bc for float operations in Termux
                if command -v bc &>/dev/null; then
                    total_time=$(echo "$total_time + $time_ms" | bc -l)
                    
                    if (( $(echo "$time_ms < $min_time" | bc -l) )); then
                        min_time=$time_ms
                    fi
                    
                    if (( $(echo "$time_ms > $max_time" | bc -l) )); then
                        max_time=$time_ms
                    fi
                else
                    # Simple integer approximation if bc not available
                    total_time=$((total_time + ${time_ms%.*}))
                    
                    if [ ${time_ms%.*} -lt ${min_time%.*} ]; then
                        min_time=$time_ms
                    fi
                    
                    if [ ${time_ms%.*} -gt ${max_time%.*} ]; then
                        max_time=$time_ms
                    fi
                fi
                
                # Display progress with color based on latency
                if command -v bc &>/dev/null; then
                    if (( $(echo "$time_ms < 50" | bc -l) )); then
                        echo -ne "${GREEN}${time_ms} ms${RESET} "
                    elif (( $(echo "$time_ms < 100" | bc -l) )); then
                        echo -ne "${YELLOW}${time_ms} ms${RESET} "
                    else
                        echo -ne "${RED}${time_ms} ms${RESET} "
                    fi
                else
                    # Simple integer comparison if bc not available
                    if [ ${time_ms%.*} -lt 50 ]; then
                        echo -ne "${GREEN}${time_ms} ms${RESET} "
                    elif [ ${time_ms%.*} -lt 100 ]; then
                        echo -ne "${YELLOW}${time_ms} ms${RESET} "
                    else
                        echo -ne "${RED}${time_ms} ms${RESET} "
                    fi
                fi
            else
                echo -ne "${GREEN}success${RESET} "
            fi
        else
            echo -ne "${RED}timeout${RESET} "
        fi
        
        current=$((current + 1))
        
        # Wait for the specified interval if not the last ping
        if [ $current -lt $count ]; then
            sleep $interval
        fi
    done
    
    # Calculate statistics
    echo -e "\n"
    echo -e "${CYAN}Ping statistics for $host:${RESET}"
    
    local packet_loss=0
    if [ $count -gt 0 ]; then
        packet_loss=$(( 100 * (count - success_count) / count ))
    fi
    
    echo -e "  ${YELLOW}Packets: Sent = $count, Received = $success_count, Lost = $((count - success_count)) ($packet_loss% loss)${RESET}"
    
    if [ $success_count -gt 0 ]; then
        local avg_time
        
        if command -v bc &>/dev/null; then
            avg_time=$(echo "scale=2; $total_time / $success_count" | bc -l)
            
            # Reset min time if it was never updated
            if [ "$min_time" = "9999" ]; then
                min_time=0
            fi
            
            echo -e "  ${YELLOW}Round-trip times (ms):${RESET}"
            echo -e "    ${GREEN}Minimum = $min_time ms, Maximum = $max_time ms, Average = $avg_time ms${RESET}"
            
            # Interpret the results
            if (( $(echo "$avg_time < 50" | bc -l) )); then
                echo -e "  ${GREEN}Excellent connectivity${RESET}"
            elif (( $(echo "$avg_time < 100" | bc -l) )); then
                echo -e "  ${CYAN}Good connectivity${RESET}"
            elif (( $(echo "$avg_time < 200" | bc -l) )); then
                echo -e "  ${YELLOW}Fair connectivity${RESET}"
            else
                echo -e "  ${RED}Poor connectivity${RESET}"
            fi
        else
            # Simple integer division if bc not available
            avg_time=$((total_time / success_count))
            
            echo -e "  ${YELLOW}Round-trip times (ms):${RESET}"
            echo -e "    ${GREEN}Minimum ≈ $min_time ms, Maximum ≈ $max_time ms, Average ≈ $avg_time ms${RESET}"
            
            # Interpret the results with integer comparison
            if [ $avg_time -lt 50 ]; then
                echo -e "  ${GREEN}Excellent connectivity${RESET}"
            elif [ $avg_time -lt 100 ]; then
                echo -e "  ${CYAN}Good connectivity${RESET}"
            elif [ $avg_time -lt 200 ]; then
                echo -e "  ${YELLOW}Fair connectivity${RESET}"
            else
                echo -e "  ${RED}Poor connectivity${RESET}"
            fi
        fi
    fi
    
    # Return success if at least one ping succeeded
    if [ $success_count -gt 0 ]; then
        return 0
    else
        echo -e "${RED}$host is unreachable${RESET}"
        return 1
    fi
}

# Check if a port is open on a host
function port_check() {
    if [ $# -lt 2 ]; then
        echo -e "${RED}Usage: port_check <hostname_or_ip> <port> [timeout]${RESET}"
        return 1
    fi
    
    local host="$1"
    local port="$2"
    local timeout=${3:-3}
    
    # Validate port
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${RED}Error: Port must be a number between 1 and 65535${RESET}"
        return 1
    fi
    
    # Validate timeout
    if ! [[ "$timeout" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Timeout must be a number${RESET}"
        return 1
    fi
    
    echo -e "${YELLOW}Checking if port $port is open on $host...${RESET}"
    
    local success=0
    local method_used=""
    
    # In Termux/proot, we have more limited options
    if command -v nc &>/dev/null; then
        if nc -z -w "$timeout" "$host" "$port" &>/dev/null; then
            success=1
            method_used="nc"
        fi
    elif [ $HAVE_CURL -eq 1 ]; then
        # Try curl for HTTP/HTTPS ports
        if [[ "$port" == "80" ]] || [[ "$port" == "443" ]] || [[ "$port" == "8080" ]]; then
            local protocol="http"
            [[ "$port" == "443" ]] && protocol="https"
            
            if curl -s --connect-timeout "$timeout" "$protocol://$host:$port" &>/dev/null; then
                success=1
                method_used="curl"
            fi
        else
            # For non-HTTP ports, try telnet-style connection with curl
            if curl -s --connect-timeout "$timeout" "telnet://$host:$port" &>/dev/null; then
                success=1
                method_used="curl telnet"
            fi
        fi
    elif command -v timeout &>/dev/null; then
        if timeout "$timeout" bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
            success=1
            method_used="bash tcp"
        fi
    else
        # Last resort - try bash's /dev/tcp (may not work in all environments)
        { bash -c "echo > /dev/tcp/$host/$port" &>/dev/null; } 2>/dev/null
        
        if [ $? -eq 0 ]; then
            success=1
            method_used="bash direct"
        fi
    fi
    
    # Display results
    if [ $success -eq 1 ]; then
        echo -e "${GREEN}Port $port is open on $host${RESET}"
        
        # Try to identify service on common ports
        if [ -f /etc/services ]; then
            local service=$(grep -w "$port/tcp" /etc/services | head -1 | awk '{print $1}')
            if [ -n "$service" ]; then
                echo -e "${CYAN}Service: $service${RESET}"
            fi
        fi
        
        echo -e "${CYAN}Method used: $method_used${RESET}"
        return 0
    else
        echo -e "${RED}Port $port is closed on $host${RESET}"
        echo -e "${CYAN}Method attempted: ${method_used:-multiple methods}${RESET}"
        return 1
    fi
}

# Network scanning for local devices
function scan_network() {
    local subnet=""
    
    # Try to determine subnet automatically
    if [ $HAVE_IP -eq 1 ]; then
        local ip_info=$(ip route get 1 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
        if [ -n "$ip_info" ]; then
            # Extract first three octets
            subnet=$(echo "$ip_info" | cut -d. -f1-3)
            subnet="$subnet.0/24"
        fi
    elif command -v ifconfig &>/dev/null; then
        # Try with ifconfig
        local ip_addr=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | sed 's/addr://')
        if [ -n "$ip_addr" ]; then
            subnet=$(echo "$ip_addr" | cut -d. -f1-3)
            subnet="$subnet.0/24"
        fi
    fi
    
    # Use provided subnet if specified
    if [ -n "$1" ]; then
        subnet="$1"
    fi
    
    if [ -z "$subnet" ]; then
        echo -e "${RED}Could not determine subnet automatically${RESET}"
        echo -e "${YELLOW}Usage: scan_network [subnet]${RESET}"
        echo -e "Example: scan_network 192.168.1.0/24"
        return 1
    fi
    
    echo -e "${YELLOW}Scanning network: $subnet${RESET}"
    
    # Check for safety in network scanning
    if [ "$NETWORK_SAFE_MODE" -eq 1 ]; then
        echo -e "${YELLOW}Network scanning can generate significant traffic.${RESET}"
        echo -e "${YELLOW}Continue? [y/N]${RESET}"
        read -r confirm
        
        if [[ ! "$confirm" =~ ^[yY]$ ]]; then
            echo -e "${YELLOW}Operation cancelled.${RESET}"
            return 1
        fi
    fi
    
    if [ $HAVE_NMAP -eq 1 ]; then
        echo -e "${CYAN}Using nmap for scanning...${RESET}"
        
        # Display progress to user
        echo -e "${YELLOW}Scanning might take a minute or two. Please wait...${RESET}"
        echo -e "${YELLOW}Using faster timing to accommodate mobile device...${RESET}"
        
        # Use more efficient scan options for mobile devices
        nmap -sn -T4 "$subnet"
        
        # Show scan statistics
        local discovered=$(nmap -sn "$subnet" -oG - | grep "Status: Up" | wc -l)
        echo -e "${GREEN}Scan complete. Found $discovered devices.${RESET}"
    else
        echo -e "${CYAN}Using simple ping scan (nmap not found)...${RESET}"
        echo -e "${YELLOW}To install nmap in Termux, run: pkg install nmap${RESET}"
        
        # Extract IP prefix for ping
        local ip_prefix=$(echo "$subnet" | cut -d/ -f1 | sed 's/\.0$//')
        
        echo -e "${YELLOW}Scanning $ip_prefix.1 to $ip_prefix.254...${RESET}"
        echo -e "${YELLOW}This might take a while. Press Ctrl+C to stop.${RESET}"
        
        local found=0
        local progress=0
        
        # Show progress bar
        echo -ne "[                    ] 0%\r"
        
        # Limit scan range to conserve battery on mobile devices
        for i in {1..254..2}; do  # Step by 2 to reduce scan time
            # Run ping in background to speed up scan
            ping -c 1 -W 1 "$ip_prefix.$i" > /dev/null 2>&1 &
            
            # Limit parallel processes to avoid overwhelming mobile device
            if [ $((i % 8)) -eq 0 ]; then
                wait
                
                # Update progress bar
                progress=$((i * 100 / 254))
                local bars=$((progress / 5))
                local spaces=$((20 - bars))
                
                echo -ne "["
                for ((j=0; j<bars; j++)); do
                    echo -ne "#"
                done
                
                for ((j=0; j<spaces; j++)); do
                    echo -ne " "
                done
                
                echo -ne "] $progress%\r"
            fi
        done
        
        # Wait for all pings to complete
        wait
        echo -ne "[####################] 100%\n"
        
        # Show results (relies on ARP cache)
        echo -e "${CYAN}Found devices:${RESET}"
        
        if command -v arp &>/dev/null; then
            local arp_output=$(arp -a | grep -v incomplete)
            
            if [ -n "$arp_output" ]; then
                echo "$arp_output" | while read -r line; do
                    local ip=$(echo "$line" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
                    local mac=$(echo "$line" | grep -Eo '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -1)
                    
                    if [ -n "$ip" ]; then
                        echo -e "${GREEN}IP: $ip${RESET}${mac:+ - MAC: $mac}"
                        found=$((found + 1))
                    fi
                done
            else
                echo -e "${YELLOW}No devices found in ARP cache${RESET}"
            fi
        elif [ $HAVE_IP -eq 1 ]; then
            # Try using ip neigh
            local ip_neigh=$(ip neigh | grep -v FAILED)
            
            if [ -n "$ip_neigh" ]; then
                echo "$ip_neigh" | while read -r line; do
                    local ip=$(echo "$line" | awk '{print $1}')
                    local mac=$(echo "$line" | awk '{print $5}')
                    local state=$(echo "$line" | awk '{print $NF}')
                    
                    if [ -n "$ip" ] && [[ "$state" == "REACHABLE" || "$state" == "STALE" || "$state" == "DELAY" ]]; then
                        echo -e "${GREEN}IP: $ip${RESET}${mac:+ - MAC: $mac} - State: $state"
                        found=$((found + 1))
                    fi
                done
            else
                echo -e "${YELLOW}No devices found in neighbor cache${RESET}"
            fi
        else
            echo -e "${YELLOW}No arp or ip command available${RESET}"
            echo -e "${CYAN}Install with: pkg install iproute2${RESET}"
        fi
        
        echo -e "${GREEN}Scan complete. Found $found devices.${RESET}"
    fi
}

# Enhanced traceroute with hostname lookup
function traceroute_plus() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: traceroute_plus <hostname_or_ip>${RESET}"
        return 1
    fi
    
    local host="$1"
    local max_hops=${2:-15}  # Lower default for mobile devices
    
    # In Termux, we want to use fewer hops by default to conserve resources
    if ! [[ "$max_hops" =~ ^[0-9]+$ ]] || [ "$max_hops" -lt 1 ] || [ "$max_hops" -gt 30 ]; then
        echo -e "${RED}Error: Max hops must be between 1 and 30${RESET}"
        max_hops=15
    fi
    
    echo -e "${YELLOW}Tracing route to $host (max $max_hops hops)...${RESET}"
    
    # Check for internet connectivity
    if ! _check_internet_connectivity; then
        echo -e "${RED}Warning: No internet connection detected${RESET}"
        echo -e "${YELLOW}Continue anyway? [y/N]${RESET}"
        read -r proceed
        if [[ ! "$proceed" =~ ^[yY]$ ]]; then
            return 1
        fi
    fi
    
    # Choose the appropriate traceroute tool for Termux
    if [ $HAVE_TRACEROUTE -eq 1 ]; then
        echo -e "${CYAN}Running traceroute with default options...${RESET}"
        traceroute -m "$max_hops" "$host"
    elif command -v tracepath &>/dev/null; then
        echo -e "${CYAN}Using tracepath (traceroute not found)...${RESET}"
        tracepath -m "$max_hops" "$host"
    else
        echo -e "${RED}Neither traceroute nor tracepath command found${RESET}"
        echo -e "${CYAN}Install with: pkg install traceroute${RESET}"
        
        # Try fallback with ping and increasing TTL - works in most Termux installs
        echo -e "${YELLOW}Attempting fallback method with ping...${RESET}"
        
        local ttl=1
        local target_reached=0
        
        echo -e "Hop\tIP\t\tTime\tHost"
        echo -e "---\t--\t\t----\t----"
        
        while [ $ttl -le $max_hops ] && [ $target_reached -eq 0 ]; do
            # Ping with specific TTL
            local ping_output=$(ping -c 1 -t $ttl -W 2 "$host" 2>&1)
            local exit_code=$?
            
            # Extract IP from the Time Exceeded message or from successful ping
            local hop_ip=""
            
            if echo "$ping_output" | grep -q "Time to live exceeded"; then
                hop_ip=$(echo "$ping_output" | grep "From" | head -1 | sed -E 's/^From ([^ ]+).*/\1/')
            elif [ $exit_code -eq 0 ]; then
                # Target reached
                hop_ip=$(echo "$ping_output" | grep "bytes from" | sed -E 's/^.*bytes from ([^:]+).*/\1/')
                target_reached=1
            fi
            
            # Extract time
            local time=""
            if echo "$ping_output" | grep -q "time="; then
                time=$(echo "$ping_output" | grep "time=" | sed -E 's/.*time=([0-9.]+) ms.*/\1/')
            else
                time="*"
            fi
            
            # Try to get hostname (avoid if battery is low)
            local hostname=""
            if [ -n "$hop_ip" ]; then
                if [ $HAVE_TERMUX_API -eq 1 ]; then
                    # Check battery level before doing DNS lookup
                    local battery_level=$(termux-battery-status 2>/dev/null | grep -o '"percentage":[0-9]*' | grep -o '[0-9]*')
                    if [ -z "$battery_level" ] || [ "$battery_level" -gt 20 ]; then
                        hostname=$(host "$hop_ip" 2>/dev/null | grep "domain name pointer" | head -1 | sed 's/^.*domain name pointer //')
                    fi
                else
                    hostname=$(host "$hop_ip" 2>/dev/null | grep "domain name pointer" | head -1 | sed 's/^.*domain name pointer //')
                fi
                
                if [ -z "$hostname" ]; then
                    hostname="$hop_ip"
                fi
                
                echo -e "$ttl\t$hop_ip\t$time ms\t$hostname"
            else
                echo -e "$ttl\t*\t*\t*"
            fi
            
            ttl=$((ttl + 1))
            
            # Add a small sleep to avoid overwhelming Termux's resources
            sleep 0.2
        done
    fi
}

# DNS lookup utility
function dns_lookup() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: dns_lookup <hostname> [record_type]${RESET}"
        echo -e "Record types: A, AAAA, MX, NS, TXT, SOA, CNAME, etc."
        echo -e "Example: dns_lookup example.com MX"
        return 1
    fi
    
    local host="$1"
    local record_type="${2:-A}"
    
    # Convert record type to uppercase
    record_type=$(echo "$record_type" | tr '[:lower:]' '[:upper:]')
    
    echo -e "${YELLOW}Looking up $record_type records for $host...${RESET}"
    
    # Choose the appropriate DNS tool
    if [ $HAVE_DIG -eq 1 ]; then
        echo -e "${CYAN}Using dig...${RESET}"
        dig "$host" "$record_type"
    elif [ $HAVE_HOST -eq 1 ]; then
        echo -e "${CYAN}Using host...${RESET}"
        host -t "$record_type" "$host"
    elif command -v nslookup &>/dev/null; then
        echo -e "${CYAN}Using nslookup...${RESET}"
        nslookup -type="$record_type" "$host"
    else
        echo -e "${RED}No DNS lookup tools found${RESET}"
        echo -e "${CYAN}Install with: pkg install dnsutils${RESET}"
        return 1
    fi
}

# Network speed test
function speedtest() {
    echo -e "${YELLOW}Running network speed test...${RESET}"
    
    # Check for internet connectivity
    if ! _check_internet_connectivity; then
        echo -e "${RED}Error: No internet connection detected${RESET}"
        return 1
    }
    
    # Mobile-friendly warning
    echo -e "${YELLOW}Warning: Speed tests consume significant data. Continue? [y/N]${RESET}"
    read -r confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo -e "${YELLOW}Speed test cancelled.${RESET}"
        return 1
    fi
    
    if [ $HAVE_SPEEDTEST_CLI -eq 1 ]; then
        echo -e "${CYAN}Using speedtest-cli for measurements...${RESET}"
        speedtest-cli --simple
    else
        echo -e "${CYAN}Using curl-based speed test (speedtest-cli not found)...${RESET}"
        echo -e "${YELLOW}Note: This method is less accurate than speedtest-cli${RESET}"
        
        # Install speedtest-cli?
        echo -e "${YELLOW}Would you like to install speedtest-cli? [y/N]${RESET}"
        read -r install_speedtest
        
        if [[ "$install_speedtest" =~ ^[yY]$ ]]; then
            if command -v pip &>/dev/null; then
                echo -e "${CYAN}Installing speedtest-cli via pip...${RESET}"
                pip install speedtest-cli
                
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}speedtest-cli installed successfully!${RESET}"
                    # Re-run speedtest with the proper tool
                    speedtest
                    return $?
                else
                    echo -e "${RED}Failed to install speedtest-cli${RESET}"
                fi
            elif command -v pkg &>/dev/null; then
                echo -e "${CYAN}Installing speedtest-cli via pkg...${RESET}"
                pkg install python
                pip install speedtest-cli
                
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}speedtest-cli installed successfully!${RESET}"
                    # Re-run speedtest with the proper tool
                    speedtest
                    return $?
                else
                    echo -e "${RED}Failed to install speedtest-cli${RESET}"
                fi
            fi
        fi
        
        # Create temp file for download test
        local tmp_file=$(mktemp)
        
        # Download test
        echo -e "${CYAN}Testing download speed (using small file size for mobile)...${RESET}"
        
        # Use smaller test files for mobile devices
        local download_urls=(
            "https://speed.cloudflare.com/__down?bytes=5000000"
            "https://proof.ovh.net/files/1Mb.dat"
        )
        
        local download_speed=0
        
        for url in "${download_urls[@]}"; do
            echo -e "${YELLOW}Testing with ${url##*/}...${RESET}"
            
            if [ $HAVE_CURL -eq 1 ]; then
                # Use curl with progress bar
                download_speed=$(curl -L -o "$tmp_file" -w "%{speed_download}" "$url" 2>/dev/null)
            elif [ $HAVE_WGET -eq 1 ]; then
                # Use wget and calculate speed manually
                local start_time=$(date +%s.%N)
                wget -O "$tmp_file" "$url" 2>&1 | grep -E '([0-9.]+)K/s' | tail -1
                local end_time=$(date +%s.%N)
                local time_diff=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "($end_time - $start_time)" | bc 2>/dev/null || echo "$((end_time - start_time))")
                local file_size=$(stat -c%s "$tmp_file" 2>/dev/null || stat -f%z "$tmp_file" 2>/dev/null || wc -c < "$tmp_file")
                
                # Calculate speed in bytes/sec
                if command -v bc &>/dev/null; then
                    download_speed=$(echo "scale=2; $file_size / $time_diff" | bc)
                else
                    download_speed=$((file_size / time_diff))
                fi
            fi
            
            if [ -n "$download_speed" ] && [ "$download_speed" != "0" ]; then
                break
            fi
        done
        
        # Convert to MB/s for display
        if command -v bc &>/dev/null; then
            download_speed=$(echo "scale=2; $download_speed / 1048576" | bc)
            echo -e "${GREEN}Download: $download_speed MB/s${RESET}"
        else
            # Simple integer division if bc not available
            download_speed=$((download_speed / 1048576))
            echo -e "${GREEN}Download: ~$download_speed MB/s${RESET}"
        fi
        
        # Upload test (simple version)
        echo -e "${CYAN}Testing upload speed (minimal test for mobile devices)...${RESET}"
        
        # Generate smaller data for mobile, only 100KB
        local upload_size=102400  # 100 KB for mobile
        dd if=/dev/urandom of="$tmp_file" bs=1024 count=$((upload_size / 1024)) 2>/dev/null
        
        local upload_speed=0
        local upload_urls=(
            "https://httpbin.org/post"
        )
        
        for url in "${upload_urls[@]}"; do
            echo -e "${YELLOW}Testing with ${url##*/}...${RESET}"
            
            if [ $HAVE_CURL -eq 1 ]; then
                # Use curl to upload and measure speed
                upload_speed=$(curl -s -w "%{speed_upload}" -F "file=@$tmp_file" "$url" 2>/dev/null)
            fi
            
            if [ -n "$upload_speed" ] && [ "$upload_speed" != "0" ]; then
                break
            fi
        done
        
        # Convert to MB/s for display
        if [ -n "$upload_speed" ] && [ "$upload_speed" != "0" ]; then
            if command -v bc &>/dev/null; then
                upload_speed=$(echo "scale=2; $upload_speed / 1048576" | bc)
                echo -e "${GREEN}Upload: $upload_speed MB/s${RESET}"
            else
                # Simple integer division if bc not available
                upload_speed=$((upload_speed / 1048576))
                echo -e "${GREEN}Upload: ~$upload_speed MB/s${RESET}"
            fi
        else
            echo -e "${YELLOW}Could not measure upload speed${RESET}"
        fi
        
        # Clean up
        rm -f "$tmp_file"
        
        # Display simple latency test
        echo
        echo -e "${YELLOW}Latency to major servers:${RESET}"
        
        local servers=("google.com" "cloudflare.com")
        
        for server in "${servers[@]}"; do
            echo -ne "${CYAN}$server: ${RESET}"
            ping -c 1 -W 2 "$server" 2>/dev/null | grep "time=" | sed -E 's/.*time=([0-9.]+) ms.*/\1 ms/' || echo "timeout"
        done
    fi
}

# ===========================================
# Web Tools & Utilities
# ===========================================

# Simple HTTP request tool
function http_request() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: http_request <url> [method] [data]${RESET}"
        echo -e "Methods: GET, POST, PUT, DELETE, HEAD (default: GET)"
        echo -e "Example: http_request https://example.com"
        echo -e "         http_request https://example.com/api POST '{\"key\":\"value\"}'"
        return 1
    fi
    
    local url="$1"
    local method="${2:-GET}"
    local data="$3"
    
    # Validate URL format
    if [[ ! "$url" =~ ^https?:// ]]; then
        echo -e "${YELLOW}URL doesn't start with http:// or https://. Adding https://...${RESET}"
        url="https://$url"
    fi
    
    # Validate method
    method=$(echo "$method" | tr '[:lower:]' '[:upper:]')
    case "$method" in
        GET|POST|PUT|DELETE|HEAD|OPTIONS|PATCH)
            # Valid method
            ;;
        *)
            echo -e "${RED}Invalid HTTP method: $method${RESET}"
            echo -e "${YELLOW}Valid methods: GET, POST, PUT, DELETE, HEAD, OPTIONS, PATCH${RESET}"
            return 1
            ;;
    esac
    
    echo -e "${YELLOW}Making $method request to $url...${RESET}"
    
    # Check for internet connectivity
    if ! _check_internet_connectivity; then
        echo -e "${RED}Warning: No internet connection detected${RESET}"
        echo -e "${YELLOW}Continue anyway? [y/N]${RESET}"
        read -r proceed
        if [[ ! "$proceed" =~ ^[yY]$ ]]; then
            return 1
        fi
    fi
    
    # Determine which tool to use
    if [ $HAVE_CURL -eq 1 ]; then
        # Build curl command
        local curl_cmd="curl -s -i -X $method"
        
        # Add user agent
        curl_cmd+=" -A '$NETWORK_USER_AGENT'"
        
        # Add timeout
        curl_cmd+=" --connect-timeout $NETWORK_TOOLS_TIMEOUT"
        
        # Add data for POST and PUT requests
        if [[ "$method" == "POST" || "$method" == "PUT" || "$method" == "PATCH" ]] && [ -n "$data" ]; then
            curl_cmd+=" -H 'Content-Type: application/json' -d '$data'"
        fi
        
        # Add URL
        curl_cmd+=" '$url'"
        
        # Show the command being executed
        echo -e "${CYAN}Executing: curl request to $url${RESET}"
        
        # Execute curl command and capture output
        local response=$(eval "$curl_cmd")
        
        # Split headers and body
        local header=$(echo "$response" | awk 'BEGIN{RS="\r\n\r\n"} {print $0; exit}')
        local body=$(echo "$response" | awk 'BEGIN{RS="\r\n\r\n"; ORS="\n\n"} {if (NR>1) print $0}')
        
        # Extract status code
        local status_code=$(echo "$header" | head -n 1 | grep -Eo '[0-9]{3}' | head -1)
        local status_text=$(echo "$header" | head -n 1 | grep -Eo '[0-9]{3} .*' | sed 's/[0-9]\{3\} //')
        
        # Display response
        echo -e "${CYAN}Response:${RESET}"
        
        # Colorize status code based on value
        if [ -n "$status_code" ]; then
            if [[ "$status_code" =~ ^2[0-9][0-9]$ ]]; then
                echo -e "${GREEN}Status: $status_code $status_text${RESET}"
            elif [[ "$status_code" =~ ^3[0-9][0-9]$ ]]; then
                echo -e "${YELLOW}Status: $status_code $status_text${RESET}"
            else
                echo -e "${RED}Status: $status_code $status_text${RESET}"
            fi
        else
            echo -e "${RED}Status: Unknown${RESET}"
        fi
        
        # Display headers
        echo -e "${GREEN}Headers:${RESET}"
        echo "$header" | grep -v "^HTTP" | head -10 | sed 's/^/  /'
        
        if [ $(echo "$header" | wc -l) -gt 10 ]; then
            echo "  ... (more headers)"
        fi
        
        # Skip body for HEAD requests
        if [ "$method" = "HEAD" ]; then
            echo -e "${YELLOW}HEAD request - no body returned${RESET}"
            return 0
        fi
        
        echo
        
        # Display body (limit for mobile)
        echo -e "${GREEN}Body (first 20 lines):${RESET}"
        echo "$body" | head -20
        
        # Check if response was truncated
        if [ "$(echo "$body" | wc -l)" -gt 20 ]; then
            echo -e "${YELLOW}... (truncated, $(echo "$body" | wc -l) lines total)${RESET}"
        fi
    elif [ $HAVE_WGET -eq 1 ]; then
        # Build wget command for Termux
        local wget_cmd="wget -qO- --server-response"
        
        # Add user agent
        wget_cmd+=" --user-agent='$NETWORK_USER_AGENT'"
        
        # Add timeout
        wget_cmd+=" --timeout=$NETWORK_TOOLS_TIMEOUT"
        
        # Handle different methods
        case "$method" in
            GET)
                # Default method for wget
                ;;
            POST|PUT|PATCH)
                if [ -n "$data" ]; then
                    # Create a temporary file for data
                    local data_file=$(mktemp)
                    echo "$data" > "$data_file"
                    
                    wget_cmd+=" --header='Content-Type: application/json'"
                    wget_cmd+=" --post-file='$data_file'"
                    
                    if [ "$method" != "POST" ]; then
                        wget_cmd+=" --method=$method"
                    fi
                else
                    wget_cmd+=" --method=$method"
                fi
                ;;
            *)
                wget_cmd+=" --method=$method"
                ;;
        esac
        
        # Add URL
        wget_cmd+=" '$url'"
        
        echo -e "${CYAN}Executing: wget request to $url${RESET}"
        
        # Execute wget command
        local response=$(eval "$wget_cmd" 2>&1)
        local exit_code=$?
        
        # Extract status from wget output
        local status_line=$(echo "$response" | grep -i "HTTP/" | head -1)
        local status_code=$(echo "$status_line" | grep -Eo '[0-9]{3}' | head -1)
        
        # Extract headers
        local headers=$(echo "$response" | awk '/^  HTTP/{flag=1} flag && /^  [A-Za-z]/{print}')
        
        # Extract body - everything after the server response block
        local body=$(echo "$response" | awk '/^  HTTP/{flag=1} !flag{print}' | tail -n +1)
        
        # Display response
        echo -e "${CYAN}Response:${RESET}"
        
        # Display status
        if [ -n "$status_code" ]; then
            if [[ "$status_code" =~ ^2[0-9][0-9]$ ]]; then
                echo -e "${GREEN}Status: $status_code${RESET}"
            elif [[ "$status_code" =~ ^3[0-9][0-9]$ ]]; then
                echo -e "${YELLOW}Status: $status_code${RESET}"
            else
                echo -e "${RED}Status: $status_code${RESET}"
            fi
        else
            echo -e "${RED}Status: Unknown${RESET}"
        fi
        
        # Display headers
        echo -e "${GREEN}Headers:${RESET}"
        echo "$headers" | head -10 | sed 's/^  /  /'
        
        # Skip body for HEAD requests
        if [ "$method" = "HEAD" ]; then
            echo -e "${YELLOW}HEAD request - no body returned${RESET}"
            
            # Clean up temp file if created
            if [ -n "$data_file" ] && [ -f "$data_file" ]; then
                rm -f "$data_file"
            fi
            
            return 0
        fi
        
        echo
        
        # Display body (limit for mobile)
        echo -e "${GREEN}Body (first 20 lines):${RESET}"
        echo "$body" | head -20
        
        # Check if response was truncated
        if [ "$(echo "$body" | wc -l)" -gt 20 ]; then
            echo -e "${YELLOW}... (truncated, $(echo "$body" | wc -l) lines total)${RESET}"
        fi
        
        # Clean up temp file if created
        if [ -n "$data_file" ] && [ -f "$data_file" ]; then
            rm -f "$data_file"
        fi
    else
        echo -e "${RED}Error: Neither curl nor wget is available${RESET}"
        echo -e "${CYAN}Install curl with: pkg install curl${RESET}"
        return 1
    fi
}

# URL shortener function
function shorten_url() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: shorten_url <long_url>${RESET}"
        return 1
    fi
    
    local long_url="$1"
    
    # Ensure URL has a protocol
    if [[ ! "$long_url" =~ ^https?:// ]]; then
        echo -e "${YELLOW}URL doesn't start with http:// or https://. Adding https://...${RESET}"
        long_url="https://$long_url"
    fi
    
    echo -e "${YELLOW}Shortening URL: $long_url${RESET}"
    
    # Check for internet connectivity
    if ! _check_internet_connectivity; then
        echo -e "${RED}Error: No internet connection detected${RESET}"
        return 1
    }
    
    local short_url=""
    local success=0
    
    # Try different URL shortening services
    if [ $HAVE_CURL -eq 1 ]; then
        # Try TinyURL API
        short_url=$(curl -s "https://tinyurl.com/api-create.php?url=$long_url")
        [ -n "$short_url" ] && [[ "$short_url" =~ ^https?:// ]] && success=1
        
        # Try is.gd if TinyURL fails
        if [ $success -eq 0 ]; then
            short_url=$(curl -s "https://is.gd/create.php?format=simple&url=$long_url")
            [ -n "$short_url" ] && [[ "$short_url" =~ ^https?:// ]] && success=1
        fi
    elif [ $HAVE_WGET -eq 1 ]; then
        # Try TinyURL API with wget
        short_url=$(wget -qO- "https://tinyurl.com/api-create.php?url=$long_url")
        [ -n "$short_url" ] && [[ "$short_url" =~ ^https?:// ]] && success=1
        
        # Try is.gd if TinyURL fails
        if [ $success -eq 0 ]; then
            short_url=$(wget -qO- "https://is.gd/create.php?format=simple&url=$long_url")
            [ -n "$short_url" ] && [[ "$short_url" =~ ^https?:// ]] && success=1
        fi
    else
        echo -e "${RED}Error: Neither curl nor wget available${RESET}"
        echo -e "${CYAN}Install curl with: pkg install curl${RESET}"
        return 1
    fi
    
    if [ $success -eq 1 ]; then
        echo -e "${GREEN}Short URL: $short_url${RESET}"
        
        # Copy to clipboard if Termux API is available
        if [ $HAVE_TERMUX_API -eq 1 ]; then
            echo -n "$short_url" | termux-clipboard-set
            echo -e "${CYAN}(URL copied to clipboard)${RESET}"
        elif command -v xclip &> /dev/null; then
            echo -n "$short_url" | xclip -selection clipboard
            echo -e "${CYAN}(URL copied to clipboard)${RESET}"
        elif command -v termux-clipboard-set &> /dev/null; then
            echo -n "$short_url" | termux-clipboard-set
            echo -e "${CYAN}(URL copied to clipboard)${RESET}"
        fi
    else
        echo -e "${RED}Failed to shorten URL${RESET}"
        return 1
    fi
}

# Download file with progress
function dl() {
    # Initialize download directory
    _init_network_dirs
    
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: dl <url> [output_filename]${RESET}"
        echo "Downloads file with progress tracking"
        echo "Example: dl https://example.com/file.zip my_file.zip"
        return 1
    fi
    
    local url="$1"
    local output_file="$2"
    
    # Ensure URL has a protocol
    if [[ ! "$url" =~ ^https?:// ]]; then
        echo -e "${YELLOW}URL doesn't start with http:// or https://. Adding https://...${RESET}"
        url="https://$url"
    fi
    
    # If output filename is not specified, use the basename of the URL
    if [ -z "$output_file" ]; then
        output_file=$(basename "$url" | sed 's/\?.*//')
        
        # If output_file is still empty or just a query string, use a default name
        if [ -z "$output_file" ] || [[ "$output_file" == "?" ]]; then
            output_file="download_$(date +%Y%m%d_%H%M%S)"
        fi
    fi
    
    # Set full path in download directory
    output_file="$NETWORK_DOWNLOAD_DIR/$output_file"
    
    # Check if file already exists
    if [ -f "$output_file" ]; then
        echo -e "${YELLOW}File '$output_file' already exists.${RESET}"
        echo -e "${YELLOW}What would you like to do?${RESET}"
        echo "1. Overwrite"
        echo "2. Resume download (if supported)"
        echo "3. Save with a new name"
        echo "4. Cancel"
        read -p "Enter your choice [1-4]: " choice
        
        case $choice in
            1)
                # Overwrite - continue with download
                ;;
            2)
                # Resume download
                echo -e "${CYAN}Attempting to resume download...${RESET}"
                if [ $HAVE_WGET -eq 1 ]; then
                    wget -c --show-progress -O "$output_file" "$url"
                elif [ $HAVE_CURL -eq 1 ]; then
                    curl -L -C - -o "$output_file" --progress-bar "$url"
                else
                    echo -e "${RED}Neither wget nor curl command found${RESET}"
                    echo -e "${CYAN}Install with: pkg install curl${RESET}"
                fi
                
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Download completed: $output_file${RESET}"
                    # Show file info
                    local file_size=$(du -h "$output_file" | cut -f1)
                    echo -e "${CYAN}File size: $file_size${RESET}"
                    
                    # Show file type
                    if command -v file &> /dev/null; then
                        echo -e "${CYAN}File type: $(file -b "$output_file")${RESET}"
                    fi
                else
                    echo -e "${RED}Download failed${RESET}"
                fi
                return
                ;;
            3)
                # Save with new name
                echo -e "${YELLOW}Enter new filename:${RESET}"
                read -r new_name
                if [ -n "$new_name" ]; then
                    output_file="$NETWORK_DOWNLOAD_DIR/$new_name"
                else
                    echo -e "${RED}No filename provided. Cancelling.${RESET}"
                    return 1
                fi
                ;;
            *)
                echo -e "${YELLOW}Download cancelled.${RESET}"
                return 0
                ;;
        esac
    fi
    
    echo -e "${YELLOW}Downloading $url to $output_file...${RESET}"
    
    # Mobile-friendly warning about data usage
    echo -e "${YELLOW}This download will use mobile data. Continue? [y/N]${RESET}"
    read -r continue_download
    if [[ ! "$continue_download" =~ ^[yY]$ ]]; then
        echo -e "${YELLOW}Download cancelled.${RESET}"
        return 0
    fi
    
    # Check for internet connectivity
    if ! _check_internet_connectivity; then
        echo -e "${RED}Warning: No internet connection detected${RESET}"
        echo -e "${YELLOW}Continue anyway? [y/N]${RESET}"
        read -r proceed
        if [[ ! "$proceed" =~ ^[yY]$ ]]; then
            return 1
        fi
    fi
    
    # Download with progress
    if [ $HAVE_WGET -eq 1 ]; then
        wget -c --show-progress -O "$output_file" "$url"
    elif [ $HAVE_CURL -eq 1 ]; then
        curl -L -o "$output_file" --progress-bar "$url"
    else
        echo -e "${RED}Neither wget nor curl command found${RESET}"
        echo -e "${CYAN}Install with: pkg install curl${RESET}"
        return 1
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Download completed: $output_file${RESET}"
        
        # Show file size
        local file_size=$(du -h "$output_file" | cut -f1)
        echo -e "${CYAN}File size: $file_size${RESET}"
        
        # Show file type
        if command -v file &> /dev/null; then
            echo -e "${CYAN}File type: $(file -b "$output_file")${RESET}"
        fi
    else
        echo -e "${RED}Download failed${RESET}"
        
        # Check if file was partially downloaded
        if [ -f "$output_file" ] && [ -s "$output_file" ]; then
            echo -e "${YELLOW}Partial file was downloaded. Keep it? [y/N]${RESET}"
            read -r keep_partial
            
            if [[ ! "$keep_partial" =~ ^[yY]$ ]]; then
                rm -f "$output_file"
                echo -e "${YELLOW}Partial file removed.${RESET}"
            else
                echo -e "${YELLOW}Partial file kept. You can resume later with: dl $url $output_file${RESET}"
            fi
        fi
        
        return 1
    fi
}

# Function to extract content from web page
function extract_web() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: extract_web <url> [type]${RESET}"
        echo -e "Types: text (default), links, images, title"
        return 1
    fi
    
    local url="$1"
    local type="${2:-text}"
    
    # Ensure URL has a protocol
    if [[ ! "$url" =~ ^https?:// ]]; then
        echo -e "${YELLOW}URL doesn't start with http:// or https://. Adding https://...${RESET}"
        url="https://$url"
    fi
    
    echo -e "${YELLOW}Extracting $type from $url...${RESET}"
    
    # Check for internet connectivity
    if ! _check_internet_connectivity; then
        echo -e "${RED}Warning: No internet connection detected${RESET}"
        echo -e "${YELLOW}Continue anyway? [y/N]${RESET}"
        read -r proceed
        if [[ ! "$proceed" =~ ^[yY]$ ]]; then
            return 1
        fi
    fi
    
    # In Termux, we need to be efficient with resources
    echo -e "${YELLOW}This might use some data. Continue? [y/N]${RESET}"
    read -r continue_extract
    if [[ ! "$continue_extract" =~ ^[yY]$ ]]; then
        echo -e "${YELLOW}Operation cancelled.${RESET}"
        return 0
    fi
    
    # Ensure we have curl or wget
    if [ $HAVE_CURL -eq 0 ] && [ $HAVE_WGET -eq 0 ]; then
        echo -e "${RED}Error: Neither curl nor wget command found${RESET}"
        echo -e "${CYAN}Install with: pkg install curl${RESET}"
        return 1
    fi
    
    # Fetch the page content
    local page_content=""
    
    if [ $HAVE_CURL -eq 1 ]; then
        page_content=$(curl -s -L --max-time $NETWORK_TOOLS_TIMEOUT -A "$NETWORK_USER_AGENT" "$url")
    else
        page_content=$(wget -qO- --timeout=$NETWORK_TOOLS_TIMEOUT --user-agent="$NETWORK_USER_AGENT" "$url")
    fi
    
    if [ -z "$page_content" ]; then
        echo -e "${RED}Error: Failed to retrieve web page content${RESET}"
        return 1
    fi
    
    # Process based on the extraction type
    case "$type" in
        text)
            echo -e "${CYAN}Extracting text content (first 20 lines)...${RESET}"
            # Remove HTML tags, scripts, styles, and blank lines
            echo "$page_content" |
                sed 's/<script[^>]*>.*<\/script>//g' |
                sed 's/<style[^>]*>.*<\/style>//g' |
                sed 's/<[^>]*>//g' |
                sed 's/&nbsp;/ /g' |
                sed 's/&lt;/</g' |
                sed 's/&gt;/>/g' |
                sed 's/&amp;/\&/g' |
                sed 's/&quot;/"/g' |
                grep -v "^\s*$" |
                head -n 20
            ;;
            
        links)
            echo -e "${CYAN}Extracting links (first 20)...${RESET}"
            # Extract and sort unique links
            echo "$page_content" |
                grep -o '<a [^>]*href="[^"]*"[^>]*>' |
                sed 's/<a [^>]*href="\([^"]*\)"[^>]*>/\1/g' |
                grep -v "^#" |
                sort |
                uniq |
                head -n 20
            ;;
            
        images)
            echo -e "${CYAN}Extracting image URLs (first 10)...${RESET}"
            # Extract image sources
            echo "$page_content" |
                grep -o '<img [^>]*src="[^"]*"[^>]*>' |
                sed 's/<img [^>]*src="\([^"]*\)"[^>]*>/\1/g' |
                head -n 10
            ;;
            
        title)
            echo -e "${CYAN}Extracting page title...${RESET}"
            # Extract title tag
            echo "$page_content" |
                grep -o '<title>[^<]*</title>' |
                sed 's/<title>\(.*\)<\/title>/\1/g' |
                sed 's/&#[0-9]\+;//g' |
                sed 's/&nbsp;/ /g' |
                sed 's/&lt;/</g' |
                sed 's/&gt;/>/g' |
                sed 's/&amp;/\&/g' |
                sed 's/&quot;/"/g'
            ;;
            
        *)
            echo -e "${RED}Unknown extraction type: $type${RESET}"
            echo -e "${YELLOW}Supported types: text, links, images, title${RESET}"
            return 1
            ;;
    esac
}

# Function to start simple HTTP server
function serve() {
    local port=${1:-8000}
    local directory=${2:-$(pwd)}
    
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Port must be a number${RESET}"
        return 1
    fi
    
    if [ ! -d "$directory" ]; then
        echo -e "${RED}Directory '$directory' not found${RESET}"
        return 1
    fi
    
    # Termux/Android specific warning
    echo -e "${YELLOW}Warning: Starting a server on your Android device may expose files${RESET}"
    echo -e "${YELLOW}to other devices on your network. Continue? [y/N]${RESET}"
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo -e "${YELLOW}Operation cancelled.${RESET}"
        return 1
    fi
    
    # Check if port is already in use
    if command -v netstat &>/dev/null; then
        if netstat -tuln | grep -q ":$port "; then
            echo -e "${RED}Error: Port $port is already in use${RESET}"
            echo -e "${YELLOW}Try a different port${RESET}"
            return 1
        fi
    elif command -v ss &>/dev/null; then
        if ss -tuln | grep -q ":$port "; then
            echo -e "${RED}Error: Port $port is already in use${RESET}"
            echo -e "${YELLOW}Try a different port${RESET}"
            return 1
        fi
    fi
    
    # Determine local IP for display
    local ip_addr=""
    if [ $HAVE_IP -eq 1 ]; then
        ip_addr=$(ip addr show | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
    elif command -v ifconfig &>/dev/null; then
        ip_addr=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | sed 's/addr://')
    fi
    
    echo -e "${GREEN}Starting HTTP server in $directory on port $port...${RESET}"
    
    # Display access URLs
    echo -e "${CYAN}Server URLs:${RESET}"
    echo -e "  Local: ${GREEN}http://localhost:$port/${RESET}"
    if [ -n "$ip_addr" ]; then
        echo -e "  Network: ${GREEN}http://$ip_addr:$port/${RESET}"
        echo -e "${YELLOW}  Note: Other devices on your network can access this server${RESET}"
    fi
    
    # Display directory contents
    echo -e "${CYAN}Serving directory contents:${RESET}"
    ls -la "$directory" | head -10
    
    echo -e "${YELLOW}Press Ctrl+C to stop the server${RESET}"
    
    # Start the server with the appropriate tool
    if command -v python3 &> /dev/null; then
        (cd "$directory" && python3 -m http.server "$port")
    elif command -v python &> /dev/null; then
        # Check Python version
        local python_version=$(python --version 2>&1)
        if [[ "$python_version" == *"Python 3"* ]]; then
            (cd "$directory" && python -m http.server "$port")
        else
            (cd "$directory" && python -m SimpleHTTPServer "$port")
        fi
    elif command -v php &> /dev/null; then
        # Fallback to PHP server
        echo -e "${YELLOW}Python not found, using PHP server${RESET}"
        (cd "$directory" && php -S "0.0.0.0:$port")
    else
        echo -e "${RED}Error: No suitable HTTP server found${RESET}"
        echo -e "${CYAN}Install Python with: pkg install python${RESET}"
        return 1
    fi
}

# Function to fetch weather information
function weather() {
    local location=${1:-""}
    
    # Check for internet connectivity
    if ! _check_internet_connectivity; then
        echo -e "${RED}Error: No internet connection detected${RESET}"
        return 1
    }
    
    if [ -z "$location" ]; then
        # Try to get location from Termux API if available
        if [ $HAVE_TERMUX_API -eq 1 ] && command -v termux-location &>/dev/null; then
            echo -e "${YELLOW}Getting current location...${RESET}"
            local location_data=$(termux-location)
            local latitude=$(echo "$location_data" | grep -o '"latitude":[^,]*' | cut -d':' -f2)
            local longitude=$(echo "$location_data" | grep -o '"longitude":[^,]*' | cut -d':' -f2)
            
            if [ -n "$latitude" ] && [ -n "$longitude" ]; then
                echo -e "${CYAN}Using current location: $latitude,$longitude${RESET}"
                # Use wttr.in with coordinates
                curl -s "wttr.in/@$latitude,$longitude?q&n" | head -n 7
                return 0
            fi
        fi
        
        # If Termux API not available, try to get location by IP
        echo -e "${YELLOW}Getting weather for your IP location...${RESET}"
        
        # Try to get location from IP info
        if [ $HAVE_CURL -eq 1 ]; then
            local ip_info=$(curl -s "https://ipinfo.io/json")
            location=$(echo "$ip_info" | grep -o '"city": *"[^"]*"' | cut -d'"' -f4)
        elif [ $HAVE_WGET -eq 1 ]; then
            local ip_info=$(wget -qO- "https://ipinfo.io/json")
            location=$(echo "$ip_info" | grep -o '"city": *"[^"]*"' | cut -d'"' -f4)
        fi
        
        if [ -z "$location" ]; then
            echo -e "${YELLOW}Could not determine location automatically${RESET}"
            echo -e "${YELLOW}Please provide a location:${RESET}"
            read -r location
            
            if [ -z "$location" ]; then
                echo -e "${RED}No location provided. Cancelling.${RESET}"
                return 1
            fi
        fi
    fi
    
    echo -e "${YELLOW}Getting weather for $location...${RESET}"
    
    # Use wttr.in for weather - simple text-based weather report
    if [ $HAVE_CURL -eq 1 ]; then
        curl -s "wttr.in/$location?q&n" | head -n 7
    elif [ $HAVE_WGET -eq 1 ]; then
        wget -qO- "wttr.in/$location?q&n" | head -n 7
    else
        echo -e "${RED}Error: Neither curl nor wget is available${RESET}"
        echo -e "${CYAN}Install curl with: pkg install curl${RESET}"
        return 1
    fi
}

# ===========================================
# Module Health Check & Auto-run Functions
# ===========================================

# Function to check the health of this module
function _network_utilities_sh_health_check() {
    local health_status=0
    
    # Check if required directories can be created
    _init_network_dirs || health_status=1
    
    # Check for critical network tools
    if [ $HAVE_CURL -eq 0 ] && [ $HAVE_WGET -eq 0 ]; then
        echo -e "${YELLOW}Warning: Neither curl nor wget is available${RESET}"
        echo -e "${CYAN}Many functions will not work. Install with: pkg install curl${RESET}"
        health_status=1
    fi
    
    # Check for network connectivity
    if ! _check_internet_connectivity; then
        echo -e "${YELLOW}Warning: No internet connection detected${RESET}"
        echo -e "${CYAN}Network functions requiring internet access will not work${RESET}"
        # Not a critical error, so don't change health_status
    fi
    
    # Check if we have basic network tools
    local missing_tools=()
    
    [ $HAVE_DIG -eq 0 ] && [ $HAVE_HOST -eq 0 ] && missing_tools+=("dnsutils")
    [ $HAVE_IP -eq 0 ] && missing_tools+=("iproute2")
    [ $HAVE_TRACEROUTE -eq 0 ] && missing_tools+=("traceroute")
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${YELLOW}Recommended packages for full functionality: ${missing_tools[*]}${RESET}"
        echo -e "${CYAN}Install with: pkg install ${missing_tools[*]}${RESET}"
    fi
    
    return $health_status
}

# Run the health check if this is not being sourced by module loader
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _network_utilities_sh_health_check
fi

# Output module load message if verbose
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}Loaded: ${BOLD}Network Utilities Module${RESET} (v1.2)"
    
    # Show Termux-specific information
    echo -e "${CYAN}Optimized for Android Termux with proot-distro Ubuntu${RESET}"
    
    # Check what tools are available
    local available_tools=()
    [ $HAVE_CURL -eq 1 ] && available_tools+=("curl")
    [ $HAVE_WGET -eq 1 ] && available_tools+=("wget")
    [ $HAVE_DIG -eq 1 ] && available_tools+=("dig")
    [ $HAVE_NMAP -eq 1 ] && available_tools+=("nmap")
    [ $HAVE_TRACEROUTE -eq 1 ] && available_tools+=("traceroute")
    [ $HAVE_SPEEDTEST_CLI -eq 1 ] && available_tools+=("speedtest-cli")
    [ $HAVE_TERMUX_API -eq 1 ] && available_tools+=("termux-api")
    
    echo -e "${CYAN}Available tools: ${available_tools[*]}${RESET}"
fi
