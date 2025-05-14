#!/bin/bash
# ===========================================
# Python Development Environment
# ===========================================
# Tools for Python development with virtual environments, dependency management and project tools
# Author: Claude & Me
# Version: 1.0
# Last Updated: 2025-05-14

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
# Virtual Environment Management
# ===========================================

# Check Python version and modules
function pycheck() {
    echo -e "${YELLOW}Python environment information:${RESET}"
    
    # Check Python version
    if command -v python3 &> /dev/null; then
        echo -e "${GREEN}Python $(python3 --version 2>&1)${RESET}"
    else
        echo -e "${RED}Python 3 not found${RESET}"
    fi
    
    # Check pip
    if command -v pip3 &> /dev/null; then
        echo -e "${GREEN}$(pip3 --version)${RESET}"
    else
        echo -e "${RED}pip3 not found${RESET}"
    fi
    
    # Check venv module
    if python3 -c "import venv" &> /dev/null; then
        echo -e "${GREEN}venv module available${RESET}"
    else
        echo -e "${RED}venv module not available${RESET}"
        echo -e "${YELLOW}Try installing python3-venv package${RESET}"
    fi
    
    # Check if in virtual environment
    if [ -n "$VIRTUAL_ENV" ]; then
        echo -e "${GREEN}Active virtual environment: $(basename "$VIRTUAL_ENV")${RESET}"
        echo -e "${CYAN}Path: $VIRTUAL_ENV${RESET}"
    else
        echo -e "${YELLOW}No active virtual environment${RESET}"
    fi
    
    # List installed packages if in venv
    if [ -n "$VIRTUAL_ENV" ]; then
        echo -e "${YELLOW}Top packages installed in this environment:${RESET}"
        pip list | grep -v "^Package" | grep -v "^------" | sort | head -n 10
        
        # Show count if more than 10
        local pkg_count=$(pip list | grep -v "^Package" | grep -v "^------" | wc -l)
        if [ "$pkg_count" -gt 10 ]; then
            echo -e "${YELLOW}... and $((pkg_count - 10)) more packages${RESET}"
        fi
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
            source "$1/bin/activate"
            pycheck
            return 0
        else
            echo -e "${RED}No valid virtual environment found at $1${RESET}"
        fi
    fi
    
    # Otherwise, try common virtual environment directories
    for venv in "${venv_dirs[@]}"; do
        if [ -d "$venv" ] && [ -f "$venv/bin/activate" ]; then
            echo -e "${GREEN}Activating virtual environment: $venv${RESET}"
            source "$venv/bin/activate"
            pycheck
            return 0
        fi
    done
    
    echo -e "${YELLOW}No virtual environment found. Checking for requirements.txt...${RESET}"
    
    if [ -f "requirements.txt" ]; then
        echo -e "${YELLOW}Found requirements.txt. Create a virtual environment? [y/N]${RESET}"
        read -r confirm
        
        if [[ "$confirm" =~ ^[yY]$ ]]; then
            echo -e "${GREEN}Creating virtual environment 'venv'...${RESET}"
            python3 -m venv venv
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Virtual environment created successfully!${RESET}"
                source venv/bin/activate
                echo -e "${YELLOW}Installing requirements...${RESET}"
                pip install -r requirements.txt
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
                                source venv/bin/activate
                                echo -e "${YELLOW}Installing requirements...${RESET}"
                                pip install -r requirements.txt
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
}

# Function to install common development tools in an active venv
function pysetup() {
    if [ -z "$VIRTUAL_ENV" ]; then
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
    
    case $structure in
        1)
            # Simple structure
            mkdir -p "$project_name"
            touch "$project_name/__init__.py"
            touch "$project_name/main.py"
            
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
            touch "$project_name/src/$project_name/main.py"
            touch "$project_name/tests/__init__.py"
            touch "$project_name/tests/test_main.py"
            
            # Create setup.py
            cat > "$project_name/setup.py" << EOF
from setuptools import setup, find_packages

setup(
    name="$project_name",
    version="0.1.0",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    install_requires=[],
    python_requires=">=3.6",
)
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
\`\`\`

## Development

\`\`\`bash
# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install development dependencies
pip install -e ".[dev]"
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
            touch "$project_name/src/$project_name/main.py"
            touch "$project_name/tests/__init__.py"
            touch "$project_name/tests/test_main.py"
            touch "$project_name/examples/example.py"
            touch "$project_name/docs/index.md"
            
            # Create setup.py
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
        (cd "$project_name" && python3 -m venv venv && source venv/bin/activate && pip install --upgrade pip && pip install -e .)
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
    
    grep -E "^from " "$python_file" | sed 's/^from \([^ .]*\).*/\1/' | while read -r package; do
        if python3 -c "import $package" 2>/dev/null; then
            echo -e "${GREEN}✓ $package${RESET}"
        else
            echo -e "${RED}✗ $package${RESET}"
        fi
    done
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
            while read -r line; do
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
            
            while read -r line; do
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
                fi
            done < requirements.txt
            ;;
            
        upgrade)
            if [ ! -f "requirements.txt" ]; then
                echo -e "${RED}requirements.txt not found${RESET}"
                return 1
            fi
            
            echo -e "${YELLOW}Upgrading packages from requirements.txt...${RESET}"
            
            while read -r line; do
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
            
        *)
            echo -e "${RED}Unknown command: $command${RESET}"
            echo -e "${YELLOW}Run 'pyreq help' for usage information.${RESET}"
            return 1
            ;;
    esac
}

# Output module load message if verbose
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}Loaded: ${BOLD}Python Development Module${RESET}"
fi
