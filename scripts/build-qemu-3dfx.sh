#!/bin/bash

# QEMU 3dfx/Virgl3D Build Script for macOS
# Builds QEMU 9.2.2 with 3dfx patches and Virgl3D support using SDL2+OpenGL
# Author: GitHub Copilot (based on KJ's qemu-3dfx project)

set -e  # Exit on any error

# Configuration
QEMU_VERSION="${QEMU_VERSION:-9.2.2}"
QEMU_URL="https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz"
VIRGLRENDERER_URL="https://gitlab.freedesktop.org/virgl/virglrenderer.git"
VIRGLRENDERER_BRANCH="main"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
QEMU_SRC_DIR="${BUILD_DIR}/qemu-${QEMU_VERSION}"
QEMU_BUILD_DIR="${QEMU_SRC_DIR}/build"
QEMU_INSTALL_DIR="${BUILD_DIR}/qemu-install/opt/homebrew"
VIRGL_SRC_DIR="${BUILD_DIR}/virglrenderer"
VIRGL_BUILD_DIR="${VIRGL_SRC_DIR}/build"
VIRGL_INSTALL_DIR="${BUILD_DIR}/virglrenderer-install"
BACKUP_DIR="${HOME}/.qemu-3dfx-macos-backup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Help function
show_help() {
    cat << EOF
QEMU 3dfx/Virgl3D Build Script for macOS

USAGE:
    $0 [COMMAND]

COMMANDS:
    build               Build QEMU with 3dfx/Virgl3D support (default)
    clean               Clean build directories
    backup-homebrew     Backup Homebrew virglrenderer packages
    restore-homebrew    Restore Homebrew virglrenderer packages
    check-env           Check build environment (for fresh installs)
    package             Create deployment package with proper structure
    info                Show build information
    help                Show this help message

DESCRIPTION:
    This script builds QEMU ${QEMU_VERSION} with KJ's 3dfx patches and Virgl3D support.
    It automatically handles dependencies, builds virglrenderer from source,
    and configures QEMU for SDL2+OpenGL (not Cocoa) on macOS.

    The built QEMU will support i386, x86_64, and aarch64 targets with:
    - 3dfx Voodoo emulation (from KJ's patches)
    - Virgl3D OpenGL acceleration
    - SDL2 display backend

EXAMPLES:
    $0                  # Build QEMU with 3dfx/Virgl3D support
    $0 clean            # Clean all build files
    $0 backup-homebrew  # Backup conflicting Homebrew packages
    $0 info             # Show information about the build

REQUIREMENTS:
    - Homebrew with development tools
    - Xcode command line tools
    - At least 4GB free disk space

EOF
}

# Check if Homebrew is installed and get prefix
get_homebrew_prefix() {
    if ! command -v brew &> /dev/null; then
        log_error "Homebrew is required but not installed."
        log_info "Install Homebrew from: https://brew.sh/"
        exit 1
    fi
    
    # Get the actual Homebrew prefix (works on both Intel and Apple Silicon)
    HOMEBREW_PREFIX=$(brew --prefix)
    log_success "Homebrew found at: $HOMEBREW_PREFIX"
    export HOMEBREW_PREFIX
}

# Verify fresh install environment
verify_environment() {
    log_info "Verifying build environment..."
    
    # Check for Xcode command line tools
    if ! xcode-select -p &> /dev/null; then
        log_error "Xcode command line tools not installed."
        log_info "Install with: xcode-select --install"
        exit 1
    fi
    log_success "Xcode command line tools found"
    
    # Check for essential build tools
    local essential_tools=("git" "make" "gcc" "clang")
    for tool in "${essential_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool not found. Install Xcode command line tools."
            exit 1
        fi
    done
    log_success "Essential build tools verified"
    
    # Check for XQuartz (required for Mesa GL context support)
    if [ ! -d "/opt/X11" ]; then
        # In CI environments, check if we have the necessary X11 libraries from Homebrew instead
        if [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ]; then
            log_warning "XQuartz directory not found, but this is a CI environment."
            log_info "Checking for X11 libraries in Homebrew instead..."
            if [ -f "/opt/homebrew/lib/libX11.dylib" ]; then
                log_success "Found Homebrew X11 libraries, proceeding with build"
            else
                log_error "No X11 libraries found in either XQuartz or Homebrew"
                exit 1
            fi
        else
            log_error "XQuartz is required but not installed."
            log_info "XQuartz provides X11 libraries needed for Mesa GL context support."
            log_info "Install XQuartz from: https://www.xquartz.org/"
            log_info "Or via Homebrew: brew install --cask xquartz"
            exit 1
        fi
    else
        log_success "XQuartz found at /opt/X11"
    fi
    
    # Check disk space (need at least 4GB)
    local free_space=$(df -h . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ "$free_space" =~ ^[0-9]+$ ]] && [ "$free_space" -lt 4 ]; then
        log_warning "Low disk space: ${free_space}GB available. Need at least 4GB."
    else
        log_success "Sufficient disk space available"
    fi
}

# Check if Homebrew is installed
check_homebrew() {
    get_homebrew_prefix
}

# Check EGL availability and configure accordingly
check_egl_support() {
    log_info "Checking EGL support..."
    
    # Check if epoxy was built with EGL support
    if [ -d "${HOMEBREW_PREFIX}/Cellar/libepoxy" ]; then
        local epoxy_version=$(ls "${HOMEBREW_PREFIX}/Cellar/libepoxy" | head -1)
        local epoxy_include_dir="${HOMEBREW_PREFIX}/Cellar/libepoxy/${epoxy_version}/include"
        
        if [ -f "${epoxy_include_dir}/epoxy/egl.h" ]; then
            log_success "EGL headers found in libepoxy"
            return 0
        else
            log_warning "EGL headers not found in libepoxy - will use GLX only"
            return 1
        fi
    else
        log_warning "libepoxy not found"
        return 1
    fi
}

# Check and install dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    # Set up PKG_CONFIG_PATH to include Homebrew paths
    export PKG_CONFIG_PATH="${HOMEBREW_PREFIX}/lib/pkgconfig:$PKG_CONFIG_PATH"
    
    # Find and add libepoxy path specifically
    if [ -d "${HOMEBREW_PREFIX}/Cellar/libepoxy" ]; then
        local epoxy_version=$(ls "${HOMEBREW_PREFIX}/Cellar/libepoxy" | head -1)
        export PKG_CONFIG_PATH="${HOMEBREW_PREFIX}/Cellar/libepoxy/${epoxy_version}/lib/pkgconfig:$PKG_CONFIG_PATH"
        log_info "Added libepoxy PKG_CONFIG_PATH: ${HOMEBREW_PREFIX}/Cellar/libepoxy/${epoxy_version}/lib/pkgconfig"
    fi
    
    # Get current Python version from Homebrew
    local python_version=""
    if brew list --formula | grep -q "python@"; then
        python_version=$(brew list --formula | grep "python@" | head -1)
        log_info "Found existing Python: $python_version"
    else
        # Default to latest stable Python if none installed
        python_version="python@3.12"
        log_info "Will install default Python: $python_version"
    fi
    
    local deps=(
        "git"
        "wget"
        "cmake"
        "ninja"
        "meson"
        "pkg-config"
        "glib"
        "pixman"
        "sdl2"
        "sdl2_image"
        "sdl2_net"
        "sdl2_sound" 
        "sdl12-compat"
        "mt32emu"
        "libepoxy"
        "$python_version"
        "gettext"
        "libffi"
    )
    
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! brew list "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_warning "Missing dependencies: ${missing_deps[*]}"
        log_info "Installing missing dependencies..."
        
        # Install dependencies one by one to catch failures
        for dep in "${missing_deps[@]}"; do
            log_info "Installing $dep..."
            if ! brew install "$dep"; then
                log_error "Failed to install $dep"
                exit 1
            fi
        done
        
        log_success "All missing dependencies installed"
    fi
    
    # Ensure libepoxy is linked and test pkg-config
    if ! brew list --formula libepoxy &> /dev/null; then
        log_error "libepoxy not installed"
        exit 1
    fi
    
    # Force relink libepoxy if needed
    brew link --overwrite libepoxy 2>/dev/null || true
    
    if ! pkg-config --exists epoxy; then
        log_warning "pkg-config cannot find epoxy, attempting to fix..."
        
        # Try to fix by updating pkg-config paths
        if [ -d "${HOMEBREW_PREFIX}/Cellar/libepoxy" ]; then
            local epoxy_version=$(ls "${HOMEBREW_PREFIX}/Cellar/libepoxy" | head -1)
            export PKG_CONFIG_PATH="${HOMEBREW_PREFIX}/Cellar/libepoxy/${epoxy_version}/lib/pkgconfig:$PKG_CONFIG_PATH"
        fi
        
        # Test again
        if ! pkg-config --exists epoxy; then
            log_error "Failed to configure pkg-config for libepoxy"
            log_info "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
            log_info "Try running: brew reinstall libepoxy"
            exit 1
        fi
    fi
    
    log_success "All dependencies checked and configured"
}

# Backup and remove conflicting packages
backup_homebrew() {
    log_info "Backing up Homebrew virglrenderer packages..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Check and backup virglrenderer
    if brew list virglrenderer &> /dev/null; then
        log_info "Backing up virglrenderer..."
        echo "virglrenderer" > "$BACKUP_DIR/virglrenderer.txt"
        brew uninstall virglrenderer
        log_success "virglrenderer backed up and removed"
    fi
    
    # Check and backup qemu-virgl-deps if it exists
    if brew list qemu-virgl-deps &> /dev/null; then
        log_info "Backing up qemu-virgl-deps..."
        echo "qemu-virgl-deps" > "$BACKUP_DIR/qemu-virgl-deps.txt"
        
        # Before removing, check if it would remove essential build tools
        local deps_to_remove=$(brew deps --tree qemu-virgl-deps | grep -E "(meson|ninja|cmake)" | head -5)
        if [ ! -z "$deps_to_remove" ]; then
            log_warning "qemu-virgl-deps removal would affect build tools. Installing them separately first..."
            brew install meson ninja cmake pkg-config
        fi
        
        brew uninstall qemu-virgl-deps
        log_success "qemu-virgl-deps backed up and removed"
    fi
    
    if [ ! -f "$BACKUP_DIR/virglrenderer.txt" ] && [ ! -f "$BACKUP_DIR/qemu-virgl-deps.txt" ]; then
        log_info "No conflicting Homebrew packages found"
    fi
}

# Restore Homebrew virglrenderer packages
restore_homebrew() {
    log_info "Restoring Homebrew packages..."
    
    if [ -f "$BACKUP_DIR/virglrenderer.txt" ]; then
        log_info "Restoring virglrenderer..."
        brew install virglrenderer
        rm -f "$BACKUP_DIR/virglrenderer.txt"
        log_success "virglrenderer restored"
    fi
    
    if [ -f "$BACKUP_DIR/qemu-virgl-deps.txt" ]; then
        log_info "Restoring qemu-virgl-deps..."
        brew install qemu-virgl-deps
        rm -f "$BACKUP_DIR/qemu-virgl-deps.txt"
        log_success "qemu-virgl-deps restored"
    fi
    
    if [ -d "$BACKUP_DIR" ] && [ -z "$(ls -A "$BACKUP_DIR")" ]; then
        rmdir "$BACKUP_DIR"
    fi
}

# Download and extract QEMU source
download_qemu() {
    log_info "Downloading QEMU ${QEMU_VERSION}..."
    
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    if [ ! -f "qemu-${QEMU_VERSION}.tar.xz" ]; then
        wget "$QEMU_URL"
    fi
    
    if [ ! -d "qemu-${QEMU_VERSION}" ]; then
        log_info "Extracting QEMU source..."
        tar -xf "qemu-${QEMU_VERSION}.tar.xz"
    fi
    
    log_success "QEMU source ready"
}

# Clone virglrenderer
clone_virglrenderer() {
    log_info "Cloning virglrenderer..."
    
    cd "$BUILD_DIR"
    
    if [ ! -d "virglrenderer" ]; then
        git clone "$VIRGLRENDERER_URL" virglrenderer
    fi
    
    cd virglrenderer
    git checkout "$VIRGLRENDERER_BRANCH"
    git pull origin "$VIRGLRENDERER_BRANCH"
    
    log_success "virglrenderer source ready"
}

# Apply patches
apply_patches() {
    log_info "Applying patches..."
    
    cd "$QEMU_SRC_DIR"
    
    # Apply KJ's Mesa/Glide patches based on QEMU version
    PATCH_FILE=""
    case "$QEMU_VERSION" in
        10.0.*|10.1.*|10.2.*)
            PATCH_FILE="00-qemu100x-mesa-glide.patch"
            ;;
        9.2.*)
            PATCH_FILE="00-qemu92x-mesa-glide.patch"
            ;;
        8.2.*)
            PATCH_FILE="01-qemu82x-mesa-glide.patch"
            ;;
        7.2.*)
            PATCH_FILE="02-qemu72x-mesa-glide.patch"
            ;;
        *)
            log_warning "No specific patch found for QEMU version $QEMU_VERSION, trying 9.2.x patch"
            PATCH_FILE="00-qemu92x-mesa-glide.patch"
            ;;
    esac
    
    if [ -f "${PROJECT_ROOT}/${PATCH_FILE}" ]; then
        log_info "Applying ${PATCH_FILE} for QEMU ${QEMU_VERSION}..."
        if ! git apply --check "${PROJECT_ROOT}/${PATCH_FILE}" 2>/dev/null; then
            log_warning "Patch may already be applied or conflicts exist"
        else
            git apply "${PROJECT_ROOT}/${PATCH_FILE}"
            log_success "Applied ${PATCH_FILE} successfully"
        fi
    else
        log_error "Patch file ${PATCH_FILE} not found!"
        return 1
    fi
    
    # Apply Virgl3D patches if available
    if [ -d "${PROJECT_ROOT}/virgil3d" ]; then
        for patch in "${PROJECT_ROOT}/virgil3d"/*.patch; do
            if [ -f "$patch" ]; then
                log_info "Applying $(basename "$patch")..."
                if ! git apply --check "$patch" 2>/dev/null; then
                    log_warning "Patch $(basename "$patch") may already be applied or conflicts exist"
                else
                    git apply "$patch"
                fi
            fi
        done
    fi
    
    # Apply experimental patches if requested
    if [ "${APPLY_EXPERIMENTAL_PATCHES:-false}" = "true" ]; then
        log_info "Applying experimental patches..."
        
        # Select version-specific SDL clipboard patch
        SDL_CLIPBOARD_PATCH=""
        case "$QEMU_VERSION" in
            10.0.2)
                SDL_CLIPBOARD_PATCH="${PROJECT_ROOT}/qemu-exp/SDL-Clipboard-10.0.2-fixed.patch"
                ;;
            10.0.*)
                SDL_CLIPBOARD_PATCH="${PROJECT_ROOT}/qemu-exp/SDL-Clipboard.patch"
                ;;
            9.2.*)
                SDL_CLIPBOARD_PATCH="${PROJECT_ROOT}/qemu-exp/SDL-Clipboard-9.2.2.patch"
                ;;
        esac
        
        # Apply SDL clipboard patch if available
        if [ -f "$SDL_CLIPBOARD_PATCH" ]; then
            log_info "Applying experimental SDL-Clipboard patch for QEMU $QEMU_VERSION..."
            if ! git apply --check "$SDL_CLIPBOARD_PATCH" 2>/dev/null; then
                log_warning "SDL-Clipboard patch may already be applied or conflicts exist"
                log_warning "This is experimental - patch may need manual adaptation"
            else
                git apply "$SDL_CLIPBOARD_PATCH"
                log_success "SDL-Clipboard patch applied successfully"
            fi
        else
            log_warning "SDL-Clipboard patch not found for QEMU version $QEMU_VERSION"
        fi
        
        # Apply other experimental patches if available
        for patch in "${PROJECT_ROOT}/qemu-exp"/*.patch; do
            if [ -f "$patch" ] && [[ "$(basename "$patch")" != "SDL-Clipboard.patch" ]] && [[ "$(basename "$patch")" != "SDL-Clipboard-9.2.2.patch" ]] && [[ "$(basename "$patch")" != "SDL-Clipboard-10.0.2.patch" ]] && [[ "$(basename "$patch")" != "SDL-Clipboard-10.0.2-fixed.patch" ]]; then
                log_info "Applying experimental patch: $(basename "$patch")..."
                if ! git apply --check "$patch" 2>/dev/null; then
                    log_warning "Experimental patch $(basename "$patch") may already be applied or conflicts exist"
                else
                    git apply "$patch"
                    log_success "Experimental patch $(basename "$patch") applied"
                fi
            fi
        done
    else
        log_info "Skipping experimental patches (not requested)"
    fi
    
    # Copy 3dfx and mesa source files
    if [ -d "${PROJECT_ROOT}/qemu-0/hw/3dfx" ]; then
        log_info "Copying 3dfx sources..."
        mkdir -p hw/3dfx
        cp -r "${PROJECT_ROOT}/qemu-0/hw/3dfx/"* hw/3dfx/
    fi
    
    if [ -d "${PROJECT_ROOT}/qemu-1/hw/mesa" ]; then
        log_info "Copying mesa sources..."
        mkdir -p hw/mesa
        cp -r "${PROJECT_ROOT}/qemu-1/hw/mesa/"* hw/mesa/
    fi
    
    # Apply GL_CONTEXTALPHA fix
    if [ -f "hw/mesa/mglcntx_linux.c" ]; then
        log_info "Applying GL_CONTEXTALPHA fix..."
        sed -i.bak 's/GL_CONTEXTALPHA/GLX_ALPHA_SIZE/g' hw/mesa/mglcntx_linux.c
    fi
    
    # Sign commit (embed commit identity in source code)
    if [ -f "${SCRIPT_DIR}/sign_commit" ]; then
        log_info "Signing commit (embedding commit identity)..."
        cd "$QEMU_SRC_DIR"
        bash "${SCRIPT_DIR}/sign_commit"
        if [ $? -eq 0 ]; then
            log_success "Commit identity embedded successfully"
        else
            log_warning "Failed to embed commit identity"
        fi
    else
        log_warning "sign_commit script not found, skipping commit signing"
    fi
    
    log_success "Patches applied"
}

# Build virglrenderer
build_virglrenderer() {
    log_info "Building virglrenderer..."
    
    cd "$VIRGL_SRC_DIR"
    
    # Clean previous build
    rm -rf "$VIRGL_BUILD_DIR"
    mkdir -p "$VIRGL_BUILD_DIR"
    
    # Set PKG_CONFIG_PATH for virglrenderer build
    export PKG_CONFIG_PATH="${HOMEBREW_PREFIX}/lib/pkgconfig:$PKG_CONFIG_PATH"
    
    # Add libepoxy path specifically
    if [ -d "${HOMEBREW_PREFIX}/Cellar/libepoxy" ]; then
        local epoxy_version=$(ls "${HOMEBREW_PREFIX}/Cellar/libepoxy" | head -1)
        export PKG_CONFIG_PATH="${HOMEBREW_PREFIX}/Cellar/libepoxy/${epoxy_version}/lib/pkgconfig:$PKG_CONFIG_PATH"
        log_info "Using libepoxy from: ${HOMEBREW_PREFIX}/Cellar/libepoxy/${epoxy_version}/lib/pkgconfig"
    fi
    
    # Configure with meson - macOS libepoxy doesn't support GLX/EGL
    log_info "Configuring virglrenderer for macOS (no platform extensions)"
    
    meson setup "$VIRGL_BUILD_DIR" \
        --prefix="$VIRGL_INSTALL_DIR" \
        --buildtype=release \
        -Dtests=false \
        -Dplatforms= \
        -Dminigbm_allocation=false \
        -Dvenus=false
    
    # Build and install
    cd "$VIRGL_BUILD_DIR"
    ninja
    ninja install
    
    log_success "virglrenderer built and installed"
}

# Build QEMU
build_qemu() {
    log_info "Building QEMU..."
    
    cd "$QEMU_SRC_DIR"
    
    # Clean previous build
    rm -rf "$QEMU_BUILD_DIR"
    mkdir -p "$QEMU_BUILD_DIR"
    cd "$QEMU_BUILD_DIR"
    
    # Set PKG_CONFIG_PATH to find our custom virglrenderer and homebrew packages
    export PKG_CONFIG_PATH="${VIRGL_INSTALL_DIR}/lib/pkgconfig:${HOMEBREW_PREFIX}/lib/pkgconfig"
    
    # Add libepoxy path specifically
    if [ -d "${HOMEBREW_PREFIX}/Cellar/libepoxy" ]; then
        local epoxy_version=$(ls "${HOMEBREW_PREFIX}/Cellar/libepoxy" | head -1)
        export PKG_CONFIG_PATH="${HOMEBREW_PREFIX}/Cellar/libepoxy/${epoxy_version}/lib/pkgconfig:$PKG_CONFIG_PATH"
        log_info "Using libepoxy from: ${HOMEBREW_PREFIX}/Cellar/libepoxy/${epoxy_version}/lib/pkgconfig"
    fi
    
    # Configure QEMU with the EXACT configuration that was proven to work
    log_info "Using the exact configuration that built successfully..."
    
    # First, let's try to patch the meson.build to make EGL optional
    if grep -q "error('epoxy/egl.h not found')" ../meson.build; then
        log_info "Patching meson.build to make EGL optional on macOS..."
        sed -i.bak "s/error('epoxy\/egl.h not found')/warning('epoxy\/egl.h not found - EGL disabled')/" ../meson.build
    fi
    
    # Set up environment variables for Homebrew paths
    export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    export CFLAGS="-I/opt/homebrew/include -I/usr/local/include ${CFLAGS:-}"
    export LDFLAGS="-L/opt/homebrew/lib -L/opt/X11/lib ${LDFLAGS:-}"
    export CPPFLAGS="-I/opt/homebrew/include -I/usr/local/include ${CPPFLAGS:-}"
    
    # Determine target list based on host architecture for optimal build efficiency
    local host_arch=$(uname -m)
    local target_list=""
    
    if [ "$host_arch" = "arm64" ]; then
        # ARM64 (Apple Silicon) can efficiently build all targets including ARM
        target_list="i386-softmmu,x86_64-softmmu,aarch64-softmmu"
        log_info "Building for ARM64 host: including all targets (x86 + ARM)"
    else
        # Intel x86_64 should only build x86 targets for efficiency
        target_list="i386-softmmu,x86_64-softmmu"
        log_info "Building for Intel host: x86 targets only for optimal performance"
    fi
    
    ../configure \
        --prefix="${QEMU_INSTALL_DIR}" \
        --target-list="$target_list" \
        --enable-sdl \
        --enable-opengl \
        --disable-cocoa \
        --enable-virglrenderer \
        --disable-gtk \
        --disable-dbus-display \
        --disable-curses \
        --enable-vnc \
        --enable-hvf \
        --disable-tcg-interpreter \
        --disable-guest-agent \
        --disable-docs
    
    # Build with ninja (QEMU 9.2.2 uses meson/ninja build system)
    # Limit parallel jobs to reduce memory usage on CI
    ninja -j$(( $(nproc 2>/dev/null || echo 4) / 2 ))
    
    log_success "QEMU built successfully"
    
    # Install QEMU to the install directory
    log_info "Installing QEMU to ${QEMU_INSTALL_DIR}..."
    mkdir -p "${QEMU_INSTALL_DIR}"
    ninja install
    
    log_success "QEMU installed to ${QEMU_INSTALL_DIR}"
    
    # Debug: List what was actually built
    log_info "Built binaries in $(pwd):"
    ls -la qemu-system-* qemu-img* 2>/dev/null || log_warning "No QEMU binaries found in build directory"
}

# Verify build
verify_build() {
    log_info "Verifying build..."
    
    # Determine which binaries should exist based on host architecture
    local host_arch=$(uname -m)
    local base_binaries=("qemu-system-i386" "qemu-system-x86_64" "qemu-img")
    
    if [ "$host_arch" = "arm64" ]; then
        # ARM64 hosts build ARM targets too
        base_binaries+=("qemu-system-aarch64")
        log_info "Verifying ARM64 host build: checking x86 + ARM targets"
    else
        # Intel hosts only build x86 targets
        log_info "Verifying Intel host build: checking x86 targets only"
    fi
    
    local found_count=0
    local test_binary=""
    
    for base_name in "${base_binaries[@]}"; do
        # Check for both unsigned and regular versions
        local unsigned_binary="${QEMU_BUILD_DIR}/${base_name}-unsigned"
        local regular_binary="${QEMU_BUILD_DIR}/${base_name}"
        
        if [ -f "$unsigned_binary" ]; then
            log_success "Found: $(basename "$unsigned_binary")"
            found_count=$((found_count + 1))
            if [ -z "$test_binary" ]; then
                test_binary="$unsigned_binary"
            fi
            
            # Create symlink without -unsigned suffix for compatibility
            ln -sf "$(basename "$unsigned_binary")" "$regular_binary" 2>/dev/null || true
            
        elif [ -f "$regular_binary" ]; then
            log_success "Found: $(basename "$regular_binary")"
            found_count=$((found_count + 1))
            if [ -z "$test_binary" ]; then
                test_binary="$regular_binary"
            fi
        else
            log_warning "Missing: $base_name (may not have been built)"
        fi
    done
    
    if [ $found_count -eq 0 ]; then
        log_error "No QEMU binaries found - build failed"
        return 1
    fi
    
    log_success "Found $found_count QEMU binaries"
    
    # Test one binary
    log_info "Testing QEMU binary: $(basename "$test_binary")..."
    if "$test_binary" --version > /dev/null 2>&1; then
        log_success "QEMU binary is functional"
    else
        log_error "QEMU binary test failed"
        return 1
    fi
    
    log_success "Build verification complete"
}

# Show build information
show_info() {
    cat << EOF

${GREEN}QEMU 3dfx/Virgl3D Build Information${NC}

Build Directory: $BUILD_DIR
QEMU Version: $QEMU_VERSION
QEMU Source: $QEMU_SRC_DIR
QEMU Build: $QEMU_BUILD_DIR

Virglrenderer Source: $VIRGL_SRC_DIR
Virglrenderer Install: $VIRGL_INSTALL_DIR

Backup Directory: $BACKUP_DIR

EOF

    if [ -d "$QEMU_BUILD_DIR" ]; then
        echo -e "${GREEN}Built QEMU Binaries:${NC}"
        find "$QEMU_BUILD_DIR" -name "qemu-system-*" -type f | head -10
        find "$QEMU_BUILD_DIR" -name "qemu-img*" -type f | head -5
        echo
    fi
    
    if [ -f "$BACKUP_DIR/virglrenderer.txt" ] || [ -f "$BACKUP_DIR/qemu-virgl-deps.txt" ]; then
        echo -e "${YELLOW}Homebrew Packages Backed Up:${NC}"
        [ -f "$BACKUP_DIR/virglrenderer.txt" ] && echo "  - virglrenderer"
        [ -f "$BACKUP_DIR/qemu-virgl-deps.txt" ] && echo "  - qemu-virgl-deps"
        echo
    fi
    
    cat << EOF
${GREEN}Usage Examples:${NC}

# Run a VM with 3dfx support:
${QEMU_BUILD_DIR}/qemu-system-i386 \\
  -machine pc-i440fx-2.1 \\
  -cpu pentium2 \\
  -m 128 \\
  -device 3dfx,voodoo=voodoo2 \\
  -hda dos.img

# Run a VM with Virgl3D support:
${QEMU_BUILD_DIR}/qemu-system-x86_64 \\
  -enable-kvm \\
  -m 2048 \\
  -device virtio-vga-gl \\
  -display sdl,gl=on \\
  -hda linux.img

EOF
}

# Clean build directories
clean_build() {
    log_info "Cleaning build directories..."
    
    rm -rf "$BUILD_DIR"
    
    log_success "Build directories cleaned"
}

# Test build
test_build() {
    log_info "Running build tests..."
    
    if [ ! -f "${QEMU_BUILD_DIR}/qemu-system-x86_64" ]; then
        log_error "QEMU binary not found. Run build first."
        return 1
    fi
    
    # Test version
    log_info "Testing QEMU version..."
    "${QEMU_BUILD_DIR}/qemu-system-x86_64" --version
    
    # Test help (3dfx device should be listed)
    log_info "Checking for 3dfx device support..."
    if "${QEMU_BUILD_DIR}/qemu-system-i386" -device help | grep -q "3dfx"; then
        log_success "3dfx device support detected"
    else
        log_warning "3dfx device support not detected"
    fi
    
    # Test Virgl support
    log_info "Checking for Virgl support..."
    if "${QEMU_BUILD_DIR}/qemu-system-x86_64" -device help | grep -q "virtio-vga-gl"; then
        log_success "Virgl3D support detected"
    else
        log_warning "Virgl3D support not detected"
    fi
    
    log_success "Build tests complete"
}

# Package QEMU for deployment
package_qemu() {
    log_info "Creating deployment package..."
    
    if [ ! -f "${QEMU_BUILD_DIR}/qemu-system-i386" ]; then
        log_error "QEMU binary not found. Run build first."
        return 1
    fi
    
    # Get Git commit hash for package naming
    cd "$QEMU_SRC_DIR"
    COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    
    # Get architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        arm64|aarch64) ARCH="arm64" ;;
        x86_64) ARCH="x86_64" ;;
        *) ARCH="unknown" ;;
    esac
    
    # Package name
    PACKAGE_NAME="qemu-${QEMU_VERSION}-3dfx-${COMMIT_HASH}-darwin-${ARCH}"
    PACKAGE_DIR="${BUILD_DIR}/${PACKAGE_NAME}"
    
    log_info "Creating package structure: ${PACKAGE_NAME}"
    
    # Create directory structure
    mkdir -p "${PACKAGE_DIR}/opt/homebrew/bin"
    mkdir -p "${PACKAGE_DIR}/opt/homebrew/lib"
    mkdir -p "${PACKAGE_DIR}/opt/homebrew/share/qemu"
    mkdir -p "${PACKAGE_DIR}/opt/homebrew/sign"
    mkdir -p "${PACKAGE_DIR}/usr/local/lib"
    
    # Copy QEMU binaries
    log_info "Copying QEMU binaries..."
    cp "${QEMU_BUILD_DIR}/qemu-system-i386" "${PACKAGE_DIR}/opt/homebrew/bin/"
    cp "${QEMU_BUILD_DIR}/qemu-img" "${PACKAGE_DIR}/opt/homebrew/bin/"
    
    # Copy QEMU data files
    log_info "Copying QEMU data files..."
    if [ -d "${QEMU_BUILD_DIR}/pc-bios" ]; then
        cp "${QEMU_BUILD_DIR}/pc-bios"/*.bin "${PACKAGE_DIR}/opt/homebrew/share/qemu/" 2>/dev/null || true
        cp "${QEMU_BUILD_DIR}/pc-bios"/*.rom "${PACKAGE_DIR}/opt/homebrew/share/qemu/" 2>/dev/null || true
    fi
    
    # Copy homebrew dependencies using otool
    log_info "Copying Homebrew dependencies..."
    
    # Get all homebrew dependencies for main binaries
    for binary in "${PACKAGE_DIR}/opt/homebrew/bin"/*; do
        if [ -f "$binary" ]; then
            log_info "Processing dependencies for $(basename "$binary")..."
            otool -L "$binary" | grep homebrew | awk '{print $1}' | while read -r lib; do
                if [ -f "$lib" ]; then
                    lib_name=$(basename "$lib")
                    if [ ! -f "${PACKAGE_DIR}/opt/homebrew/lib/${lib_name}" ]; then
                        log_info "  Copying $lib_name"
                        cp "$lib" "${PACKAGE_DIR}/opt/homebrew/lib/"
                    fi
                fi
            done
        fi
    done
    
    # Copy virglrenderer libraries if they exist
    if [ -d "$VIRGL_INSTALL_DIR/lib" ]; then
        log_info "Copying virglrenderer libraries..."
        cp "$VIRGL_INSTALL_DIR/lib"/libvirglrenderer*.dylib "${PACKAGE_DIR}/opt/homebrew/lib/" 2>/dev/null || true
    fi
    
    # Create proper symlinks for libraries
    log_info "Creating library symlinks..."
    cd "${PACKAGE_DIR}/opt/homebrew/lib"
    
    # Create symlinks for versioned libraries
    for lib in *.*.dylib; do
        if [ -f "$lib" ]; then
            base_name=$(echo "$lib" | sed 's/\.[0-9]*\.dylib$/.dylib/')
            if [ "$base_name" != "$lib" ] && [ ! -L "$base_name" ]; then
                ln -sf "$lib" "$base_name"
                log_info "  Created symlink: $base_name -> $lib"
            fi
        fi
    done
    
    # Create symlinks in /usr/local/lib pointing to homebrew
    log_info "Creating /usr/local/lib symlinks..."
    cd "${PACKAGE_DIR}/usr/local/lib"
    
    # Key libraries that might be needed in /usr/local/lib
    for lib in libglide2x.dylib libglide3x.dylib libSDL2.dylib; do
        if [ -f "${PACKAGE_DIR}/opt/homebrew/lib/$lib" ]; then
            ln -sf "/opt/homebrew/lib/$lib" "$lib"
            log_info "  Created symlink: $lib -> /opt/homebrew/lib/$lib"
        fi
    done
    
    # Copy signing resources
    log_info "Copying signing resources..."
    if [ -f "${PROJECT_ROOT}/qemu.rsrc" ]; then
        cp "${PROJECT_ROOT}/qemu.rsrc" "${PACKAGE_DIR}/opt/homebrew/sign/"
    fi
    if [ -f "${PROJECT_ROOT}/scripts/qemu.sign" ]; then
        cp "${PROJECT_ROOT}/scripts/qemu.sign" "${PACKAGE_DIR}/opt/homebrew/sign/"
    elif [ -f "${PROJECT_ROOT}/qemu.sign" ]; then
        cp "${PROJECT_ROOT}/qemu.sign" "${PACKAGE_DIR}/opt/homebrew/sign/"
    fi
    
    # Create the compressed package
    log_info "Creating compressed package..."
    cd "$BUILD_DIR"
    
    # Use zstd if available, otherwise tar.xz
    if command -v zstd >/dev/null 2>&1; then
        tar -cf "${PACKAGE_NAME}.tar" "$PACKAGE_NAME"
        zstd "${PACKAGE_NAME}.tar" -o "${PACKAGE_NAME}.tar.zst"
        rm "${PACKAGE_NAME}.tar"
        PACKAGE_FILE="${PACKAGE_NAME}.tar.zst"
    else
        tar -cJf "${PACKAGE_NAME}.tar.xz" "$PACKAGE_NAME"
        PACKAGE_FILE="${PACKAGE_NAME}.tar.xz"
    fi
    
    # Show package information
    log_success "Package created successfully!"
    echo
    echo -e "${GREEN}Package Information:${NC}"
    echo "  Name: $PACKAGE_NAME"
    echo "  File: ${BUILD_DIR}/${PACKAGE_FILE}"
    echo "  Size: $(du -h "${BUILD_DIR}/${PACKAGE_FILE}" | cut -f1)"
    echo
    echo -e "${GREEN}Installation Commands:${NC}"
    echo "  # Extract package:"
    echo "  sudo tar xf ${PACKAGE_FILE} -C / 2>/dev/null"
    echo
    echo "  # Sign binaries (if needed):"
    echo "  cd \$(brew --prefix)/sign"
    echo "  bash ./qemu.sign"
    echo
    echo -e "${GREEN}Package Contents:${NC}"
    echo "  Binaries: $(find "${PACKAGE_DIR}/opt/homebrew/bin" -type f | wc -l | tr -d ' ') files"
    echo "  Libraries: $(find "${PACKAGE_DIR}/opt/homebrew/lib" -name "*.dylib" | wc -l | tr -d ' ') files"
    echo "  Data files: $(find "${PACKAGE_DIR}/opt/homebrew/share/qemu" -type f | wc -l | tr -d ' ') files"
    echo "  Symlinks: $(find "${PACKAGE_DIR}" -type l | wc -l | tr -d ' ') links"
    
    cd "$SCRIPT_DIR"
}

# Main build function
main_build() {
    log_info "Starting QEMU 3dfx/Virgl3D build process..."
    
    verify_environment
    check_homebrew
    check_dependencies
    backup_homebrew
    download_qemu
    clone_virglrenderer
    apply_patches
    build_virglrenderer
    build_qemu
    verify_build
    test_build
    
    log_success "Build completed successfully!"
    echo
    show_info
}

# Main script logic
case "${1:-build}" in
    build)
        main_build
        ;;
    clean)
        clean_build
        ;;
    backup-homebrew)
        backup_homebrew
        ;;
    restore-homebrew)
        restore_homebrew
        ;;
    check-env)
        verify_environment
        get_homebrew_prefix
        check_dependencies
        log_success "Environment check complete - ready for build!"
        ;;
    info)
        show_info
        ;;
    test)
        test_build
        ;;
    package)
        package_qemu
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        echo
        show_help
        exit 1
        ;;
esac
