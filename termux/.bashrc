#!/bin/bash
# ===========================================
# Termux Auto-Start Configuration
# ===========================================
# Automatically starts Ubuntu proot-distro on Termux launch (per user preference)
# Author: Claude & Me
# Version: 1.0
# Last Updated: 2025-05-14

# ===========================================
# Environment Check
# ===========================================

# Check if we're already in Ubuntu environment (to prevent recursive launching)
if [ -n "$UBUNTU_LAUNCHED" ]; then
    return
fi

# ===========================================
# Auto-Launch Ubuntu
# ===========================================

# Set flag to prevent recursive launching
export UBUNTU_LAUNCHED=1

# Display welcome message
echo -e "\033[32m"
echo "  _______                                "
echo " |__   __|                               "
echo "    | | ___ _ __ _ __ ___  _   ___  __  "
echo "    | |/ _ \ '__| '_ \` _ \| | | \ \/ /  "
echo "    | |  __/ |  | | | | | | |_| |>  <   "
echo "    |_|\___|_|  |_| |_| |_|\__,_/_/\_\  "
echo "                                         "
echo -e "\033[35m  Starting Ubuntu...\033[0m"
echo

# Check if proot-distro is installed
if ! command -v proot-distro &> /dev/null; then
    echo -e "\033[31mError: proot-distro not found\033[0m"
    echo "Please install proot-distro with: pkg install proot-distro"
    return
fi

# Check if Ubuntu is installed in proot-distro
if ! proot-distro list | grep -q "ubuntu: installed"; then
    echo -e "\033[33mUbuntu not installed. Installing now...\033[0m"
    proot-distro install ubuntu
    
    if [ $? -ne 0 ]; then
        echo -e "\033[31mFailed to install Ubuntu\033[0m"
        return
    fi
fi

# Launch Ubuntu with login shell
echo -e "\033[32mLaunching Ubuntu...\033[0m"
proot-distro login ubuntu -- bash -l

# Exit Termux after Ubuntu session ends
exit
