#!/bin/bash
# ===========================================
# Python Development Environment
# ===========================================
# Tools for Python development with virtual environments, dependency management and project tools
# Author: Claude & Me
# Version: 1.1
# Last Updated: 2025-05-14

# ===========================================
# Configuration Options
# ===========================================

# User-configurable options
PYTHON_DEFAULT_VERSION=${PYTHON_DEFAULT_VERSION:-"python3"}  # Default Python interpreter
PYTHON_VENV_DIR=${PYTHON_VENV_DIR:-"venv"}                  # Default virtual environment directory
PYTHON_AUTO_ACTIVATE=${PYTHON_AUTO_ACTIVATE:-1}             # Auto-activate virtual environment (0=off, 1=on)
PYTHON_COMMON_PACKAGES=${PYTHON_COMMON_PACKAGES:-"pytest black flake8"}  # Common dev packages
PYTHON_PREFER_PIPENV=${PYTHON_PREFER_PIPENV:-0}             # Prefer pipenv over venv (0=off, 1=on)
PYTHON_PACKAGE_MANAGER=${PYTHON_PACKAGE_MANAGER:-"pip"}      # pip, pipenv, or poetry

# ===========================================
# Python Command Aliases
# ===========================================

# Python shortcuts
alias p3="python3"
alias py="python3"
alias pip="pip3"
alias pipi="pip install"
alias pipipr="pip install -r requirements.txt"
alias pipup="pip install --upgrade pip"
alias piplist="pip list"
alias pipoutdated="pip list --outdated"
alias pypath="python3 -c 'import sys; print(sys.path)'"

# Python project utilities
alias pyc="python3 -m compileall"
alias pyclean="find . -name \"*.pyc\" -delete"
alias pytest="python3 -m pytest"
alias flake8="python3 -m flake8"
alias pylint="python3 -m pylint"

# Format code with Black if available
if command -v black &> /dev/null; then
    alias black="python3 -m black"
fi

# ===========================================
# Python Environment Detection
# ===========================================

# Detect Python versions and tools
function detect_python_environment() {
    # Check Python versions
    if command -v python3 &> /dev/null; then
        PYTHON3_VERSION=$(python3 --version 2>&1)
        PYTHON3_AVAILABLE=1
    else
        PYTHON3_AVAILABLE=0
    fi
    
    if command -v python &> /dev/null; then
        PYTHON_VERSION=$(python --version 2>&1)
        PYTHON_AVAILABLE=1
    else
        PYTHON_AVAILABLE=0
    fi
    
    # Check for pip
    if command -v pip3 &> /dev/null; then
        PIP3_VERSION=$(pip3 --version 2>&1)
        PIP3_AVAILABLE=1
    else
        PIP3_AVAILABLE=0
    fi
    
    if command -v pip &> /dev/null; then
        PIP_VERSION=$(pip --version 2>&1)
        PIP_AVAILABLE=1
    else
        PIP_AVAILABLE=0
    fi
    
    # Check for virtual environment tools
    if python3 -c "import venv" &> /dev/null; then
        VENV_AVAILABLE=1
    else
        VENV_AVAILABLE=0
    fi
    
    if command -v pipenv &> /dev/null; then
        PIPENV_AVAILABLE=1
    else
        PIPENV_AVAILABLE=0
    fi
    
    if command -v poetry &> /dev/null; then
        POETRY_AVAILABLE=1
    else
        POETRY_AVAILABLE=0
    fi
    
    # Check for active virtual environment
    if [ -n "$VIRTUAL_ENV" ]; then
        VENV_ACTIVE=1
        VENV_NAME=$(basename "$VIRTUAL_ENV")
    else
        VENV_ACTIVE=0
        VENV_NAME=""
    fi
    
    # Check for conda
    if command -v conda &> /dev/null; then
        CONDA_AVAILABLE=1
        if [ -n "$CONDA_DEFAULT_ENV" ]; then
            CONDA_ACTIVE=1
            CONDA_ENV_NAME="$CONDA_DEFAULT_ENV"
        else
            CONDA_ACTIVE=0
            CONDA_ENV_NAME=""
        fi
    else
        CONDA_AVAILABLE=0
        CONDA_ACTIVE=0
        CONDA_ENV_NAME=""
    fi
}

# Initialize Python environment detection
detect_python_environment

# ===========================================
# Virtual Environment Management
# ===========================================

# Check Python version and modules
function pycheck() {
    # Re-detect environment to ensure we have current info
    detect_python_environment
    
    echo -e "${YELLOW}Python environment information:${RESET}"
    
    # Check Python version
    if [ "$PYTHON3_AVAILABLE" -eq 1 ]; then
        echo -e "${GREEN}Python $(python3 --version 2>&1)${RESET}"
    else
        echo -e "${RED}Python 3 not found${RESET}"
    fi
    
    # Check pip
    if [ "$PIP3_AVAILABLE" -eq 1 ]; then
        echo -e "${GREEN}$(pip3 --version)${RESET}"
    else
        echo -e "${RED}pip3 not found${RESET}"
    fi
    
    # Check venv module
    if [ "$VENV_AVAILABLE" -eq 1 ]; then
        echo -e "${GREEN}venv module available${RESET}"
    else
        echo -e "${RED}venv module not available${RESET}"
        echo -e "${YELLOW}Try installing python3-venv package${RESET}"
    fi
    
    # Check pipenv
    if [ "$PIPENV_AVAILABLE" -eq 1 ]; then
        echo -e "${GREEN}pipenv available$(pipenv --version 2>&1)${RESET}"
    else
        echo -e "${YELLOW}pipenv not found${RESET}"
        echo -e "${CYAN}Install with: pip install pipenv${RESET}"
    fi
    
    # Check poetry
    if [ "$POETRY_AVAILABLE" -eq 1 ]; then
        echo -e "${GREEN}poetry available$(poetry --version 2>&1)${RESET}"
    else
        echo -e "${YELLOW}poetry not found${RESET}"
        echo -e "${CYAN}Install with: pip install poetry${RESET}"
    fi
    
    # Check if in virtual environment
    if [ "$VENV_ACTIVE" -eq 1 ]; then
        echo -e "${GREEN}Active virtual environment: $VENV_NAME${RESET}"
        echo -e "${CYAN}Path: $VIRTUAL_ENV${RESET}"
        
        # Check Python version in venv
        echo -e "${GREEN}Venv Python: $(python --version 2>&1)${RESET}"
        
        # List installed packages if in venv
        echo -e "${YELLOW}Top packages installed in this environment:${RESET}"
        pip list | grep -v "^Package" | grep -v "^------" | sort | head -n 10
        
        # Show count if more than 10
        local pkg_count=$(pip list | grep -v "^Package" | grep -v "^------" | wc -l)
        if [ "$pkg_count" -gt 10 ]; then
            echo -e "${YELLOW}... and $((pkg_count - 10)) more packages${RESET}"
        fi
    elif [ "$CONDA_ACTIVE" -eq 1 ]; then
        echo -e "${GREEN}Active conda environment: $CONDA_ENV_NAME${RESET}"
        
        # List conda packages
        if command -v conda &> /dev/null; then
            echo -e "${YELLOW}Top packages in conda environment:${RESET}"
            conda list | head -n 10
            
            # Show count if more than 10
            local conda_pkg_count=$(conda list | wc -l)
            if [ "$conda_pkg_count" -gt 12 ]; then
                echo -e "${YELLOW}... and $((conda_pkg_count - 12)) more packages${RESET}"
            fi
        fi
    else
        echo -e "${YELLOW}No active virtual environment${RESET}"
    fi
    
    # Check for requirements.txt
    if [ -f "requirements.txt" ]; then
        echo -e "${CYAN}Found requirements.txt with $(wc -l < requirements.txt) packages${RESET}"
    fi
    
    # Check for pyproject.toml
    if [ -f "pyproject.toml" ]; then
        echo -e "${CYAN}Found pyproject.toml (Poetry/PEP 518 project)${RESET}"
    fi
    
    # Check for setup.py
    if [ -f "setup.py" ]; then
        echo -e "${CYAN}Found setup.py (standard Python package)${RESET}"
    fi
    
    # Check for Pipfile
    if [ -f "Pipfile" ]; then
        echo -e "${CYAN}Found Pipfile (Pipenv project)${RESET}"
    fi
}

# Virtual environment functions with better error handling
function activate_venv() {
    local venv_dirs=(
        "venv"
        ".venv"
        "env"
        ".env"
        "$HOME/venv"
        "./venv"
        "./myenv"
    )
    
    # First, check the specified directory if provided
    if [ -n "$1" ]; then
        if [ -d "$1" ] && [ -f "$1/bin/activate" ]; then
            echo -e "${GREEN}Activating virtual environment: $1${RESET}"
            # shellcheck source=/dev/null
            source "$1/bin/activate"
            detect_python_environment  # Update environment detection
            pycheck
            return 0
        else
            echo -e "${RED}No valid virtual environment found at $1${RESET}"
        fi
    fi
    
    # Otherwise, try to find a virtual environment in the current directory
    for venv in "${venv_dirs[@]}"; do
        if [ -d "$venv" ] && [ -f "$venv/bin/activate" ]; then
            echo -e "${GREEN}Activating virtual environment: $venv${RESET}"
            # shellcheck source=/dev/null
            source "$venv/bin/activate"
            detect_python_environment  # Update environment detection
            pycheck
            return 0
        fi
    done
    
    # Check for Pipenv or Poetry project
    if [ -f "Pipfile" ] && [ "$PIPENV_AVAILABLE" -eq 1 ]; then
        echo -e "${GREEN}Pipenv project detected. Activating...${RESET}"
        eval "$(pipenv shell)"
        return 0
    elif [ -f "pyproject.toml" ] && [ "$POETRY_AVAILABLE" -eq 1 ]; then
        echo -e "${GREEN}Poetry project detected. Activating...${RESET}"
        poetry shell
        return 0
    fi
    
    echo -e "${YELLOW}No virtual environment found. Checking for requirements.txt...${RESET}"
    
    if [ -f "requirements.txt" ]; then
        echo -e "${YELLOW}Found requirements.txt. Create a virtual environment? [y/N]${RESET}"
        read -r confirm
        
        if [[ "$confirm" =~ ^[yY]$ ]]; then
            echo -e "${GREEN}Creating virtual environment 'venv'...${RESET}"
            python3 -m venv venv
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Virtual environment created successfully!${RESET}"
                # shellcheck source=/dev/null
                source venv/bin/activate
                echo -e "${YELLOW}Installing requirements...${RESET}"
                pip install -r requirements.txt
                detect_python_environment  # Update environment detection
                pycheck
                return 0
            else
                echo -e "${RED}Failed to create virtual environment.${RESET}"
                
                # Check if python3-venv is installed
                if ! python3 -c "import venv" &> /dev/null; then
                    echo -e "${YELLOW}The venv module is not available. Install it? [y/N]${RESET}"
                    read -r install_venv
                    
                    if [[ "$install_venv" =~ ^[yY]$ ]]; then
                        sudo apt-get update
                        sudo apt-get install -y python3-venv
                        
                        if [ $? -eq 0 ]; then
                            echo -e "${GREEN}python3-venv installed. Retrying...${RESET}"
                            python3 -m venv venv
                            
                            if [ $? -eq 0 ]; then
                                echo -e "${GREEN}Virtual environment created successfully!${RESET}"
                                # shellcheck source=/dev/null
                                source venv/bin/activate
                                echo -e "${YELLOW}Installing requirements...${RESET}"
                                pip install -r requirements.txt
                                detect_python_environment  # Update environment detection
                                pycheck
                                return 0
                            else
                                echo -e "${RED}Failed to create virtual environment.${RESET}"
                                return 1
                            fi
                        else
                            echo -e "${RED}Failed to install python3-venv.${RESET}"
                            return 1
                        fi
                    fi
                fi
                
                return 1
            fi
        fi
    fi
    
    echo -e "${RED}No virtual environment found${RESET}"
    return 1
}

# Create and activate a new virtual environment
function create_venv() {
    local venv_name=${1:-"venv"}
    
    # Check if Python and venv are available
    if [ "$PYTHON3_AVAILABLE" -eq 0 ]; then
        echo -e "${RED}Error: Python 3 not found${RESET}"
        return 1
    fi
    
    if [ "$VENV_AVAILABLE" -eq 0 ] && [ "$PIPENV_AVAILABLE" -eq 0 ] && [ "$POETRY_AVAILABLE" -eq 0 ]; then
        echo -e "${RED}Error: No virtual environment tools found${RESET}"
        echo -e "${YELLOW}Please install venv, pipenv, or poetry first${RESET}"
        echo -e "${CYAN}venv:   sudo apt install python3-venv${RESET}"
        echo -e "${CYAN}pipenv: pip install pipenv${RESET}"
        echo -e "${CYAN}poetry: pip install poetry${RESET}"
        return 1
    fi
    
    # Determine which virtual environment tool to use
    local venv_tool="venv"  # Default to venv
    
    if [ "$PYTHON_PREFER_PIPENV" -eq 1 ] && [ "$PIPENV_AVAILABLE" -eq 1 ]; then
        venv_tool="pipenv"
    elif [ "$PYTHON_PACKAGE_MANAGER" = "poetry" ] && [ "$POETRY_AVAILABLE" -eq 1 ]; then
        venv_tool="poetry"
    elif [ "$PYTHON_PACKAGE_MANAGER" = "pipenv" ] && [ "$PIPENV_AVAILABLE" -eq 1 ]; then
        venv_tool="pipenv"
    fi
    
    # Ask user to confirm or change tool if there are multiple options
    if [ "$VENV_AVAILABLE" -eq 1 ] && [ "$PIPENV_AVAILABLE" -eq 1 ] || [ "$POETRY_AVAILABLE" -eq 1 ]; then
        echo -e "${YELLOW}Available virtual environment tools:${RESET}"
        echo -e "1. ${CYAN}venv${RESET} (standard library, isolated environments)"
        
        if [ "$PIPENV_AVAILABLE" -eq 1 ]; then
            echo -e "2. ${CYAN}pipenv${RESET} (dependency management + virtual environments)"
        fi
        
        if [ "$POETRY_AVAILABLE" -eq 1 ]; then
            echo -e "3. ${CYAN}poetry${RESET} (advanced dependency management + packaging)"
        fi
        
        echo -e "${YELLOW}Select tool to create environment [default: $venv_tool]:${RESET}"
        read -r tool_selection
        
        case "$tool_selection" in
            1)
                venv_tool="venv"
                ;;
            2)
                if [ "$PIPENV_AVAILABLE" -eq 1 ]; then
                    venv_tool="pipenv"
                else
                    echo -e "${RED}pipenv not available${RESET}"
                fi
                ;;
            3)
                if [ "$POETRY_AVAILABLE" -eq 1 ]; then
                    venv_tool="poetry"
                else
                    echo -e "${RED}poetry not available${RESET}"
                fi
                ;;
        esac
    fi
    
    echo -e "${GREEN}Creating Python environment using $venv_tool...${RESET}"
    
    if [ "$venv_tool" = "venv" ]; then
        # Using standard venv
        if [ -d "$venv_name" ]; then
            echo -e "${YELLOW}Directory '$venv_name' already exists. Overwrite? [y/N]${RESET}"
            read -r confirm
            
            if [[ ! "$confirm" =~ ^[yY]$ ]]; then
                echo -e "${YELLOW}Operation cancelled.${RESET}"
                return 1
            fi
            
            rm -rf "$venv_name"
        fi
        
        echo -e "${GREEN}Creating virtual environment '$venv_name'...${RESET}"
        python3 -m venv "$venv_name"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Virtual environment created successfully!${RESET}"
            # shellcheck source=/dev/null
            source "$venv_name/bin/activate"
            
            # Upgrade pip
            echo -e "${YELLOW}Upgrading pip...${RESET}"
            pip install --upgrade pip
            
            echo -e "${GREEN}Python version: $(python3 --version)${RESET}"
            echo -e "${GREEN}Pip version: $(pip --version)${RESET}"
            
            # Install common packages if requested
            echo -e "${YELLOW}Install common development packages? [y/N]${RESET}"
            read -r confirm
            
            if [[ "$confirm" =~ ^[yY]$ ]]; then
                echo -e "${YELLOW}Select package set:${RESET}"
                echo "1. Basic (pytest)"
                echo "2. Development (pytest, black, flake8)"
                echo "3. Data Science (numpy, pandas, matplotlib)"
                echo "4. Web (Flask, requests)"
                echo "5. All of the above"
                read -p "Enter your choice [1-5]: " choice
                
                case $choice in
                    1)
                        echo -e "${GREEN}Installing basic packages...${RESET}"
                        pip install pytest
                        ;;
                    2)
                        echo -e "${GREEN}Installing development packages...${RESET}"
                        pip install pytest black flake8
                        ;;
                    3)
                        echo -e "${GREEN}Installing data science packages...${RESET}"
                        pip install numpy pandas matplotlib
                        ;;
                    4)
                        echo -e "${GREEN}Installing web packages...${RESET}"
                        pip install flask requests
                        ;;
                    5)
                        echo -e "${GREEN}Installing all packages...${RESET}"
                        pip install pytest black flake8 numpy pandas matplotlib flask requests
                        ;;
                    *)
                        echo -e "${YELLOW}Invalid choice. No packages installed.${RESET}"
                        ;;
                esac
                
                echo -e "${GREEN}Packages installed successfully!${RESET}"
            fi
            
            detect_python_environment  # Update environment detection
            return 0
        else
            echo -e "${RED}Failed to create virtual environment.${RESET}"
            
            # Check if python3-venv is installed
            if ! python3 -c "import venv" &> /dev/null; then
                echo -e "${YELLOW}The venv module is not available. Install it? [y/N]${RESET}"
                read -r install_venv
                
                if [[ "$install_venv" =~ ^[yY]$ ]]; then
                    sudo apt-get update
                    sudo apt-get install -y python3-venv
                    
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}python3-venv installed. Retrying...${RESET}"
                        return create_venv "$venv_name"
                    else
                        echo -e "${RED}Failed to install python3-venv.${RESET}"
                        return 1
                    fi
                fi
            fi
            
            return 1
        fi
    elif [ "$venv_tool" = "pipenv" ]; then
        # Using Pipenv
        echo -e "${GREEN}Creating Pipenv environment...${RESET}"
        
        # Check if Pipfile exists
        if [ -f "Pipfile" ]; then
            echo -e "${YELLOW}Pipfile already exists. Update it? [y/N]${RESET}"
            read -r confirm
            
            if [[ ! "$confirm" =~ ^[yY]$ ]]; then
                echo -e "${YELLOW}Operation cancelled.${RESET}"
                return 1
            fi
        fi
        
        # Initialize Pipenv in the current directory
        pipenv --python 3
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Pipenv environment created successfully!${RESET}"
            
            # Install common packages if requested
            echo -e "${YELLOW}Install common development packages? [y/N]${RESET}"
            read -r confirm
            
            if [[ "$confirm" =~ ^[yY]$ ]]; then
                echo -e "${YELLOW}Select package set:${RESET}"
                echo "1. Basic (pytest)"
                echo "2. Development (pytest, black, flake8)"
                echo "3. Data Science (numpy, pandas, matplotlib)"
                echo "4. Web (Flask, requests)"
                echo "5. All of the above"
                read -p "Enter your choice [1-5]: " choice
                
                case $choice in
                    1)
                        echo -e "${GREEN}Installing basic packages...${RESET}"
                        pipenv install pytest --dev
                        ;;
                    2)
                        echo -e "${GREEN}Installing development packages...${RESET}"
                        pipenv install pytest black flake8 --dev
                        ;;
                    3)
                        echo -e "${GREEN}Installing data science packages...${RESET}"
                        pipenv install numpy pandas matplotlib
                        ;;
                    4)
                        echo -e "${GREEN}Installing web packages...${RESET}"
                        pipenv install flask requests
                        ;;
                    5)
                        echo -e "${GREEN}Installing all packages...${RESET}"
                        pipenv install pytest black flake8 --dev
                        pipenv install numpy pandas matplotlib flask requests
                        ;;
                    *)
                        echo -e "${YELLOW}Invalid choice. No packages installed.${RESET}"
                        ;;
                esac
                
                echo -e "${GREEN}Packages installed successfully!${RESET}"
            fi
            
            # Activate environment
            echo -e "${YELLOW}Activate the environment now? [Y/n]${RESET}"
            read -r activate_confirm
            
            if [[ ! "$activate_confirm" =~ ^[nN]$ ]]; then
                pipenv shell
            else
                echo -e "${CYAN}You can activate the environment later with 'pipenv shell'${RESET}"
            fi
            
            detect_python_environment  # Update environment detection
            return 0
        else
            echo -e "${RED}Failed to create Pipenv environment.${RESET}"
            return 1
        fi
    elif [ "$venv_tool" = "poetry" ]; then
        # Using Poetry
        echo -e "${GREEN}Creating Poetry environment...${RESET}"
        
        # Check if pyproject.toml exists
        if [ -f "pyproject.toml" ]; then
            echo -e "${YELLOW}pyproject.toml already exists. Update it? [y/N]${RESET}"
            read -r confirm
            
            if [[ ! "$confirm" =~ ^[yY]$ ]]; then
                echo -e "${YELLOW}Operation cancelled.${RESET}"
                return 1
            fi
        fi
        
        # Initialize Poetry project
        poetry init
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Poetry project initialized successfully!${RESET}"
            
            # Create virtual environment
            poetry env use python3
            
            # Install common packages if requested
            echo -e "${YELLOW}Install common development packages? [y/N]${RESET}"
            read -r confirm
            
            if [[ "$confirm" =~ ^[yY]$ ]]; then
                echo -e "${YELLOW}Select package set:${RESET}"
                echo "1. Basic (pytest)"
                echo "2. Development (pytest, black, flake8)"
                echo "3. Data Science (numpy, pandas, matplotlib)"
                echo "4. Web (Flask, requests)"
                echo "5. All of the above"
                read -p "Enter your choice [1-5]: " choice
                
                case $choice in
                    1)
                        echo -e "${GREEN}Installing basic packages...${RESET}"
                        poetry add pytest --group dev
                        ;;
                    2)
                        echo -e "${GREEN}Installing development packages...${RESET}"
                        poetry add pytest black flake8 --group dev
                        ;;
                    3)
                        echo -e "${GREEN}Installing data science packages...${RESET}"
                        poetry add numpy pandas matplotlib
                        ;;
                    4)
                        echo -e "${GREEN}Installing web packages...${RESET}"
                        poetry add flask requests
                        ;;
                    5)
                        echo -e "${GREEN}Installing all packages...${RESET}"
                        poetry add pytest black flake8 --group dev
                        poetry add numpy pandas matplotlib flask requests
                        ;;
                    *)
                        echo -e "${YELLOW}Invalid choice. No packages installed.${RESET}"
                        ;;
                esac
                
                echo -e "${GREEN}Packages installed successfully!${RESET}"
            fi
            
            # Activate environment
            echo -e "${YELLOW}Activate the environment now? [Y/n]${RESET}"
            read -r activate_confirm
            
            if [[ ! "$activate_confirm" =~ ^[nN]$ ]]; then
                poetry shell
            else
                echo -e "${CYAN}You can activate the environment later with 'poetry shell'${RESET}"
            fi
            
            detect_python_environment  # Update environment detection
            return 0
        else
            echo -e "${RED}Failed to create Poetry environment.${RESET}"
            return 1
        fi
    else
        echo -e "${RED}Unknown virtual environment tool: $venv_tool${RESET}"
        return 1
    fi
}

# Auto-detect and activate virtual environment if in project directory
function auto_activate_venv() {
    if [ "$PYTHON_AUTO_ACTIVATE" -ne 1 ]; then
        return 0
    fi
    
    # Skip if already in a virtual environment
    if [ -n "$VIRTUAL_ENV" ] || [ -n "$CONDA_DEFAULT_ENV" ]; then
        return 0
    fi
    
    local venv_dirs=(
        "venv"
        ".venv"
        "env"
        ".env"
    )
    
    # Look for a virtual environment in the current directory
    for venv in "${venv_dirs[@]}"; do
        if [ -d "$venv" ] && [ -f "$venv/bin/activate" ]; then
            echo -e "${CYAN}Found virtual environment: $venv. Activating...${RESET}"
            # shellcheck source=/dev/null
            source "$venv/bin/activate"
            detect_python_environment  # Update environment detection
            return 0
        fi
    done
    
    # Look for other project files
    if [ -f "Pipfile" ] && [ "$PIPENV_AVAILABLE" -eq 1 ]; then
        echo -e "${CYAN}Found Pipfile. Activating with pipenv...${RESET}"
        pipenv shell
        return 0
    elif [ -f "pyproject.toml" ] && [ "$POETRY_AVAILABLE" -eq 1 ]; then
        echo -e "${CYAN}Found pyproject.toml. Activating with poetry...${RESET}"
        poetry shell
        return 0
    fi
    
    return 1
}

# Function to install common development tools in an active venv
function pysetup() {
    if [ -z "$VIRTUAL_ENV" ] && [ -z "$CONDA_DEFAULT_ENV" ]; then
        echo -e "${RED}No active virtual environment detected.${RESET}"
        echo -e "${YELLOW}Activate a virtual environment first with: activate_venv${RESET}"
        return 1
    fi
    
    echo -e "${YELLOW}Installing development tools in virtual environment...${RESET}"
    
    # Upgrade pip first
    pip install --upgrade pip
    
    # Install common tools
    pip install pytest black flake8 pylint pytest-cov
    
    # Ask about more tools
    echo -e "${YELLOW}Install additional tools? [y/N]${RESET}"
    read -r confirm
    
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        echo -e "${YELLOW}Select additional tools:${RESET}"
        echo "1. Web development (Flask, requests)"
        echo "2. Data science (numpy, pandas, matplotlib)"
        echo "3. Task management (invoke, click)"
        echo "4. Documentation (sphinx, mkdocs)"
        echo "5. All of the above"
        read -p "Enter your choice [1-5]: " choice
        
        case $choice in
            1)
                pip install flask requests
                ;;
            2)
                pip install numpy pandas matplotlib seaborn
                ;;
            3)
                pip install invoke click
                ;;
            4)
                pip install sphinx mkdocs
                ;;
            5)
                pip install flask requests numpy pandas matplotlib seaborn invoke click sphinx mkdocs
                ;;
            *)
                echo -e "${YELLOW}Invalid choice. No additional tools installed.${RESET}"
                ;;
        esac
    fi
    
    # Create .vscode directory and settings if applicable
    if [ -d ".vscode" ] || command -v code &> /dev/null; then
        echo -e "${YELLOW}Configure VSCode settings for this project? [y/N]${RESET}"
        read -r vscode_confirm
        
        if [[ "$vscode_confirm" =~ ^[yY]$ ]]; then
            mkdir -p .vscode
            
            # Create settings.json
            cat > .vscode/settings.json << EOF
{
    "python.defaultInterpreterPath": "${VIRTUAL_ENV}/bin/python",
    "python.linting.enabled": true,
    "python.linting.pylintEnabled": true,
    "python.linting.flake8Enabled": true,
    "python.formatting.provider": "black",
    "editor.formatOnSave": true,
    "python.testing.pytestEnabled": true,
    "python.testing.unittestEnabled": false,
    "python.testing.nosetestsEnabled": false,
    "python.testing.pytestArgs": [
        "tests"
    ]
}
EOF
            echo -e "${GREEN}VSCode settings created.${RESET}"
        fi
    fi
    
    echo -e "${GREEN}Development environment setup complete!${RESET}"
    
    # Final report
    pycheck
}

# Virtual environment aliases
alias a="activate_venv"
alias d="deactivate 2>/dev/null || echo 'No active virtual environment'"
alias newv="create_venv"
alias pys="pysetup"

# ===========================================
# Python Project Management
# ===========================================

# Create a new Python project
function pyproject() {
    local project_name="$1"
    
    if [ -z "$project_name" ]; then
        echo -e "${RED}Usage: pyproject <project_name>${RESET}"
        return 1
    fi
    
    if [ -d "$project_name" ]; then
        echo -e "${RED}Directory '$project_name' already exists${RESET}"
        return 1
    fi
    
    echo -e "${GREEN}Creating Python project: $project_name${RESET}"
    
    # Ask about project structure
    echo -e "${YELLOW}Select project structure:${RESET}"
    echo "1. Simple (single module)"
    echo "2. Standard (src layout with tests)"
    echo "3. Full (src, tests, docs, examples)"
    read -p "Enter your choice [1-3]: " structure
    
    # Ask about packaging system
    echo -e "${YELLOW}Select packaging system:${RESET}"
    echo "1. setuptools (traditional setup.py)"
    echo "2. poetry (modern dependency management)"
    echo "3. pipenv (simpler dependency management)"
    echo "4. plain (no packaging setup)"
    read -p "Enter your choice [1-4]: " packaging
    
    # Create the selected structure
    case $structure in
        1)
            # Simple structure
            mkdir -p "$project_name"
            touch "$project_name/__init__.py"
            touch "$project_name/main.py"
            
            # Create simple main.py
            cat > "$project_name/main.py" << EOF
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
$project_name - A simple Python project.
"""


def main():
    """Main entry point for the application."""
    print("Hello from $project_name!")


if __name__ == "__main__":
    main()
EOF
            
            # Create simple README
            cat > "$project_name/README.md" << EOF
# $project_name

A simple Python project.

## Usage

\`\`\`python
from $project_name import main
\`\`\`
EOF
            ;;
            
        2)
            # Standard structure
            mkdir -p "$project_name"/{src/"$project_name",tests}
            
            # Create basic module files
            touch "$project_name/src/$project_name/__init__.py"
            cat > "$project_name/src/$project_name/main.py" << EOF
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Main module for $project_name.
"""


def greet(name="World"):
    """Return a greeting message."""
    return f"Hello, {name}!"


def main():
    """Main entry point for the application."""
    print(greet())


if __name__ == "__main__":
    main()
EOF
            
            # Create test files
            touch "$project_name/tests/__init__.py"
            cat > "$project_name/tests/test_main.py" << EOF
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Tests for the main module.
"""
import pytest
from $project_name.main import greet


def test_greet():
    """Test the greet function."""
    assert greet() == "Hello, World!"
    assert greet("Test") == "Hello, Test!"
EOF
            
            # Create README.md
            cat > "$project_name/README.md" << EOF
# $project_name

Description of your project.

## Installation

\`\`\`bash
pip install -e .
\`\`\`

## Usage

\`\`\`python
from $project_name import main
print(main.greet("Your Name"))
\`\`\`

## Development

\`\`\`bash
# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install development dependencies
pip install -e ".[dev]"
\`\`\`

## Testing

\`\`\`bash
pytest
\`\`\`
EOF
            
            # Create requirements.txt
            cat > "$project_name/requirements.txt" << EOF
# Project dependencies
pytest>=7.0.0
black>=23.0.0
flake8>=6.0.0
EOF
            ;;
            
        3)
            # Full structure
            mkdir -p "$project_name"/{src/"$project_name",tests,docs,examples,scripts}
            
            # Create basic module files
            touch "$project_name/src/$project_name/__init__.py"
            cat > "$project_name/src/$project_name/main.py" << EOF
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Main module for $project_name.
"""


def greet(name="World"):
    """Return a greeting message."""
    return f"Hello, {name}!"


def main():
    """Main entry point for the application."""
    print(greet())


if __name__ == "__main__":
    main()
EOF
            
            # Create test files
            touch "$project_name/tests/__init__.py"
            cat > "$project_name/tests/test_main.py" << EOF
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Tests for the main module.
"""
import pytest
from $project_name.main import greet


def test_greet():
    """Test the greet function."""
    assert greet() == "Hello, World!"
    assert greet("Test") == "Hello, Test!"
EOF
            
            # Create example
            cat > "$project_name/examples/example.py" << EOF
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Example usage of $project_name.
"""
from $project_name.main import greet

print(greet("Example User"))
EOF
            
            # Create docs
            touch "$project_name/docs/index.md"
            
            # Create pyproject.toml
            cat > "$project_name/pyproject.toml" << EOF
[build-system]
requires = ["setuptools>=42", "wheel"]
build-backend = "setuptools.build_meta"

[tool.black]
line-length = 88
target-version = ['py38']
include = '\.pyi?$'

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = "test_*.py"
EOF
            
            # Create README.md
            cat > "$project_name/README.md" << EOF
# $project_name

Description of your project.

## Features

- Feature 1
- Feature 2

## Installation

\`\`\`bash
pip install -e .
\`\`\`

## Usage

\`\`\`python
from $project_name import main
print(main.greet("Your Name"))
\`\`\`

## Development

\`\`\`bash
# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install development dependencies
pip install -e ".[dev]"

# Run tests
pytest

# Format code
black src tests

# Run type checking
mypy src
\`\`\`

## Documentation

To build the documentation:

\`\`\`bash
pip install -e ".[docs]"
cd docs
mkdocs serve
\`\`\`
EOF
            
            # Create requirements.txt
            cat > "$project_name/requirements.txt" << EOF
# Project dependencies

# Development dependencies
pytest>=7.0.0
black>=23.0.0
flake8>=6.0.0
mypy>=1.0.0
pytest-cov>=4.0.0

# Documentation dependencies
mkdocs>=1.4.0
mkdocs-material>=9.0.0
EOF
            
            # Create mkdocs.yml
            cat > "$project_name/mkdocs.yml" << EOF
site_name: $project_name Documentation
theme:
  name: material
  palette:
    primary: indigo
    accent: indigo
markdown_extensions:
  - pymdownx.highlight:
      anchor_linenums: true
  - pymdownx.superfences
  - pymdownx.inlinehilite
  - pymdownx.tabbed
  - pymdownx.tasklist:
      custom_checkbox: true
nav:
  - Home: index.md
EOF
            
            # Create example documentation
            cat > "$project_name/docs/index.md" << EOF
# Welcome to $project_name

This is the documentation for $project_name.

## Installation

\`\`\`bash
pip install $project_name
\`\`\`

## Basic Usage

\`\`\`python
from $project_name import main

# Your code here
\`\`\`
EOF
            ;;
            
        *)
            echo -e "${RED}Invalid choice. Using standard structure.${RESET}"
            mkdir -p "$project_name"/{src/"$project_name",tests}
            touch "$project_name/src/$project_name/__init__.py"
            touch "$project_name/src/$project_name/main.py"
            touch "$project_name/tests/__init__.py"
            touch "$project_name/tests/test_main.py"
            ;;
    esac
    
    # Create packaging files based on selection
    case $packaging in
        1)
            # setuptools
            cat > "$project_name/setup.py" << EOF
from setuptools import setup, find_packages

setup(
    name="$project_name",
    version="0.1.0",
    description="A Python project",
    author="Your Name",
    author_email="your.email@example.com",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    install_requires=[],
    extras_require={
        "dev": [
            "pytest>=7.0.0",
            "black>=23.0.0",
            "flake8>=6.0.0",
            "mypy>=1.0.0",
            "pytest-cov>=4.0.0",
        ],
        "docs": [
            "mkdocs>=1.4.0",
            "mkdocs-material>=9.0.0",
        ],
    },
    python_requires=">=3.8",
)
EOF
            ;;
        2)
            # poetry
            cat > "$project_name/pyproject.toml" << EOF
[tool.poetry]
name = "$project_name"
version = "0.1.0"
description = "A Python project"
authors = ["Your Name <your.email@example.com>"]
readme = "README.md"
packages = [{include = "$project_name", from = "src"}]

[tool.poetry.dependencies]
python = "^3.8"

[tool.poetry.dev-dependencies]
pytest = "^7.0.0"
black = "^23.0.0"
flake8 = "^6.0.0"
mypy = "^1.0.0"
pytest-cov = "^4.0.0"

[tool.poetry.group.docs]
optional = true

[tool.poetry.group.docs.dependencies]
mkdocs = "^1.4.0"
mkdocs-material = "^9.0.0"

[build-system]
requires = ["poetry-core>=1.0.0"]
build-backend = "poetry.core.masonry.api"

[tool.black]
line-length = 88
target-version = ['py38']
include = '\.pyi?$'

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = "test_*.py"
EOF
            ;;
        3)
            # pipenv
            cat > "$project_name/Pipfile" << EOF
[[source]]
url = "https://pypi.org/simple"
verify_ssl = true
name = "pypi"

[packages]

[dev-packages]
pytest = ">=7.0.0"
black = ">=23.0.0"
flake8 = ">=6.0.0"
mypy = ">=1.0.0"
pytest-cov = ">=4.0.0"

[docs]
mkdocs = ">=1.4.0"
mkdocs-material = ">=9.0.0"

[requires]
python_version = "3.8"
EOF
            ;;
        4)
            # No packaging setup, just requirements.txt
            cat > "$project_name/requirements.txt" << EOF
# Project dependencies

# Development tools
pytest>=7.0.0
black>=23.0.0
flake8>=6.0.0
EOF
            ;;
    esac
    
    # Create .gitignore
    cat > "$project_name/.gitignore" << EOF
# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$py.class

# Distribution / packaging
dist/
build/
*.egg-info/

# Unit test / coverage reports
htmlcov/
.tox/
.coverage
.coverage.*
.cache
coverage.xml
*.cover

# Virtual environments
venv/
.env/
.venv/
env/

# IDE specific files
.idea/
.vscode/
*.swp
*.swo
EOF
    
    echo -e "${GREEN}Project structure created successfully!${RESET}"
    echo -e "${YELLOW}Next steps:${RESET}"
    echo -e "1. cd $project_name"
    echo -e "2. python -m venv venv"
    echo -e "3. source venv/bin/activate"
    echo -e "4. pip install -e ."
    
    # Ask if user wants to initialize git repo
    echo
    echo -e "${YELLOW}Initialize git repository? [Y/n]${RESET}"
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[nN]$ ]]; then
        (cd "$project_name" && git init && git add . && git commit -m "Initial commit")
        echo -e "${GREEN}Git repository initialized!${RESET}"
    fi
    
    # Ask if user wants to create a virtual environment
    echo
    echo -e "${YELLOW}Create a virtual environment? [Y/n]${RESET}"
    read -r venv_confirm
    
    if [[ ! "$venv_confirm" =~ ^[nN]$ ]]; then
        (cd "$project_name" && python3 -m venv venv && source venv/bin/activate && pip install --upgrade pip)
        
        # Install project in development mode
        case $packaging in
            1)
                (cd "$project_name" && pip install -e ".[dev]")
                ;;
            2)
                (cd "$project_name" && poetry install)
                ;;
            3)
                (cd "$project_name" && pipenv install --dev)
                ;;
            4)
                (cd "$project_name" && pip install -r requirements.txt)
                ;;
        esac
        
        echo -e "${GREEN}Virtual environment created and project installed in development mode!${RESET}"
    fi
    
    # Ask if user wants to cd into the project
    echo
    echo -e "${YELLOW}Change to project directory? [Y/n]${RESET}"
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[nN]$ ]]; then
        cd "$project_name" || return
        echo -e "${GREEN}Changed to project directory.${RESET}"
        ls -la
    fi
}

# Function to run Python code with timing
function pyrun() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: pyrun <python_file.py> [args...]${RESET}"
        return 1
    fi
    
    local python_file="$1"
    shift
    
    if [ ! -f "$python_file" ]; then
        echo -e "${RED}File '$python_file' not found${RESET}"
        return 1
    fi
    
    echo -e "${YELLOW}Running $python_file${RESET}"
    
    # Time the execution
    local start_time=$(date +%s.%N)
    python3 "$python_file" "$@"
    local exit_code=$?
    local end_time=$(date +%s.%N)
    local elapsed=$(echo "$end_time - $start_time" | bc)
    
    echo -e "${GREEN}Execution time: ${BOLD}${elapsed}${RESET} seconds"
    
    return $exit_code
}

# Function to analyze Python imports
function pyimports() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: pyimports <python_file.py>${RESET}"
        return 1
    fi
    
    local python_file="$1"
    
    if [ ! -f "$python_file" ]; then
        echo -e "${RED}File '$python_file' not found${RESET}"
        return 1
    fi
    
    echo -e "${YELLOW}Analyzing imports in $python_file:${RESET}"
    
    # Extract imports using grep
    grep -E "^(import|from) " "$python_file" | sort | uniq
    
    echo -e "${YELLOW}Checking if imports are installed:${RESET}"
    
    # Extract package names and check if they're installed
    grep -E "^import " "$python_file" | sed 's/^import \([^ .]*\).*/\1/' | while read -r package; do
        if python3 -c "import $package" 2>/dev/null; then
            echo -e "${GREEN}✓ $package${RESET}"
        else
            echo -e "${RED}✗ $package${RESET}"
        fi
    done
    
    grep -E "^from " "$python_file" | sed 's/^from \([^ .]*\).*/\1/' | sort | uniq | while read -r package; do
        if python3 -c "import $package" 2>/dev/null; then
            echo -e "${GREEN}✓ $package${RESET}"
        else
            echo -e "${RED}✗ $package${RESET}"
        fi
    done
    
    # Analyze import structure
    echo
    echo -e "${YELLOW}Import structure analysis:${RESET}"
    
    local stdlib_count=0
    local thirdparty_count=0
    local local_count=0
    
    # List of standard library modules
    local stdlib_modules=("abc" "argparse" "asyncio" "collections" "contextlib" "copy" "csv" "datetime" "enum" "functools" "glob" "json" "logging" "math" "os" "pathlib" "random" "re" "shutil" "sys" "tempfile" "time" "typing" "uuid" "zlib")
    
    # Extract unique imported modules
    local all_imports=$(grep -E "^import |^from " "$python_file" | sed -E 's/^import ([^ .]*).*$/\1/;s/^from ([^ .]*).*$/\1/' | sort | uniq)
    
    for module in $all_imports; do
        local found=0
        
        # Check if module is in standard library
        for stdlib in "${stdlib_modules[@]}"; do
            if [ "$module" = "$stdlib" ]; then
                found=1
                stdlib_count=$((stdlib_count + 1))
                echo -e "${CYAN}stdlib:${RESET} $module"
                break
            fi
        done
        
        # If not found in stdlib, check if it's installed via pip
        if [ $found -eq 0 ]; then
            if pip show "$module" &>/dev/null; then
                thirdparty_count=$((thirdparty_count + 1))
                echo -e "${GREEN}3rd-party:${RESET} $module"
            else
                # If not found in pip, assume it's a local module
                local_count=$((local_count + 1))
                echo -e "${PURPLE}local:${RESET} $module"
            fi
        fi
    done
    
    echo
    echo -e "${YELLOW}Import summary:${RESET}"
    echo -e "Standard library: $stdlib_count"
    echo -e "Third-party packages: $thirdparty_count"
    echo -e "Local modules: $local_count"
    echo -e "Total imports: $((stdlib_count + thirdparty_count + local_count))"
}

# Function to manage Python dependencies
function pyreq() {
    local command=${1:-"help"}
    
    case $command in
        help)
            echo -e "${YELLOW}Usage: pyreq <command>${RESET}"
            echo "Commands:"
            echo "  help      - Show this help message"
            echo "  generate  - Generate requirements.txt from installed packages"
            echo "  check     - Check if all packages in requirements.txt are installed"
            echo "  install   - Install packages from requirements.txt"
            echo "  outdated  - Show outdated packages in requirements.txt"
            echo "  upgrade   - Upgrade all packages in requirements.txt"
            echo "  graph     - Generate a dependency graph (requires graphviz)"
            ;;
            
        generate)
            echo -e "${YELLOW}Generating requirements.txt from installed packages...${RESET}"
            
            if [ -n "$VIRTUAL_ENV" ]; then
                # Only include packages the user explicitly installed
                pip freeze --local > requirements.txt
                echo -e "${GREEN}Generated requirements.txt with $(grep -c "" requirements.txt) packages${RESET}"
            else
                echo -e "${RED}No active virtual environment detected.${RESET}"
                echo -e "${YELLOW}This will generate requirements from global packages. Continue? [y/N]${RESET}"
                read -r confirm
                
                if [[ "$confirm" =~ ^[yY]$ ]]; then
                    pip freeze > requirements.txt
                    echo -e "${GREEN}Generated requirements.txt with $(grep -c "" requirements.txt) packages${RESET}"
                else
                    echo -e "${YELLOW}Operation cancelled.${RESET}"
                    return 1
                fi
            fi
            ;;
            
        check)
            if [ ! -f "requirements.txt" ]; then
                echo -e "${RED}requirements.txt not found${RESET}"
                return 1
            fi
            
            echo -e "${YELLOW}Checking installed packages against requirements.txt...${RESET}"
            
            local missing=0
            while read -r line || [[ -n "$line" ]]; do
                # Skip empty lines and comments
                if [[ -z "$line" || "$line" == \#* ]]; then
                    continue
                fi
                
                # Extract package name (before == or >= or <= or >)
                local package=$(echo "$line" | sed -E 's/([a-zA-Z0-9_.-]+).*/\1/')
                
                # Check if package is installed
                if ! pip show "$package" &> /dev/null; then
                    echo -e "${RED}✗ $package is not installed${RESET}"
                    missing=$((missing + 1))
                else
                    echo -e "${GREEN}✓ $package is installed${RESET}"
                fi
            done < requirements.txt
            
            if [ $missing -eq 0 ]; then
                echo -e "${GREEN}All packages from requirements.txt are installed.${RESET}"
            else
                echo -e "${RED}$missing package(s) from requirements.txt are not installed.${RESET}"
                echo -e "${YELLOW}Run 'pyreq install' to install missing packages.${RESET}"
                return 1
            fi
            ;;
            
        install)
            if [ ! -f "requirements.txt" ]; then
                echo -e "${RED}requirements.txt not found${RESET}"
                return 1
            fi
            
            echo -e "${YELLOW}Installing packages from requirements.txt...${RESET}"
            pip install -r requirements.txt
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Packages installed successfully!${RESET}"
            else
                echo -e "${RED}Failed to install some packages.${RESET}"
                return 1
            fi
            ;;
            
        outdated)
            if [ ! -f "requirements.txt" ]; then
                echo -e "${RED}requirements.txt not found${RESET}"
                return 1
            fi
            
            echo -e "${YELLOW}Checking for outdated packages in requirements.txt...${RESET}"
            
            local outdated_count=0
            while read -r line || [[ -n "$line" ]]; do
                # Skip empty lines and comments
                if [[ -z "$line" || "$line" == \#* ]]; then
                    continue
                fi
                
                # Extract package name (before == or >= or <= or >)
                local package=$(echo "$line" | sed -E 's/([a-zA-Z0-9_.-]+).*/\1/')
                
                # Check if package is outdated
                local outdated=$(pip list --outdated | grep "$package")
                if [ -n "$outdated" ]; then
                    echo -e "${YELLOW}$outdated${RESET}"
                    outdated_count=$((outdated_count + 1))
                fi
            done < requirements.txt
            
            if [ $outdated_count -eq 0 ]; then
                echo -e "${GREEN}All packages are up to date.${RESET}"
            else
                echo -e "${YELLOW}Found $outdated_count outdated package(s).${RESET}"
                echo -e "${CYAN}Use 'pyreq upgrade' to upgrade all packages.${RESET}"
            fi
            ;;
            
        upgrade)
            if [ ! -f "requirements.txt" ]; then
                echo -e "${RED}requirements.txt not found${RESET}"
                return 1
            fi
            
            echo -e "${YELLOW}Upgrading packages from requirements.txt...${RESET}"
            
            # Create a backup of the current requirements
            cp requirements.txt requirements.txt.bak
            echo -e "${CYAN}Created backup at requirements.txt.bak${RESET}"
            
            while read -r line || [[ -n "$line" ]]; do
                # Skip empty lines and comments
                if [[ -z "$line" || "$line" == \#* ]]; then
                    continue
                fi
                
                # Extract package name (before == or >= or <= or >)
                local package=$(echo "$line" | sed -E 's/([a-zA-Z0-9_.-]+).*/\1/')
                
                # Upgrade package
                echo -e "${CYAN}Upgrading $package...${RESET}"
                pip install --upgrade "$package"
            done < requirements.txt
            
            echo -e "${GREEN}Packages upgraded successfully!${RESET}"
            echo -e "${YELLOW}Run 'pyreq generate' to update requirements.txt with new versions.${RESET}"
            ;;
            
        graph)
            if ! command -v pip-dependency-graph &> /dev/null; then
                echo -e "${YELLOW}pip-dependency-graph not found. Install it? [Y/n]${RESET}"
                read -r confirm
                
                if [[ ! "$confirm" =~ ^[nN]$ ]]; then
                    pip install pip-dependency-graph
                else
                    echo -e "${RED}Cannot generate dependency graph without pip-dependency-graph.${RESET}"
                    return 1
                fi
            fi
            
            if ! command -v dot &> /dev/null; then
                echo -e "${YELLOW}Graphviz not found. Install it for graph visualization.${RESET}"
                echo -e "${CYAN}On Ubuntu: sudo apt install graphviz${RESET}"
                echo -e "${CYAN}On Termux: pkg install graphviz${RESET}"
            fi
            
            if [ ! -f "requirements.txt" ]; then
                echo -e "${YELLOW}requirements.txt not found. Generate a graph from installed packages? [Y/n]${RESET}"
                read -r confirm
                
                if [[ ! "$confirm" =~ ^[nN]$ ]]; then
                    if [ -n "$VIRTUAL_ENV" ]; then
                        echo -e "${YELLOW}Generating dependency graph for current environment...${RESET}"
                        pip-dependency-graph -o dependencies.pdf
                        echo -e "${GREEN}Dependency graph generated: dependencies.pdf${RESET}"
                    else
                        echo -e "${RED}No active virtual environment detected.${RESET}"
                        echo -e "${YELLOW}Generate graph for global packages? [y/N]${RESET}"
                        read -r global_confirm
                        
                        if [[ "$global_confirm" =~ ^[yY]$ ]]; then
                            pip-dependency-graph -o dependencies.pdf
                            echo -e "${GREEN}Dependency graph generated: dependencies.pdf${RESET}"
                        else
                            echo -e "${YELLOW}Operation cancelled.${RESET}"
                            return 1
                        fi
                    fi
                else
                    echo -e "${YELLOW}Operation cancelled.${RESET}"
                    return 1
                fi
            else
                echo -e "${YELLOW}Generating dependency graph from requirements.txt...${RESET}"
                pip-dependency-graph -r requirements.txt -o dependencies.pdf
                echo -e "${GREEN}Dependency graph generated: dependencies.pdf${RESET}"
            fi
            
            # Open the graph if possible
            if command -v xdg-open &> /dev/null; then
                echo -e "${YELLOW}Open the graph now? [Y/n]${RESET}"
                read -r open_confirm
                
                if [[ ! "$open_confirm" =~ ^[nN]$ ]]; then
                    xdg-open dependencies.pdf
                fi
            fi
            ;;
            
        *)
            echo -e "${RED}Unknown command: $command${RESET}"
            echo -e "${YELLOW}Run 'pyreq help' for usage information.${RESET}"
            return 1
            ;;
    esac
}

# Register this module's health check function
function _python_development_sh_health_check() {
    # Run the environment detection function
    detect_python_environment
    
    # Check for Python 3
    if [ "$PYTHON3_AVAILABLE" -eq 0 ]; then
        echo -e "${RED}Error: Python 3 not found${RESET}"
        return 1
    fi
    
    # Check for pip
    if [ "$PIP3_AVAILABLE" -eq 0 ] && [ "$PIP_AVAILABLE" -eq 0 ]; then
        echo -e "${YELLOW}Warning: pip not found${RESET}"
    fi
    
    # Check for venv module
    if [ "$VENV_AVAILABLE" -eq 0 ] && [ "$PIPENV_AVAILABLE" -eq 0 ] && [ "$POETRY_AVAILABLE" -eq 0 ]; then
        echo -e "${YELLOW}Warning: No virtual environment tools found (venv, pipenv, poetry)${RESET}"
    fi
    
    return 0
}

# Initialize auto-activation of venv if enabled
if [ "$PYTHON_AUTO_ACTIVATE" -eq 1 ]; then
    auto_activate_venv
fi

# Output module load message if verbose
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}Loaded: ${BOLD}Python Development Module${RESET} (v1.1)"
fi
