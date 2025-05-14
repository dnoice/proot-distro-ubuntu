# Modular Bashrc System for Termux Ubuntu

This project provides a comprehensive, modular Bash configuration system for Ubuntu running in Termux via proot-distro. It enhances your command-line experience with improved navigation, productivity tools, development environments, and more.

## Features

- **Modular Design**: Each functionality in its own file for easy maintenance
- **Enhanced Navigation**: Seamlessly navigate between Ubuntu and Android shared storage
- **Git Integration**: Advanced Git workflow with smart features and GitHub integration
- **Python Development**: Virtual environment management and project tools
- **Task Management**: Built-in task timer and project tracking
- **Network Utilities**: Tools for network diagnostics and web operations
- **Auto-start Configuration**: Launch Ubuntu automatically when opening Termux

## Installation

### Quick Install

1. Copy the `install.sh` script to your Ubuntu environment
2. Make it executable:
   ```bash
   chmod +x install.sh
   ```
3. Run the installer:
   ```bash
   ./install.sh
   ```

### Manual Installation

1. Create the module directory:
   ```bash
   mkdir -p ~/.bashrc.d
   ```

2. Copy all module files (`*.sh`) to `~/.bashrc.d/`

3. Copy the main `.bashrc` file to your home directory:
   ```bash
   cp main-bashrc ~/.bashrc
   ```

4. (Optional) Configure Termux to auto-start Ubuntu:
   ```bash
   cp termux-bashrc ~/../../home/.bashrc
   ```

5. Apply changes:
   ```bash
   source ~/.bashrc
   ```

## Module Structure

The system is organized into the following modules:

1. **00-module-loader.sh**: Core loader that manages all other modules
2. **01-core-settings.sh**: Basic shell settings and environment configuration
3. **02-prompt.sh**: Enhanced command prompt with Git integration
4. **03-storage-navigation.sh**: Navigation between Ubuntu and Android storage
5. **04-file-operations.sh**: Advanced file management operations
6. **05-git-integration.sh**: Git workflow and GitHub integration
7. **06-python-development.sh**: Python development environment tools
8. **07-system-management.sh**: System monitoring and maintenance
9. **08-productivity-tools.sh**: Task timer and project management
10. **09-network-utilities.sh**: Network diagnostics and web tools
11. **10-custom-utilities.sh**: Miscellaneous utility functions

## Key Commands

### General

- `help`: Show available commands
- `lsmod`: List available modules
- `reload`: Reload all modules
- `bashrc <module>`: Edit a specific module

### Storage Navigation

- `sdcard`: Jump to Android shared storage
- `home`: Return to Ubuntu home directory
- `scd <folder>`: Navigate to a folder in shared storage
- `where`: Show current path relative to sdcard

### Development

- `p <project>`: Navigate to a project
- `a`: Activate Python virtual environment
- `pyproject <name>`: Create a new Python project structure
- `gclone <user/repo>`: Clone a GitHub repository with insights

### Productivity

- `ts <task>`: Start timing a task
- `te`: Stop current timer
- `tr [days]`: Show timer report
- `note add <title>`: Add a quick note
- `project list`: List all projects

### System & Network

- `sm`: Show system monitoring information
- `myip`: Show public and local IP addresses
- `update`: Interactive system update
- `weather [location]`: Show weather forecast

## Customization

You can create a custom configuration file at `~/.bashrc.custom` to add your own settings, which will be loaded after all modules.

To enable verbose module loading:

```bash
export VERBOSE_MODULE_LOAD=1
```

To disable the welcome message:

```bash
export DISABLE_WELCOME=1
```

## Troubleshooting

If you encounter issues:

1. Check module loading with verbose mode:
   ```bash
   export VERBOSE_MODULE_LOAD=1
   source ~/.bashrc
   ```

2. Inspect individual modules:
   ```bash
   bashrc <module_name>
   ```

3. Reload the configuration:
   ```bash
   reload
   ```

4. Restore original PATH if needed:
   ```bash
   restore_path
   ```

## License

This project is licensed under the MIT License - see the LICENSE file for details.
