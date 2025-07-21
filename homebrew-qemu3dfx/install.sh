#!/bin/bash

# QEMU 3dfx Homebrew Tap Installation Script
# Installs the tap and QEMU 3dfx components

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
QEMU 3dfx Homebrew Tap Installer

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --tap-only      Add tap only (don't install packages)
    --virgl-only    Install only virglrenderer-3dfx
    --glide-only    Install only glide-3dfx  
    --qemu-only     Install only qemu-3dfx
    --all           Install all components (default)
    --help          Show this help

DESCRIPTION:
    This script adds the QEMU 3dfx Homebrew tap and installs the components.
    
    IMPORTANT: This script will check for and remove conflicting Homebrew
    packages (like standard qemu, virglrenderer) to avoid conflicts.
    A backup of removed packages will be created automatically.
    
    Components available:
    - virglrenderer-3dfx: Virgl3D renderer with macOS patches
    - glide-3dfx: 3dfx Glide wrapper libraries
    - qemu-3dfx: QEMU with 3dfx and Virgl3D support

EXAMPLES:
    $0                  # Install tap and all components (with cleanup)
    $0 --qemu-only      # Install only QEMU 3dfx (with cleanup)
    $0 --tap-only       # Add tap but don't install anything

CLEANUP:
    Run './cleanup.sh --check-only' to see what packages would be removed
    Run './cleanup.sh --restore' to restore previously removed packages

EOF
}

check_homebrew() {
    log_info "Checking Homebrew installation..."
    
    if ! command -v brew &> /dev/null; then
        log_error "Homebrew is required but not installed."
        log_info "Install Homebrew from: https://brew.sh/"
        exit 1
    fi
    
    local brew_version=$(brew --version | head -1)
    log_success "Homebrew found: $brew_version"
}

check_system() {
    log_info "Checking system requirements..."
    
    # Check macOS version
    local macos_version=$(sw_vers -productVersion)
    log_info "macOS version: $macos_version"
    
    # Check architecture
    local arch=$(uname -m)
    log_info "Architecture: $arch"
    
    # Check Xcode Command Line Tools
    if ! xcode-select -p &> /dev/null; then
        log_error "Xcode Command Line Tools not installed."
        log_info "Install with: xcode-select --install"
        exit 1
    fi
    log_success "Xcode Command Line Tools found"
    
    # Check available disk space
    local available_space=$(df -h . | awk 'NR==2 {print $4}')
    log_info "Available disk space: $available_space"
}

add_tap() {
    log_info "Adding QEMU 3dfx Homebrew tap..."
    
    # Check if tap is already added
    if brew tap | grep -q "startergo/qemu3dfx"; then
        log_info "Tap already added, updating..."
        brew tap startergo/qemu3dfx
    else
        log_info "Adding new tap..."
        brew tap startergo/qemu3dfx
    fi
    
    log_success "Tap added successfully"
}

cleanup_conflicting_packages() {
    log_info "Checking for conflicting Homebrew packages..."
    
    # Run our cleanup script with backup
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$script_dir/cleanup.sh" ]; then
        log_info "Running cleanup script..."
        bash "$script_dir/cleanup.sh" --backup
    else
        # Manual cleanup if script not found
        log_warning "Cleanup script not found, performing manual cleanup..."
        
        local conflicting_packages=()
        
        # Check for common conflicting packages
        for package in qemu virglrenderer qemu-virgl-deps; do
            if brew list --formula "$package" &> /dev/null; then
                conflicting_packages+=("$package")
            fi
        done
        
        if [ ${#conflicting_packages[@]} -gt 0 ]; then
            log_warning "Found conflicting packages: ${conflicting_packages[*]}"
            echo -n "Remove these packages to avoid conflicts? [y/N]: "
            read -r confirm
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                for package in "${conflicting_packages[@]}"; do
                    log_info "Removing $package..."
                    brew uninstall "$package" || log_warning "Failed to remove $package"
                done
            else
                log_warning "Conflicting packages not removed - installation may fail"
            fi
        else
            log_success "No conflicting packages found"
        fi
    fi
}

install_component() {
    local component="$1"
    log_info "Installing $component..."
    
    if brew list "$component" &> /dev/null; then
        log_info "$component already installed, upgrading..."
        brew upgrade "$component" || brew reinstall "$component"
    else
        brew install "$component"
    fi
    
    log_success "$component installed successfully"
}

install_virgl() {
    install_component "virglrenderer-3dfx"
}

install_glide() {
    install_component "glide-3dfx"
}

install_qemu() {
    install_component "qemu-3dfx"
}

install_all() {
    log_info "Installing all QEMU 3dfx components..."
    
    # Install in dependency order
    install_virgl
    install_glide
    install_qemu
    
    log_success "All components installed successfully"
}

verify_installation() {
    log_info "Verifying installation..."
    
    # Check QEMU
    if command -v qemu-system-x86_64 &> /dev/null; then
        local qemu_version=$(qemu-system-x86_64 --version | head -1)
        log_success "QEMU found: $qemu_version"
        
        # Test 3dfx support
        if qemu-system-i386 -device help | grep -q "3dfx"; then
            log_success "3dfx device support verified"
        else
            log_warning "3dfx device support not detected"
        fi
        
        # Test Virgl support
        if qemu-system-x86_64 -device help | grep -q "virtio-vga-gl"; then
            log_success "Virgl3D support verified"
        else
            log_warning "Virgl3D support not detected"
        fi
    else
        log_warning "QEMU not found in PATH"
    fi
    
    # Check libraries
    local brew_prefix=$(brew --prefix)
    
    if [ -f "$brew_prefix/lib/libvirglrenderer.dylib" ]; then
        log_success "Virglrenderer library found"
    fi
    
    if [ -f "$brew_prefix/lib/libglide2x.dylib" ] || [ -f "$brew_prefix/lib/libglide3x.dylib" ]; then
        log_success "Glide libraries found"
    fi
}

show_usage_examples() {
    local brew_prefix=$(brew --prefix)
    
    cat << EOF

${GREEN}Installation completed successfully!${NC}

${YELLOW}Usage Examples:${NC}

# Run DOS/Windows 9x with 3dfx Voodoo support:
qemu-system-i386 \\
  -machine pc-i440fx-2.1 \\
  -cpu pentium2 \\
  -m 128 \\
  -device 3dfx,voodoo=voodoo2 \\
  -hda dos.img \\
  -display sdl

# Run Linux with Virgl3D acceleration:
qemu-system-x86_64 \\
  -enable-kvm \\
  -m 2048 \\
  -device virtio-vga-gl \\
  -display sdl,gl=on \\
  -hda linux.img

${YELLOW}Troubleshooting:${NC}

# If you get library errors, create compatibility symlinks:
sudo ln -sf $brew_prefix/lib/libglide2x.dylib /usr/local/lib/
sudo ln -sf $brew_prefix/lib/libglide3x.dylib /usr/local/lib/

# If code signing issues occur:
codesign --force --deep --sign - $brew_prefix/bin/qemu-*

${YELLOW}More Information:${NC}
- Tap documentation: brew info qemu-3dfx
- Source repository: https://github.com/startergo/qemu-3dfx-macos

EOF
}

# Main installation logic
main() {
    log_info "Starting QEMU 3dfx Homebrew installation..."
    
    check_homebrew
    check_system
    cleanup_conflicting_packages
    add_tap
    
    case "${1:---all}" in
        --tap-only)
            log_success "Tap added successfully - ready for manual installation"
            ;;
        --virgl-only)
            install_virgl
            verify_installation
            ;;
        --glide-only)
            install_glide
            verify_installation
            ;;
        --qemu-only)
            install_qemu
            verify_installation
            ;;
        --all)
            install_all
            verify_installation
            show_usage_examples
            ;;
        --help|-h|help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    
    log_success "Installation completed!"
}

# Run main function with all arguments
main "$@"
