#!/bin/bash
# ===========================================
# Network Utilities & Web Tools
# ===========================================
# Network diagnostics, monitoring, and web-related functions
# Author: Claude & Me
# Version: 1.0
# Last Updated: 2025-05-14

# ===========================================
# Network Information & Diagnostics
# ===========================================

# Get public IP address with enhanced formatting
function myip() {
    echo -e "${YELLOW}Fetching public IP address...${RESET}"
    
    local ip_address
    local ip_info
    
    # Try different services in case one is down
    if ip_address=$(curl -s ifconfig.me); then
        echo -e "${GREEN}Public IP: ${BOLD}$ip_address${RESET}"
        
        # Get additional IP information
        if ip_info=$(curl -s "https://ipinfo.io/$ip_address/json"); then
            local city=$(echo "$ip_info" | grep -o '"city": *"[^"]*"' | cut -d'"' -f4)
            local region=$(echo "$ip_info" | grep -o '"region": *"[^"]*"' | cut -d'"' -f4)
            local country=$(echo "$ip_info" | grep -o '"country": *"[^"]*"' | cut -d'"' -f4)
            local org=$(echo "$ip_info" | grep -o '"org": *"[^"]*"' | cut -d'"' -f4)
            
            echo -e "${CYAN}Location: $city, $region, $country${RESET}"
            echo -e "${CYAN}Provider: $org${RESET}"
        fi
    elif ip_address=$(curl -s icanhazip.com); then
        echo -e "${GREEN}Public IP: ${BOLD}$ip_address${RESET}"
    elif ip_address=$(curl -s ipecho.net/plain); then
        echo -e "${GREEN}Public IP: ${BOLD}$ip_address${RESET}"
    else
        echo -e "${RED}Failed to retrieve public IP address${RESET}"
        return 1
    fi
    
    # Show local IP addresses
    echo
    echo -e "${YELLOW}Local network interfaces:${RESET}"
    ip -brief address show | grep -v '^lo'
}

# Enhanced ping with statistics
function ping_host() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: ping_host <hostname_or_ip> [count]${RESET}"
        return 1
    fi
    
    local host="$1"
    local count=${2:-5}
    
    echo -e "${YELLOW}Pinging $host ($count packets)...${RESET}"
    
    if ping -c "$count" "$host"; then
        echo -e "${GREEN}$host is reachable${RESET}"
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
    
    echo -e "${YELLOW}Checking if port $port is open on $host...${RESET}"
    
    if command -v nc &> /dev/null; then
        if nc -z -w "$timeout" "$host" "$port"; then
            echo -e "${GREEN}Port $port is open on $host${RESET}"
            return 0
        else
            echo -e "${RED}Port $port is closed on $host${RESET}"
            return 1
        fi
    elif command -v timeout &> /dev/null; then
        if timeout "$timeout" bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
            echo -e "${GREEN}Port $port is open on $host${RESET}"
            return 0
        else
            echo -e "${RED}Port $port is closed on $host${RESET}"
            return 1
        fi
    else
        echo -e "${RED}Neither nc nor timeout command found${RESET}"
        return 1
    fi
}

# Network scanning for local devices
function scan_network() {
    local subnet=""
    
    # Try to determine subnet automatically
    local ip_info=$(ip route get 1 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
    if [ -n "$ip_info" ]; then
        # Extract first three octets
        subnet=$(echo "$ip_info" | cut -d. -f1-3)
        subnet="$subnet.0/24"
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
    
    if command -v nmap &> /dev/null; then
        echo -e "${CYAN}Using nmap for scanning...${RESET}"
        nmap -sn "$subnet"
    else
        echo -e "${CYAN}Using simple ping scan (nmap not found)...${RESET}"
        
        # Extract IP prefix for ping
        local ip_prefix=$(echo "$subnet" | cut -d/ -f1 | sed 's/\.0$//')
        
        echo -e "${YELLOW}Scanning $ip_prefix.0 to $ip_prefix.255...${RESET}"
        
        for i in {1..254}; do
            # Run ping in background to speed up scan
            ping -c 1 -W 1 "$ip_prefix.$i" > /dev/null 2>&1 &
        done
        
        # Wait for all pings to complete
        wait
        
        # Show results (relies on ARP cache)
        echo -e "${CYAN}Found devices:${RESET}"
        arp -a | grep -v incomplete
    fi
}

# Enhanced traceroute with hostname lookup
function traceroute_plus() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: traceroute_plus <hostname_or_ip>${RESET}"
        return 1
    fi
    
    local host="$1"
    
    echo -e "${YELLOW}Tracing route to $host...${RESET}"
    
    if command -v traceroute &> /dev/null; then
        traceroute -n "$host"
    elif command -v tracepath &> /dev/null; then
        tracepath -n "$host"
    else
        echo -e "${RED}Neither traceroute nor tracepath command found${RESET}"
        return 1
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
    
    echo -e "${YELLOW}Looking up $record_type records for $host...${RESET}"
    
    if command -v dig &> /dev/null; then
        dig "$host" "$record_type" +short
    elif command -v host &> /dev/null; then
        host -t "$record_type" "$host"
    elif command -v nslookup &> /dev/null; then
        nslookup -type="$record_type" "$host"
    else
        echo -e "${RED}No DNS lookup tools found (dig, host, or nslookup)${RESET}"
        return 1
    fi
}

# Network speed test
function speedtest() {
    echo -e "${YELLOW}Running network speed test...${RESET}"
    
    if command -v speedtest-cli &> /dev/null; then
        speedtest-cli --simple
    else
        echo -e "${CYAN}Using curl-based speed test (speedtest-cli not found)...${RESET}"
        
        # Create temp file for download test
        local tmp_file=$(mktemp)
        
        # Download test
        echo -e "${CYAN}Testing download speed...${RESET}"
        local download_speed=$(curl -o "$tmp_file" -s -w "%{speed_download}" "https://speed.cloudflare.com/__down?bytes=50000000" 2>/dev/null)
        download_speed=$(echo "scale=2; $download_speed / 1048576" | bc)
        echo -e "${GREEN}Download: $download_speed MB/s${RESET}"
        
        # Upload test (simple version)
        echo -e "${CYAN}Testing upload speed...${RESET}"
        local upload_data=$(head -c 10000000 /dev/urandom | base64)
        local upload_speed=$(curl -s -w "%{speed_upload}" -d "$upload_data" "https://speed.cloudflare.com/__up" 2>/dev/null)
        upload_speed=$(echo "scale=2; $upload_speed / 1048576" | bc)
        echo -e "${GREEN}Upload: $upload_speed MB/s${RESET}"
        
        # Clean up
        rm "$tmp_file"
    fi
}

# ===========================================
# Web Tools & Utilities
# ===========================================

# Simple HTTP request tool
function http_request() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: http_request <url> [method] [data]${RESET}"
        echo -e "Methods: GET, POST, PUT, DELETE, HEAD"
        echo -e "Example: http_request https://example.com"
        echo -e "         http_request https://example.com/api POST '{\"key\":\"value\"}'"
        return 1
    fi
    
    local url="$1"
    local method="${2:-GET}"
    local data="$3"
    
    echo -e "${YELLOW}Making $method request to $url...${RESET}"
    
    # Build curl command based on method and data
    local curl_cmd="curl -s -X $method"
    
    # Add data for POST and PUT requests
    if [[ "$method" == "POST" || "$method" == "PUT" ]] && [ -n "$data" ]; then
        curl_cmd+=" -H 'Content-Type: application/json' -d '$data'"
    fi
    
    # Add URL and response headers
    curl_cmd+=" -i '$url'"
    
    # Execute the request
    echo -e "${CYAN}Request:${RESET}"
    echo "$method $url"
    if [ -n "$data" ]; then
        echo "Data: $data"
    fi
    echo
    
    # Execute curl command and capture output
    local response=$(eval "$curl_cmd")
    
    # Split headers and body
    local header=$(echo "$response" | awk 'BEGIN{RS="\r\n\r\n"} {print $0; exit}')
    local body=$(echo "$response" | awk 'BEGIN{RS="\r\n\r\n"; ORS="\n\n"} {if (NR>1) print $0}')
    
    # Extract status code
    local status_code=$(echo "$header" | head -n 1 | awk '{print $2}')
    
    # Display response
    echo -e "${CYAN}Response:${RESET}"
    echo -e "${GREEN}Status: $status_code${RESET}"
    echo -e "${GREEN}Headers:${RESET}"
    echo "$header" | grep -v "^HTTP"
    echo
    
    # Pretty-print JSON response if possible
    if echo "$body" | grep -q "^\s*[{[]" && command -v jq &> /dev/null; then
        echo -e "${GREEN}Body (formatted):${RESET}"
        echo "$body" | jq .
    else
        echo -e "${GREEN}Body:${RESET}"
        echo "$body"
    fi
}

# URL shortener function
function shorten_url() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: shorten_url <long_url>${RESET}"
        return 1
    fi
    
    local long_url="$1"
    
    echo -e "${YELLOW}Shortening URL: $long_url${RESET}"
    
    # Use TinyURL API
    local short_url=$(curl -s "https://tinyurl.com/api-create.php?url=$long_url")
    
    if [ -n "$short_url" ]; then
        echo -e "${GREEN}Short URL: $short_url${RESET}"
        
        # Copy to clipboard if available
        if command -v xclip &> /dev/null; then
            echo -n "$short_url" | xclip -selection clipboard
            echo -e "${CYAN}(URL copied to clipboard)${RESET}"
        elif command -v pbcopy &> /dev/null; then
            echo -n "$short_url" | pbcopy
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
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: dl <url> [output_filename]${RESET}"
        return 1
    fi
    
    local url="$1"
    local output_file="$2"
    
    # If output filename is not specified, use the basename of the URL
    if [ -z "$output_file" ]; then
        output_file=$(basename "$url")
    fi
    
    echo -e "${YELLOW}Downloading $url to $output_file...${RESET}"
    
    if command -v wget &> /dev/null; then
        wget -c --show-progress -O "$output_file" "$url"
    elif command -v curl &> /dev/null; then
        curl -L -o "$output_file" --progress-bar "$url"
    else
        echo -e "${RED}Neither wget nor curl command found${RESET}"
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
    
    echo -e "${YELLOW}Extracting $type from $url...${RESET}"
    
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}curl command not found${RESET}"
        return 1
    fi
    
    case "$type" in
        text)
            echo -e "${CYAN}Extracting text content...${RESET}"
            curl -s "$url" | sed 's/<[^>]*>//g' | grep -v "^[[:space:]]*$" | head -n 50
            ;;
        links)
            echo -e "${CYAN}Extracting links...${RESET}"
            curl -s "$url" | grep -o '<a [^>]*href="[^"]*"[^>]*>' | sed 's/<a [^>]*href="\([^"]*\)"[^>]*>/\1/g' | sort | uniq
            ;;
        images)
            echo -e "${CYAN}Extracting image URLs...${RESET}"
            curl -s "$url" | grep -o '<img [^>]*src="[^"]*"[^>]*>' | sed 's/<img [^>]*src="\([^"]*\)"[^>]*>/\1/g'
            ;;
        title)
            echo -e "${CYAN}Extracting page title...${RESET}"
            curl -s "$url" | grep -o '<title>[^<]*</title>' | sed 's/<title>\(.*\)<\/title>/\1/g'
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
    
    echo -e "${GREEN}Starting HTTP server in $directory on port $port...${RESET}"
    
    if command -v python3 &> /dev/null; then
        (cd "$directory" && python3 -m http.server "$port")
    elif command -v python &> /dev/null; then
        (cd "$directory" && python -m SimpleHTTPServer "$port")
    else
        echo -e "${RED}Python not found${RESET}"
        return 1
    fi
}

# Function to fetch weather information
function weather() {
    local location=${1:-""}
    
    if [ -z "$location" ]; then
        # Try to get location by IP
        echo -e "${YELLOW}Getting weather for your current location...${RESET}"
    else
        echo -e "${YELLOW}Getting weather for $location...${RESET}"
    fi
    
    # Use wttr.in for weather
    curl -s "wttr.in/$location?q&n" | head -n 7
}

# Output module load message if verbose
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}Loaded: ${BOLD}Network Utilities Module${RESET}"
fi
