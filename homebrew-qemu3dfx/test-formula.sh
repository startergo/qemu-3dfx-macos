#!/bin/bash

# Test script for QEMU 3dfx Homebrew formula
# This script builds the formula from source and runs debugging tests

set -e  # Exit on any error

echo "=== QEMU 3dfx Formula Test and Debug Script ==="
echo "Starting at: $(date)"
echo

# Set up environment
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Get the formula directory
FORMULA_DIR="/Users/macbookpro/qemu-3dfx-1/homebrew-qemu3dfx"
FORMULA_FILE="$FORMULA_DIR/Formula/qemu-3dfx.rb"

echo "Formula directory: $FORMULA_DIR"
echo "Formula file: $FORMULA_FILE"
echo

# Check if formula file exists
if [ ! -f "$FORMULA_FILE" ]; then
    echo "ERROR: Formula file not found at $FORMULA_FILE"
    exit 1
fi

echo "=== Step 1: Validating Formula Syntax ==="
cd "$FORMULA_DIR"
brew audit --strict --online Formula/qemu-3dfx.rb || echo "Warning: Audit found issues (continuing anyway)"
echo

echo "=== Step 2: Installing Dependencies ==="
# Install build dependencies first
brew install cmake meson ninja pkg-config python@3.12

# Install runtime dependencies
brew install capstone glib gettext gnutls libepoxy libgcrypt libslirp libusb jpeg-turbo lz4 opus sdl2 zstd
brew install libffi pixman sdl2_image spice-protocol spice-server mt32emu sdl12-compat sdl2_net sdl2_sound

echo "Dependencies installed successfully"
echo

echo "=== Step 3: Building Formula (Verbose Mode) ==="
# Use verbose mode to see detailed output
cd "$FORMULA_DIR"
brew install --verbose --build-from-source Formula/qemu-3dfx.rb

echo
echo "=== Step 4: Running Formula Tests ==="
# Test the installed formula
brew test qemu-3dfx

echo
echo "=== Step 5: Manual Verification ==="
# Get the installation prefix
QEMU_PREFIX=$(brew --prefix qemu-3dfx)
echo "QEMU 3dfx installed at: $QEMU_PREFIX"

# Test version and 3dfx signature
echo "Testing version output:"
"$QEMU_PREFIX/bin/qemu-system-x86_64" --version

echo
echo "Checking for 3dfx signature:"
if "$QEMU_PREFIX/bin/qemu-system-x86_64" --version | grep -q "qemu-3dfx@"; then
    echo "✅ 3dfx signature found"
else
    echo "❌ 3dfx signature NOT found"
fi

echo
echo "Testing device enumeration:"
"$QEMU_PREFIX/bin/qemu-system-x86_64" -device help | grep -E "virtio-vga|virtio-gpu" || echo "No virtio VGA devices found"

echo
echo "Testing display support:"
"$QEMU_PREFIX/bin/qemu-system-x86_64" -display help

echo
echo "=== Step 6: Checking Installation Structure ==="
echo "Binary files:"
ls -la "$QEMU_PREFIX/bin/"

echo
echo "Library files:"
ls -la "$QEMU_PREFIX/lib/" | head -20

echo
echo "=== Build and Test Complete ==="
echo "Finished at: $(date)"
