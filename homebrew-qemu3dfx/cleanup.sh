#!/bin/bash

# Cleanup script for removing conflicting Homebrew packages
# before installing QEMU 3dfx tap

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
Homebrew QEMU/Virgl Cleanup Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --check-only    Only check what would be removed (dry run)
    --backup        Create backup list before removal
    --force         Force removal without confirmation
    --restore       Restore previously backed up packages
    --help          Show this help

DESCRIPTION:
    This script removes conflicting Homebrew packages before installing
    the QEMU 3dfx tap. It handles QEMU, virglrenderer, and related packages
    that might conflict with our custom builds.

EXAMPLES:
    $0                  # Interactive cleanup with confirmation
    $0 --check-only     # See what would be removed
    $0 --backup         # Backup package list before removal
    $0 --restore        # Restore previously backed up packages

EOF
}

# Check what QEMU/Virgl packages are installed
check_installed_packages() {
    local packages_to_check=(
        "qemu"
        "virglrenderer" 
        "qemu-virgl-deps"
    )
    
    local installed_packages=()
    
    for package in "${packages_to_check[@]}"; do
        if brew list --formula "$package" &> /dev/null; then
            installed_packages+=("$package")
        elif brew list --cask "$package" &> /dev/null; then
            installed_packages+=("$package (cask)")
        fi
    done
    
    # Check for any package containing qemu or virgl (but exclude mesa and common libs)
    local additional_packages=$(brew list --formula 2>/dev/null | grep -E "^(qemu|virgl)" 2>/dev/null || true)
    if [ ! -z "$additional_packages" ]; then
        while IFS= read -r package; do
            # Skip mesa, libmesa, and other common graphics libraries
            if [[ "$package" =~ ^(mesa|libmesa|glu|freeglut)$ ]]; then
                continue
            fi
            
            if [[ ! " ${installed_packages[@]} " =~ " ${package} " ]]; then
                installed_packages+=("$package")
            fi
        done <<< "$additional_packages"
    fi
    
    # Return the packages (don't echo log messages here)
    if [ ${#installed_packages[@]} -gt 0 ]; then
        printf '%s\n' "${installed_packages[@]}"
    fi
}

# Backup installed packages to a file
backup_packages() {
    local backup_file="$HOME/.qemu-3dfx-tap-backup-$(date +%Y%m%d-%H%M%S).txt"
    log_info "Creating backup at: $backup_file"
    
    # Get all installed packages
    local all_packages=$(brew list --formula)
    
    # Filter for QEMU/Virgl related packages (but exclude mesa and common libs)
    local qemu_virgl_packages=$(echo "$all_packages" | grep -E "^(qemu|virgl)" || true)
    
    if [ ! -z "$qemu_virgl_packages" ]; then
        echo "# Homebrew packages backup created $(date)" > "$backup_file"
        echo "# QEMU/Virgl packages that were installed before QEMU 3dfx tap" >> "$backup_file"
        echo "$qemu_virgl_packages" >> "$backup_file"
        log_success "Backup created: $backup_file"
        echo "$backup_file"
    else
        log_info "No QEMU/Virgl packages to backup"
        echo ""
    fi
}

# Restore packages from backup
restore_packages() {
    log_info "Looking for backup files..."
    
    local backup_files=$(find "$HOME" -name ".qemu-3dfx-tap-backup-*.txt" 2>/dev/null | sort -r | head -5)
    
    if [ -z "$backup_files" ]; then
        log_error "No backup files found"
        return 1
    fi
    
    echo "Available backup files:"
    local i=1
    local file_array=()
    while IFS= read -r file; do
        echo "  $i) $(basename "$file") ($(date -r "$file" '+%Y-%m-%d %H:%M'))"
        file_array[i]="$file"
        ((i++))
    done <<< "$backup_files"
    
    echo -n "Select backup to restore [1-$((i-1))]: "
    read -r choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
        local backup_file="${file_array[$choice]}"
        log_info "Restoring from: $(basename "$backup_file")"
        
        # Read packages from backup file (skip comment lines)
        local packages=$(grep -v "^#" "$backup_file" | grep -v "^$")
        
        if [ ! -z "$packages" ]; then
            log_info "Installing packages from backup..."
            while IFS= read -r package; do
                log_info "Installing: $package"
                brew install "$package" || log_warning "Failed to install: $package"
            done <<< "$packages"
            log_success "Restore completed"
        else
            log_warning "No packages found in backup file"
        fi
    else
        log_error "Invalid selection"
        return 1
    fi
}

# Remove packages
remove_packages() {
    local packages_str="$1"
    local force="$2"
    
    if [ -z "$packages_str" ]; then
        log_info "No conflicting packages found"
        return 0
    fi
    
    # Convert string to array
    local packages_array=($packages_str)
    
    if [ "$force" != "true" ]; then
        echo
        log_warning "The following packages will be removed:"
        for package in "${packages_array[@]}"; do
            echo "  - $package"
        done
        echo
        echo -n "Continue with removal? [y/N]: "
        read -r confirm
        
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Removal cancelled"
            return 1
        fi
    fi
    
    log_info "Removing conflicting packages..."
    
    for package in "${packages_array[@]}"; do
        if [[ "$package" == *"(cask)"* ]]; then
            # Handle cask packages
            local cask_name=${package% (cask)}
            log_info "Removing cask: $cask_name"
            brew uninstall --cask "$cask_name" || log_warning "Failed to remove cask: $cask_name"
        else
            # Handle formula packages
            log_info "Removing formula: $package"
            brew uninstall "$package" || log_warning "Failed to remove formula: $package"
        fi
    done
    
    log_success "Package removal completed"
}

# Check if any packages depend on QEMU/Virgl
check_dependencies() {
    local packages_str="$1"
    
    if [ -z "$packages_str" ]; then
        return 0
    fi
    
    local packages_array=($packages_str)
    local has_dependents=false
    
    log_info "Checking for packages that depend on QEMU/Virgl..."
    
    for package in "${packages_array[@]}"; do
        if [[ "$package" == *"(cask)"* ]]; then
            continue  # Skip cask dependency checks
        fi
        
        local dependents=$(brew uses --installed "$package" 2>/dev/null || true)
        if [ ! -z "$dependents" ]; then
            log_warning "Package '$package' is used by:"
            echo "$dependents" | sed 's/^/  - /'
            has_dependents=true
        fi
    done
    
    if [ "$has_dependents" = true ]; then
        echo
        log_warning "Some packages have dependents. You may need to reinstall them after installing QEMU 3dfx."
        return 1
    fi
    
    return 0
}

# Main cleanup function
main_cleanup() {
    local check_only="$1"
    local force="$2"
    local create_backup="$3"
    
    log_info "Starting Homebrew QEMU/Virgl cleanup..."
    
    # Check what's installed
    log_info "Checking for installed QEMU and Virgl packages..."
    local installed_packages=$(check_installed_packages)
    
    if [ -z "$installed_packages" ]; then
        log_success "No conflicting packages found - ready for QEMU 3dfx installation!"
        return 0
    fi
    
    # Show what was found
    log_info "Found the following packages:"
    while IFS= read -r package; do
        log_warning "  - $package"
    done <<< "$installed_packages"
    
    # Check dependencies
    if [ "$force" != "true" ]; then
        check_dependencies "$installed_packages"
    fi
    
    # Create backup if requested
    local backup_file=""
    if [ "$create_backup" = "true" ]; then
        backup_file=$(backup_packages)
    fi
    
    # Remove packages or just show what would be removed
    if [ "$check_only" = "true" ]; then
        echo
        log_info "DRY RUN - The following packages would be removed:"
        while IFS= read -r package; do
            echo "  - $package"
        done <<< "$installed_packages"
        echo
        log_info "Run without --check-only to actually remove these packages"
    else
        remove_packages "$installed_packages" "$force"
        
        if [ ! -z "$backup_file" ]; then
            echo
            log_info "Backup created at: $backup_file"
            log_info "To restore these packages later, run: $0 --restore"
        fi
        
        echo
        log_success "Cleanup completed - ready for QEMU 3dfx installation!"
        log_info "You can now run: brew tap startergo/qemu3dfx && brew install qemu-3dfx"
    fi
}

# Main script logic
case "${1:-cleanup}" in
    cleanup|"")
        main_cleanup false false false
        ;;
    --check-only)
        main_cleanup true false false
        ;;
    --backup)
        main_cleanup false false true
        ;;
    --force)
        main_cleanup false true false
        ;;
    --force-backup)
        main_cleanup false true true
        ;;
    --restore)
        restore_packages
        ;;
    --help|-h|help)
        show_help
        ;;
    *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
