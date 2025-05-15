#!/bin/bash
# ===========================================
# Installation Script
# ===========================================
# Installs the modular bashrc system for Termux Ubuntu via proot-distro
# Author: Claude & Me
# Version: 1.0
# Last Updated: 2025-05-14

# Terminal colors
RESET="\033[0m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
BOLD="\033[1m"

# ===========================================
# Helper Functions
# ===========================================

# Print section header
function print_header() {
    echo -e "\n${BOLD}${GREEN}=== $1 ===${RESET}\n"
}

# Print success message
function print_success() {
    echo -e "${GREEN}✓ $1${RESET}"
}

# Print info message
function print_info() {
    echo -e "${CYAN}ℹ $1${RESET}"
}

# Print warning message
function print_warning() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

# Print error message
function print_error() {
    echo -e "${RED}✗ $1${RESET}"
}

# Check if command exists
function command_exists() {
    command -v "$1" &> /dev/null
}

# ===========================================
# Environment Detection
# ===========================================

print_header "Environment Detection"

# Check if running in Termux
IN_TERMUX=0
if [ -d "/data/data/com.termux" ]; then
    IN_TERMUX=1
    print_success "Running in Termux environment"
else
    print_info "Not running in Termux"
fi

# Check if running in Ubuntu
IN_UBUNTU=0
if [ -f "/etc/lsb-release" ] && grep -q "Ubuntu" "/etc/lsb-release"; then
    IN_UBUNTU=1
    print_success "Running in Ubuntu environment"
    UBUNTU_VERSION=$(grep "DISTRIB_RELEASE" /etc/lsb-release | cut -d= -f2)
    print_info "Ubuntu version: $UBUNTU_VERSION"
else
    print_warning "Not running in Ubuntu. This script is designed for Ubuntu in Termux"
    echo -e "${YELLOW}Continue anyway? [y/N]${RESET}"
    read -r continue_anyway
    if [[ ! "$continue_anyway" =~ ^[yY]$ ]]; then
        print_info "Installation aborted"
        exit 1
    fi
fi

# ===========================================
# Backup Existing Configuration
# ===========================================

print_header "Backing Up Existing Configuration"

# Backup existing .bashrc
BACKUP_DIR="${HOME}/.bashrc_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

if [ -f "${HOME}/.bashrc" ]; then
    cp "${HOME}/.bashrc" "${BACKUP_DIR}/.bashrc.bak"
    print_success "Existing .bashrc backed up to ${BACKUP_DIR}/.bashrc.bak"
else
    print_info "No existing .bashrc found"
fi

# Backup existing .bashrc.d directory
if [ -d "${HOME}/.bashrc.d" ]; then
    cp -r "${HOME}/.bashrc.d" "${BACKUP_DIR}/.bashrc.d.bak"
    print_success "Existing .bashrc.d directory backed up to ${BACKUP_DIR}/.bashrc.d.bak"
else
    print_info "No existing .bashrc.d directory found"
fi

# ===========================================
# Package Installation
# ===========================================

print_header "Installing Required Packages"

# List of packages to install
PACKAGES="git curl wget python3 vim nano tree htop"

# Check if we can use apt
if command_exists apt; then
    print_info "Updating package lists..."
    apt update

    print_info "Installing required packages: $PACKAGES"
    apt install -y $PACKAGES
    
    if [ $? -eq 0 ]; then
        print_success "Required packages installed successfully"
    else
        print_warning "Some packages may not have installed correctly"
    fi
else
    print_warning "apt not found. Skipping package installation"
    print_info "You may need to manually install: $PACKAGES"
fi

# ===========================================
# Install Bashrc Modules
# ===========================================

print_header "Installing Bashrc Modules"

# Create directories
MODULE_DIR="${HOME}/.bashrc.d"
mkdir -p "$MODULE_DIR"
print_success "Created module directory: $MODULE_DIR"

# Copy module files
print_info "Copying module files..."

# Copy module-loader.sh first (it's critical)
if [ -f "module-loader.sh" ]; then
    cp "module-loader.sh" "${MODULE_DIR}/00-module-loader.sh"
    chmod +x "${MODULE_DIR}/00-module-loader.sh"
    print_success "Installed 00-module-loader.sh"
else
    print_error "Module loader file 'module-loader.sh' not found"
    exit 1
fi

# Map source files to destination module names
declare -A MODULE_MAP
MODULE_MAP=(
    ["core-settings.sh"]="01-core-settings.sh"
    ["prompt.sh"]="02-prompt.sh"
    ["storage-navigation.sh"]="03-storage-navigation.sh"
    ["file-operations.sh"]="04-file-operations.sh"
    ["git-integration.sh"]="05-git-integration.sh"
    ["python-development.sh"]="06-python-development.sh"
    ["system-management.sh"]="07-system-management.sh"
    ["productivity-tools.sh"]="08-productivity-tools.sh"
    ["network-utilities.sh"]="09-network-utilities.sh"
    ["custom-utilities.sh"]="10-custom-utilities.sh"
)

# Copy all module files
for source_file in "${!MODULE_MAP[@]}"; do
    dest_file="${MODULE_MAP[$source_file]}"
    
    if [ -f "$source_file" ]; then
        cp "$source_file" "${MODULE_DIR}/${dest_file}"
        chmod +x "${MODULE_DIR}/${dest_file}"
        print_success "Installed ${dest_file}"
    else
        print_warning "Source file '$source_file' not found, creating placeholder"
        
        # Create minimal placeholder with proper header
        echo "#!/bin/bash" > "${MODULE_DIR}/${dest_file}"
        echo "# Missing module: ${dest_file}" >> "${MODULE_DIR}/${dest_file}"
        echo "echo -e \"\${RED}Warning: ${dest_file} is a placeholder. Original module not found during installation.\${RESET}\"" >> "${MODULE_DIR}/${dest_file}"
        chmod +x "${MODULE_DIR}/${dest_file}"
    fi
done

print_success "All module files installed"

# ===========================================
# Install Main .bashrc
# ===========================================

print_header "Installing Main .bashrc"

# Create the main .bashrc file
cat > "${HOME}/.bashrc" << 'EOF'
#!/bin/bash
# ===========================================
# Main Bashrc Configuration for Termux Ubuntu
# ===========================================
# Modular Bash configuration for proot-distro Ubuntu environment in Termux
# Version: 3.0

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Set module directory path
export BASHRC_MODULES_PATH="${HOME}/.bashrc.d"

# Source the module loader if it exists
if [ -f "${BASHRC_MODULES_PATH}/00-module-loader.sh" ]; then
    source "${BASHRC_MODULES_PATH}/00-module-loader.sh"
else
    echo "Module loader not found. Running first-time setup..."
    
    # Create necessary directories
    mkdir -p "${BASHRC_MODULES_PATH}"
    
    # Show instructions for initial setup
    echo "Please copy your module files to: ${BASHRC_MODULES_PATH}"
    echo "Then run: source ~/.bashrc"
fi
EOF

print_success "Main .bashrc installed"

# ===========================================
# Termux Auto-Start Configuration
# ===========================================

if [ "$IN_TERMUX" -eq 1 ]; then
    print_header "Installing Termux Auto-start Configuration"
    
    # Create Termux's .bashrc for auto-starting Ubuntu
    cat > "${HOME}/.bashrc.termux" << 'EOF'
# Termux Auto-Start Configuration
# Automatically starts Ubuntu proot-distro on Termux launch

# Check if we're already in Ubuntu environment
if [ -n "$UBUNTU_LAUNCHED" ]; then
    return
fi

# Set flag to prevent recursive launching
export UBUNTU_LAUNCHED=1

# Display welcome message
echo -e "\033[32mStarting Ubuntu...\033[0m"

# Launch Ubuntu with login shell
proot-distro login ubuntu -- bash -l

# Exit Termux after Ubuntu session ends
exit
EOF
    
    print_success "Termux auto-start configuration created at ${HOME}/.bashrc.termux"
    print_info "To enable auto-start, run: cp ${HOME}/.bashrc.termux ${HOME}/.bashrc"
fi

# ===========================================
# Finishing Up
# ===========================================

print_header "Installation Complete"

print_success "Modular bashrc system installed successfully!"
print_info "To apply changes immediately, run: source ~/.bashrc"

# Show module commands
echo -e "\n${CYAN}Available module commands:${RESET}"
echo -e "${GREEN}lsmod${RESET}    - List available modules"
echo -e "${GREEN}reload${RESET}   - Reload all modules"
echo -e "${GREEN}bashrc${RESET}   - Edit a module"

# Show feature info
echo -e "\n${CYAN}Key features:${RESET}"
echo -e "- ${GREEN}sdcard${RESET}   - Quick access to shared storage"
echo -e "- ${GREEN}home${RESET}     - Return to root home directory"
echo -e "- ${GREEN}ts/te${RESET}    - Task timer start/stop"
echo -e "- ${GREEN}p${RESET}        - Project navigation"
echo -e "- ${GREEN}help${RESET}     - Show all available commands"

echo -e "\n${BOLD}${GREEN}Enjoy your enhanced Termux environment!${RESET}"
