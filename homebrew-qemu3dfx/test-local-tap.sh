#!/bin/bash

# Test script for local homebrew tap
set -e

echo "🧪 Testing QEMU 3dfx Homebrew Tap Locally"
echo "========================================"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test 1: Check formula syntax
log_info "Testing formula syntax..."
if brew style Formula/qemu-3dfx.rb; then
    log_success "Formula syntax is valid"
else
    log_error "Formula syntax has issues"
    exit 1
fi

# Test 2: Check formula info and basic validation
log_info "Getting formula information..."
if brew info Formula/qemu-3dfx.rb > /dev/null 2>&1; then
    log_success "Formula info command works"
    brew info Formula/qemu-3dfx.rb
else
    log_error "Formula info failed"
    exit 1
fi

# Test 3: Check if dependencies exist
log_info "Checking dependencies..."
missing_deps=()

# Check build dependencies
for dep in cmake meson ninja pkg-config python@3.12; do
    if ! brew list "$dep" &>/dev/null; then
        missing_deps+=("$dep")
    fi
done

# Check runtime dependencies  
for dep in glib libepoxy pixman sdl2; do
    if ! brew list "$dep" &>/dev/null; then
        missing_deps+=("$dep")
    fi
done

if [ ${#missing_deps[@]} -eq 0 ]; then
    log_success "All dependencies are available"
else
    log_error "Missing dependencies: ${missing_deps[*]}"
    log_info "Installing missing dependencies..."
    brew install "${missing_deps[@]}"
fi

# Test 4: Check formula can be parsed
log_info "Testing formula can be parsed..."
if brew info Formula/qemu-3dfx.rb | grep -q "qemu-3dfx"; then
    log_success "Formula parsing works correctly"
else
    log_error "Formula parsing failed"
    exit 1
fi

echo
log_success "Local tap testing completed!"
echo "Ready to install with: brew install --build-from-source ./Formula/qemu-3dfx.rb"
