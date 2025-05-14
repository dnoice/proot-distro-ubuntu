#!/bin/bash
# ===========================================
# Git & GitHub Integration
# ===========================================
# Enhanced Git workflow tools with intelligent feedback and automation
# Author: Claude & Me
# Version: 1.0
# Last Updated: 2025-05-14

# ===========================================
# Git Status Checking Function
# ===========================================

# Function to check if git is available and we're in a repo
function _is_git_repo() {
    if ! command -v git &> /dev/null; then
        echo -e "${RED}Error: Git is not installed${RESET}"
        return 1
    fi
    
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}Error: Not in a git repository${RESET}"
        return 1
    fi
    
    return 0
}

# ===========================================
# Basic Git Command Aliases
# ===========================================

# Git workflow with improved aliases and feedback
alias g="git"
alias gs="git status"
alias ga="git add"
alias gaa="git add --all && echo -e '${GREEN}All files staged${RESET}'"
alias gc="git commit -m"
alias gca="git commit --amend"
alias gp="git push && echo -e '${GREEN}Successfully pushed to remote${RESET}'"
alias gl="git pull && echo -e '${GREEN}Successfully pulled from remote${RESET}'"
alias gf="git fetch"
alias gd="git diff"
alias gds="git diff --staged"
alias gb="git branch"
alias gba="git branch -a"
alias gco="git checkout"
alias gcb="git checkout -b"
alias glog="git log --oneline --graph --decorate"
alias grh="git reset --hard"
alias gcl="git clone"
alias gst="git stash"
alias gstp="git stash pop"
alias gstl="git stash list"
alias gcp="git cherry-pick"
alias gm="git merge"
alias grb="git rebase"
alias gundo="git reset HEAD~1 --soft"  # Undo last commit but keep changes

# ===========================================
# Enhanced Git Functions
# ===========================================

# Git log visualization with better formatting
function git_log_graph() {
    _is_git_repo || return
    
    local num_commits=${1:-20}
    echo -e "${CYAN}Showing commit history (last $num_commits commits):${RESET}"
    git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all -n "$num_commits"
}

alias glg="git_log_graph"

# Git branch management with enhanced details
function gbr() {
    _is_git_repo || return
    
    # Fetch branch info from remote if connected to internet
    if ping -c 1 github.com &> /dev/null || ping -c 1 gitlab.com &> /dev/null; then
        echo -e "${YELLOW}Fetching latest branch information...${RESET}"
        git fetch --prune
    fi
    
    # Get current branch
    local current_branch=$(git branch --show-current)
    
    # List all branches with last commit date
    echo -e "${YELLOW}Local branches:${RESET}"
    for branch in $(git for-each-ref --format='%(refname)' refs/heads/); do
        local branch_name=${branch#refs/heads/}
        local last_commit=$(git log -1 --format="%cr" "$branch_name")
        local author=$(git log -1 --format="%an" "$branch_name")
        
        # Mark current branch with asterisk
        if [ "$branch_name" = "$current_branch" ]; then
            echo -e "${GREEN}* $branch_name${RESET} - $last_commit by $author"
        else
            echo -e "  ${GREEN}$branch_name${RESET} - $last_commit by $author"
        fi
    done
    
    # Show default branch
    local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [ -n "$default_branch" ]; then
        echo
        echo -e "${YELLOW}Default branch: ${GREEN}$default_branch${RESET}"
    fi
    
    # Show remote branches if any
    if git remote show | grep -q "origin"; then
        echo
        echo -e "${YELLOW}Remote branches:${RESET}"
        git branch -r | grep -v "HEAD" | while read -r remote_branch; do
            # Clean up branch name for display
            local branch_name=$(echo "$remote_branch" | sed 's/origin\///')
            
            # Get last commit info
            local last_commit=$(git log -1 --format="%cr" "$remote_branch")
            local author=$(git log -1 --format="%an" "$remote_branch")
            
            echo -e "  ${BLUE}$branch_name${RESET} - $last_commit by $author"
        done
    fi
}

# Switch to a branch with smart features
function gsw() {
    _is_git_repo || return
    
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Available branches:${RESET}"
        git branch | sed 's/^../  /'
        echo -e "${YELLOW}Usage: gsw <branch_name>${RESET}"
        return 1
    fi
    
    local branch="$1"
    
    # Check if branch exists
    if ! git show-ref --quiet refs/heads/"$branch"; then
        # Branch doesn't exist locally, check if it exists in remote
        if git show-ref --quiet refs/remotes/origin/"$branch"; then
            echo -e "${YELLOW}Branch '$branch' not found locally but exists in remote.${RESET}"
            echo -e "${YELLOW}Creating tracking branch for origin/$branch...${RESET}"
            git checkout -b "$branch" origin/"$branch"
        else
            # Branch doesn't exist at all
            echo -e "${YELLOW}Branch '$branch' not found. Create it? [y/N]${RESET}"
            read -r confirm
            if [[ "$confirm" =~ ^[yY]$ ]]; then
                git checkout -b "$branch"
                echo -e "${GREEN}Created and switched to new branch: $branch${RESET}"
            else
                echo -e "${YELLOW}Operation cancelled.${RESET}"
                return 1
            fi
        fi
    else
        # Branch exists locally, check if we have uncommitted changes
        if ! git diff --quiet; then
            echo -e "${YELLOW}You have uncommitted changes. Stash them? [y/N]${RESET}"
            read -r confirm
            if [[ "$confirm" =~ ^[yY]$ ]]; then
                git stash
                echo -e "${GREEN}Changes stashed.${RESET}"
            else
                echo -e "${YELLOW}Continuing with uncommitted changes...${RESET}"
            fi
        fi
        
        # Switch branch
        git checkout "$branch"
    fi
    
    # Show branch status after switching
    echo -e "${GREEN}Now on branch: $branch${RESET}"
    git status -s
}

# Enhanced GitHub clone function with repository insights
function gclone() {
    if [ -z "$1" ]; then
        echo -e "${RED}Usage: gclone [username/repo] [directory]${RESET}"
        echo "Examples:"
        echo "  gclone torvalds/linux"
        echo "  gclone https://github.com/microsoft/vscode.git"
        return 1
    fi
    
    local repo="$1"
    local clone_dir="$2"
    local repo_url
    
    # Determine if this is a URL or user/repo format
    if [[ "$repo" == http* ]]; then
        repo_url="$repo"
        # Extract repo name from URL
        local repo_name=$(basename "$repo_url" .git)
    else
        # Process user/repo format
        if [[ "$repo" != *"/"* ]]; then
            echo -e "${RED}Error: Please use format 'username/repo' or provide a full URL${RESET}"
            return 1
        fi
        
        local username=$(echo "$repo" | cut -d '/' -f1)
        local reponame=$(echo "$repo" | cut -d '/' -f2)
        
        if [ -z "$username" ] || [ -z "$reponame" ]; then
            echo -e "${RED}Error: Please use format 'username/repo'${RESET}"
            return 1
        fi
        
        repo_url="https://github.com/$username/$reponame.git"
        repo_name="$reponame"
    fi
    
    # Set clone directory if not specified
    if [ -z "$clone_dir" ]; then
        clone_dir="$repo_name"
    fi
    
    echo -e "${YELLOW}Cloning $repo_url into $clone_dir...${RESET}"
    
    # Clone the repository
    git clone "$repo_url" "$clone_dir"
    
    # If successful, cd into the repo
    if [ $? -eq 0 ]; then
        cd "$clone_dir" || return
        echo -e "${GREEN}Repository cloned successfully!${RESET}"
        
        # Repository info
        echo -e "${YELLOW}Repository Details:${RESET}"
        echo "Current branch: $(git branch --show-current)"
        echo "Total commits: $(git rev-list --count HEAD)"
        echo "Contributors: $(git shortlog -sn --no-merges | wc -l)"
        echo "Latest tag: $(git describe --tags --abbrev=0 2>/dev/null || echo 'No tags')"
        
        # Check for common setup files
        echo
        echo -e "${YELLOW}Project Detection:${RESET}"
        local detected=0
        
        if [ -f "package.json" ]; then
            echo -e "${GREEN}Node.js project detected.${RESET} Run 'npm install' to install dependencies."
            # Show main info from package.json
            local pkg_name=$(grep -m 1 '"name":' package.json | awk -F'"' '{print $4}')
            local pkg_version=$(grep -m 1 '"version":' package.json | awk -F'"' '{print $4}')
            echo -e "  Package: $pkg_name v$pkg_version"
            detected=1
        fi
        
        if [ -f "requirements.txt" ]; then
            echo -e "${GREEN}Python project detected.${RESET} Run 'pip install -r requirements.txt' to install dependencies."
            # Show line count of requirements
            local req_count=$(wc -l < requirements.txt)
            echo -e "  Dependencies: $req_count packages listed"
            detected=1
        fi
        
        if [ -f "Gemfile" ]; then
            echo -e "${GREEN}Ruby project detected.${RESET} Run 'bundle install' to install dependencies."
            detected=1
        fi
        
        if [ -f "composer.json" ]; then
            echo -e "${GREEN}PHP project detected.${RESET} Run 'composer install' to install dependencies."
            detected=1
        fi
        
        if [ -f "go.mod" ]; then
            echo -e "${GREEN}Go project detected.${RESET} Run 'go mod download' to install dependencies."
            detected=1
        fi
        
        if [ -f "Cargo.toml" ]; then
            echo -e "${GREEN}Rust project detected.${RESET} Run 'cargo build' to install dependencies."
            detected=1
        fi
        
        if [ -f "pom.xml" ]; then
            echo -e "${GREEN}Java Maven project detected.${RESET} Run 'mvn install' to install dependencies."
            detected=1
        fi
        
        if [ -f "build.gradle" ]; then
            echo -e "${GREEN}Java Gradle project detected.${RESET} Run 'gradle build' to install dependencies."
            detected=1
        fi
        
        if [ -f "CMakeLists.txt" ]; then
            echo -e "${GREEN}CMake project detected.${RESET} Run 'mkdir build && cd build && cmake ..' to configure."
            detected=1
        fi
        
        if [ "$detected" -eq 0 ]; then
            echo -e "${YELLOW}No specific project type detected.${RESET}"
        fi
        
        # Show project structure
        echo
        echo -e "${CYAN}Project structure:${RESET}"
        if command -v tree &> /dev/null; then
            tree -L 2 -C
        else
            ls -la
        fi
    else
        echo -e "${RED}Failed to clone repository${RESET}"
    fi
}

# Create GitHub PR with enhanced error checking and feedback
function gh_pr() {
    _is_git_repo || return
    
    # Check if current branch is not main/master
    local current_branch=$(git branch --show-current)
    local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
    
    if [ "$current_branch" = "$default_branch" ] || [ "$current_branch" = "master" ]; then
        echo -e "${RED}Error: You're on $current_branch branch. Create a feature branch first.${RESET}"
        echo -e "Run: ${YELLOW}git checkout -b feature/your-feature-name${RESET}"
        return 1
    fi
    
    # Ensure changes are committed
    if ! git diff-index --quiet HEAD --; then
        echo -e "${RED}You have uncommitted changes. Commit first with:${RESET}"
        echo -e "${YELLOW}git add .${RESET}"
        echo -e "${YELLOW}git commit -m \"Your message\"${RESET}"
        return 1
    fi
    
    # Check for GitHub CLI tool
    if command -v gh &> /dev/null; then
        echo -e "${GREEN}GitHub CLI detected. Creating pull request...${RESET}"
        gh pr create
        return $?
    fi
    
    # Check for upstream branch
    if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} > /dev/null 2>&1; then
        echo -e "${YELLOW}Setting upstream branch...${RESET}"
        git push -u origin "$current_branch"
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to push to remote${RESET}"
            return 1
        fi
    else
        # Push to remote
        echo -e "${YELLOW}Pushing latest changes...${RESET}"
        git push
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to push to remote${RESET}"
            return 1
        fi
    fi
    
    # Extract repo information from remote
    local remote_url=$(git remote get-url origin)
    local repo_url=""
    
    if [[ "$remote_url" == *"github.com"* ]]; then
        # Handle HTTPS URLs
        if [[ "$remote_url" == *"https://"* ]]; then
            repo_url=$(echo "$remote_url" | sed -e 's/https:\/\/github.com\///' -e 's/\.git$//')
        # Handle SSH URLs
        elif [[ "$remote_url" == *"git@github.com"* ]]; then
            repo_url=$(echo "$remote_url" | sed -e 's/git@github.com://' -e 's/\.git$//')
        fi
    else
        echo -e "${RED}Remote is not a GitHub repository${RESET}"
        return 1
    fi
    
    local pr_url="https://github.com/$repo_url/pull/new/$current_branch"
    
    echo -e "${GREEN}To create a PR, go to:${RESET}"
    echo -e "${CYAN}$pr_url${RESET}"
    
    # Try to open in browser if xdg-open is available
    if command -v xdg-open &> /dev/null; then
        echo -e "${YELLOW}Attempting to open in browser...${RESET}"
        xdg-open "$pr_url" &> /dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Browser opened with PR creation page${RESET}"
        else
            echo -e "${YELLOW}Could not open browser automatically${RESET}"
        fi
    fi
}

# Git bulk operations
function gbulk() {
    local command="$1"
    shift
    
    if [ -z "$command" ]; then
        echo -e "${YELLOW}Usage: gbulk [command] [options]${RESET}"
        echo "Commands:"
        echo "  update   - Pull updates for all git repos in current directory"
        echo "  status   - Check status of all git repos in current directory"
        echo "  clean    - Clean up all git repos (garbage collection, prune)"
        echo "  backup   - Create backup archive of all git repos"
        return 1
    fi
    
    case "$command" in
        update)
            echo -e "${YELLOW}Updating all git repositories in current directory...${RESET}"
            for dir in */; do
                if [ -d "$dir/.git" ]; then
                    echo -e "${GREEN}Updating ${BOLD}$dir${RESET}"
                    (cd "$dir" && git pull)
                    echo
                fi
            done
            ;;
        status)
            echo -e "${YELLOW}Checking status of all git repositories in current directory...${RESET}"
            for dir in */; do
                if [ -d "$dir/.git" ]; then
                    echo -e "${GREEN}Status of ${BOLD}$dir${RESET}"
                    (cd "$dir" && git status -s)
                    # Show branch info
                    (cd "$dir" && echo -e "Branch: $(git branch --show-current)")
                    # Show last commit
                    (cd "$dir" && echo -e "Last commit: $(git log -1 --format="%h - %s (%cr)")")
                    echo
                fi
            done
            ;;
        clean)
            echo -e "${YELLOW}Cleaning all git repositories in current directory...${RESET}"
            for dir in */; do
                if [ -d "$dir/.git" ]; then
                    echo -e "${GREEN}Cleaning ${BOLD}$dir${RESET}"
                    (cd "$dir" && git gc && git prune)
                    echo
                fi
            done
            ;;
        backup)
            echo -e "${YELLOW}Backing up all git repositories in current directory...${RESET}"
            local timestamp=$(date +"%Y%m%d_%H%M%S")
            local backup_file="git_repos_backup_$timestamp.tar.gz"
            
            # Get list of git repos
            local git_repos=()
            for dir in */; do
                if [ -d "$dir/.git" ]; then
                    git_repos+=("$dir")
                fi
            done
            
            if [ ${#git_repos[@]} -eq 0 ]; then
                echo -e "${RED}No git repositories found in current directory${RESET}"
                return 1
            fi
            
            echo -e "${GREEN}Found ${#git_repos[@]} repositories to backup${RESET}"
            echo -e "${YELLOW}Creating backup archive: $backup_file${RESET}"
            
            tar -czf "$backup_file" "${git_repos[@]}"
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Backup created successfully: $backup_file${RESET}"
                echo -e "Archive size: $(du -h "$backup_file" | cut -f1)"
            else
                echo -e "${RED}Failed to create backup${RESET}"
                return 1
            fi
            ;;
        *)
            echo -e "${RED}Unknown command: $command${RESET}"
            echo "Valid commands: update, status, clean, backup"
            return 1
            ;;
    esac
}

# Detect and update outdated repositories
function gupdate() {
    _is_git_repo || return
    
    echo -e "${YELLOW}Checking for updates in repository...${RESET}"
    
    # Fetch latest changes
    git fetch
    
    # Check if we're behind the remote
    local behind_count=$(git rev-list --count HEAD..@{u} 2>/dev/null)
    
    if [ -z "$behind_count" ] || [ "$behind_count" -eq 0 ]; then
        echo -e "${GREEN}Repository is up to date.${RESET}"
        return 0
    fi
    
    echo -e "${YELLOW}Repository is behind by $behind_count commits.${RESET}"
    
    # Check if we have uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo -e "${RED}You have uncommitted changes. Stash or commit them before updating.${RESET}"
        echo -e "Options:"
        echo -e "1. ${YELLOW}Stash changes and update${RESET}"
        echo -e "2. ${YELLOW}Show changes and exit${RESET}"
        echo -e "3. ${YELLOW}Exit without updating${RESET}"
        
        read -p "Enter your choice [1-3]: " choice
        
        case $choice in
            1)
                echo -e "${YELLOW}Stashing changes...${RESET}"
                git stash
                ;;
            2)
                echo -e "${YELLOW}Uncommitted changes:${RESET}"
                git status -s
                return 1
                ;;
            *)
                echo -e "${YELLOW}Update cancelled.${RESET}"
                return 1
                ;;
        esac
    fi
    
    # Show what will be updated
    echo -e "${YELLOW}Incoming changes:${RESET}"
    git log --oneline HEAD..@{u}
    
    echo -e "${YELLOW}Update repository now? [Y/n]${RESET}"
    read -r confirm
    
    if [[ "$confirm" =~ ^[nN]$ ]]; then
        echo -e "${YELLOW}Update cancelled.${RESET}"
        return 1
    fi
    
    # Pull changes
    git pull
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Repository updated successfully!${RESET}"
        
        # If we stashed changes, check if user wants to pop them
        if [ $choice -eq 1 ]; then
            echo -e "${YELLOW}Apply stashed changes? [Y/n]${RESET}"
            read -r apply_stash
            
            if [[ ! "$apply_stash" =~ ^[nN]$ ]]; then
                git stash pop
                echo -e "${GREEN}Stashed changes applied.${RESET}"
            else
                echo -e "${YELLOW}Stashed changes kept in stash.${RESET}"
            fi
        fi
    else
        echo -e "${RED}Update failed.${RESET}"
        return 1
    fi
}

# Git commit with conventional commit format
function gcommit() {
    _is_git_repo || return
    
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: gcommit <type> <message>${RESET}"
        echo "Conventional commit types:"
        echo "  feat     - A new feature"
        echo "  fix      - A bug fix"
        echo "  docs     - Documentation only changes"
        echo "  style    - Changes that do not affect the meaning of the code"
        echo "  refactor - A code change that neither fixes a bug nor adds a feature"
        echo "  perf     - A code change that improves performance"
        echo "  test     - Adding missing tests or correcting existing tests"
        echo "  chore    - Changes to the build process or auxiliary tools"
        return 1
    fi
    
    local type="$1"
    shift
    local message="$*"
    
    if [ -z "$message" ]; then
        echo -e "${RED}Error: Commit message is required${RESET}"
        return 1
    fi
    
    # Validate commit type
    local valid_types=("feat" "fix" "docs" "style" "refactor" "perf" "test" "chore")
    local valid=0
    
    for valid_type in "${valid_types[@]}"; do
        if [ "$type" = "$valid_type" ]; then
            valid=1
            break
        fi
    done
    
    if [ $valid -eq 0 ]; then
        echo -e "${RED}Error: Invalid commit type '$type'${RESET}"
        echo "Valid types: ${valid_types[*]}"
        return 1
    fi
    
    # Stage files if needed
    git diff --quiet || {
        echo -e "${YELLOW}You have unstaged changes. Stage them? [Y/n]${RESET}"
        read -r stage
        
        if [[ ! "$stage" =~ ^[nN]$ ]]; then
            git add .
            echo -e "${GREEN}Changes staged.${RESET}"
        fi
    }
    
    # Create commit
    local commit_message="$type: $message"
    git commit -m "$commit_message"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Commit created: ${BOLD}$commit_message${RESET}"
    else
        echo -e "${RED}Failed to create commit${RESET}"
        return 1
    fi
}

# Initialize new git repository with useful defaults
function ginit() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}Repository already initialized${RESET}"
        return 1
    fi
    
    echo -e "${YELLOW}Initializing new git repository...${RESET}"
    git init
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to initialize repository${RESET}"
        return 1
    fi
    
    # Create .gitignore if it doesn't exist
    if [ ! -f ".gitignore" ]; then
        echo -e "${YELLOW}Creating .gitignore file...${RESET}"
        
        echo -e "${YELLOW}Select project type for .gitignore template:${RESET}"
        echo "1. Node.js"
        echo "2. Python"
        echo "3. Java"
        echo "4. C/C++"
        echo "5. General"
        read -p "Enter your choice [1-5]: " choice
        
        case $choice in
            1)
                cat > .gitignore << 'EOF'
# Node.js
node_modules/
npm-debug.log
yarn-debug.log
yarn-error.log
package-lock.json
.npm/
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
coverage/
dist/
build/
EOF
                ;;
            2)
                cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
ENV/
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
*.egg-info/
.installed.cfg
*.egg
.pytest_cache/
.coverage
htmlcov/
EOF
                ;;
            3)
                cat > .gitignore << 'EOF'
# Java
*.class
*.log
*.jar
*.war
*.nar
*.ear
*.zip
*.tar.gz
*.rar
hs_err_pid*
replay_pid*
target/
.idea/
.gradle/
build/
.classpath
.project
.settings/
bin/
EOF
                ;;
            4)
                cat > .gitignore << 'EOF'
# C/C++
*.o
*.ko
*.obj
*.elf
*.ilk
*.map
*.exp
*.gch
*.pch
*.so
*.dylib
*.dll
*.a
*.lib
*.la
*.lo
*.out
*.app
*.exe
*.out
*.app
.vs/
CMakeLists.txt.user
CMakeCache.txt
CMakeFiles
.DS_Store
EOF
                ;;
            *)
                cat > .gitignore << 'EOF'
# General
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
.idea/
.vscode/
*.swp
*.bak
*~
temp/
tmp/
.env
EOF
                ;;
        esac
        
        echo -e "${GREEN}.gitignore created.${RESET}"
    fi
    
    # Create README.md if it doesn't exist
    if [ ! -f "README.md" ]; then
        echo -e "${YELLOW}Creating README.md file...${RESET}"
        
        # Get directory name as default project name
        local project_name=$(basename "$PWD")
        
        cat > README.md << EOF
# $project_name

## Description
A short description of your project.

## Installation
Installation instructions here.

## Usage
Usage instructions here.

## License
MIT
EOF
        
        echo -e "${GREEN}README.md created.${RESET}"
    fi
    
    # Initial commit
    echo -e "${YELLOW}Do you want to create an initial commit? [Y/n]${RESET}"
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[nN]$ ]]; then
        git add .
        git commit -m "Initial commit"
        echo -e "${GREEN}Initial commit created.${RESET}"
    fi
    
    # Ask about GitHub/remote repository
    echo -e "${YELLOW}Do you want to set up a remote repository? [y/N]${RESET}"
    read -r remote_confirm
    
    if [[ "$remote_confirm" =~ ^[yY]$ ]]; then
        echo -e "${YELLOW}Enter the remote repository URL:${RESET}"
        read -r remote_url
        
        if [ -n "$remote_url" ]; then
            git remote add origin "$remote_url"
            echo -e "${GREEN}Remote 'origin' added: $remote_url${RESET}"
            
            echo -e "${YELLOW}Push to remote now? [y/N]${RESET}"
            read -r push_confirm
            
            if [[ "$push_confirm" =~ ^[yY]$ ]]; then
                git push -u origin master 2>/dev/null || git push -u origin main
                echo -e "${GREEN}Pushed to remote repository.${RESET}"
            fi
        else
            echo -e "${YELLOW}No URL provided. Skipping remote setup.${RESET}"
        fi
    fi
    
    echo -e "${GREEN}Git repository initialized successfully!${RESET}"
}

# Output module load message if verbose
if [[ "$VERBOSE_MODULE_LOAD" == "1" ]]; then
    echo -e "${GREEN}Loaded: ${BOLD}Git & GitHub Integration Module${RESET}"
fi
