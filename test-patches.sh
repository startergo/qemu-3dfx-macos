#!/bin/bash

# Test script to debug the apply_patches function

set -e  # Exit on any error

SCRIPT_DIR="/Users/macbookpro/qemu-3dfx-1"
QEMU_SRC_DIR="/Users/macbookpro/qemu-3dfx-1/build/qemu-9.2.2"

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

# Test apply_patches function
apply_patches() {
    log_info "Applying patches..."
    
    cd "$QEMU_SRC_DIR"
    
    # Apply KJ's Mesa/Glide patches
    if [ -f "${SCRIPT_DIR}/00-qemu92x-mesa-glide.patch" ]; then
        log_info "Found 00-qemu92x-mesa-glide.patch..."
        if ! git apply --check "${SCRIPT_DIR}/00-qemu92x-mesa-glide.patch" 2>/dev/null; then
            log_warning "Patch may already be applied or conflicts exist"
        else
            log_info "Would apply 00-qemu92x-mesa-glide.patch"
            # git apply "${SCRIPT_DIR}/00-qemu92x-mesa-glide.patch"
        fi
    else
        log_warning "00-qemu92x-mesa-glide.patch not found"
    fi
    
    # Apply Virgl3D patches to QEMU (root level patches)
    if [ -d "${SCRIPT_DIR}/virgil3d" ]; then
        log_info "Found virgil3d directory"
        for patch in "${SCRIPT_DIR}/virgil3d"/*.patch; do
            if [ -f "$patch" ]; then
                log_info "Found QEMU patch $(basename "$patch")..."
                if ! git apply --check "$patch" 2>/dev/null; then
                    log_warning "QEMU patch $(basename "$patch") may already be applied or conflicts exist"
                else
                    log_info "Would apply QEMU patch $(basename "$patch")"
                    # git apply "$patch"
                fi
            fi
        done
    else
        log_warning "virgil3d directory not found"
    fi
    
    # Copy 3dfx and mesa source files
    log_info "Checking source directories..."
    
    if [ -d "${SCRIPT_DIR}/qemu-0/hw/3dfx" ]; then
        log_info "Found 3dfx sources at ${SCRIPT_DIR}/qemu-0/hw/3dfx"
        log_info "Contents:"
        ls -la "${SCRIPT_DIR}/qemu-0/hw/3dfx" | head -10
        
        log_info "Copying 3dfx sources..."
        mkdir -p hw/3dfx
        cp -r "${SCRIPT_DIR}/qemu-0/hw/3dfx/"* hw/3dfx/
        log_success "3dfx sources copied"
    else
        log_warning "3dfx sources not found at ${SCRIPT_DIR}/qemu-0/hw/3dfx"
    fi
    
    if [ -d "${SCRIPT_DIR}/qemu-1/hw/mesa" ]; then
        log_info "Found mesa sources at ${SCRIPT_DIR}/qemu-1/hw/mesa"
        log_info "Contents:"
        ls -la "${SCRIPT_DIR}/qemu-1/hw/mesa" | head -10
        
        log_info "Copying mesa sources..."
        mkdir -p hw/mesa
        cp -r "${SCRIPT_DIR}/qemu-1/hw/mesa/"* hw/mesa/
        log_success "Mesa sources copied"
    else
        log_warning "Mesa sources not found at ${SCRIPT_DIR}/qemu-1/hw/mesa"
    fi
    
    # Check what was copied
    log_info "Checking copied files..."
    if [ -d "hw/3dfx" ]; then
        log_info "hw/3dfx contents:"
        ls -la hw/3dfx | head -10
    fi
    
    if [ -d "hw/mesa" ]; then
        log_info "hw/mesa contents:"
        ls -la hw/mesa | head -10
    fi
    
    # Apply GL_CONTEXTALPHA fix
    if [ -f "hw/mesa/mglcntx_linux.c" ]; then
        log_info "Applying GL_CONTEXTALPHA fix..."
        sed -i.bak 's/GL_CONTEXTALPHA/GLX_ALPHA_SIZE/g' hw/mesa/mglcntx_linux.c
        log_success "GL_CONTEXTALPHA fix applied"
    else
        log_info "hw/mesa/mglcntx_linux.c not found - fix not needed"
    fi
    
    # Sign commit (embed commit identity in source code)
    if [ -f "${SCRIPT_DIR}/scripts/sign_commit" ]; then
        log_info "Found sign_commit script"
        log_info "Would run sign_commit..."
        # bash "${SCRIPT_DIR}/scripts/sign_commit"
    else
        log_warning "sign_commit script not found"
    fi
    
    log_success "Patches test completed"
}

# Run the test
apply_patches
