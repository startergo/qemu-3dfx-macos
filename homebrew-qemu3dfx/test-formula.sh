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

echo "=== Step 2: Installing Dependencies (Replicating Workflow) ==="

# Install Xcode command line tools dependencies
echo "Installing Xcode command line tools..."
xcode-select --install 2>/dev/null || true

# Install XQuartz (REQUIRED by KJ for Mesa GL context support)
echo "Installing XQuartz..."
brew install --cask xquartz

# XQuartz needs to be properly initialized - create the expected directory structure
echo "Setting up XQuartz directory structure..."
sudo mkdir -p /opt/X11/lib /opt/X11/include

# Link XQuartz libraries to expected location if they're not there yet
if [ ! -d "/opt/X11/lib" ] || [ -z "$(ls -A /opt/X11/lib 2>/dev/null)" ]; then
  echo "Setting up XQuartz library symlinks..."
  # XQuartz installs to /usr/X11/lib on some systems, check multiple locations
  for xquartz_lib in "/usr/X11/lib" "/System/Library/Frameworks/OpenGL.framework/Libraries" "/opt/homebrew/lib"; do
    if [ -d "$xquartz_lib" ]; then
      sudo ln -sf "$xquartz_lib"/*X11* /opt/X11/lib/ 2>/dev/null || true
      sudo ln -sf "$xquartz_lib"/*GL* /opt/X11/lib/ 2>/dev/null || true
    fi
  done
  
  # If still empty, create minimal structure using Homebrew X11 libraries
  if [ -z "$(ls -A /opt/X11/lib 2>/dev/null)" ]; then
    echo "Creating X11 library structure using Homebrew libraries..."
    sudo ln -sf /opt/homebrew/lib/libX11* /opt/X11/lib/
    sudo ln -sf /opt/homebrew/lib/libXext* /opt/X11/lib/
    sudo ln -sf /opt/homebrew/lib/libGL* /opt/X11/lib/ 2>/dev/null || true
  fi
fi

# Install KJ's specified core prerequisites
echo "Installing KJ's core prerequisites..."
brew install capstone glib gettext gnutls libepoxy libgcrypt libslirp libusb jpeg-turbo lz4 opus sdl2 zstd

# Install KJ's gaming essentials (for DOSBox SVN Games)
echo "Installing gaming essentials..."
brew install sdl12-compat sdl2_net sdl2_sound mt32emu

# Additional build tools needed for compilation
echo "Installing build tools..."
brew install git wget cmake ninja meson pkg-config pixman libffi python@3.12

# Install additional dependencies that might be missing
echo "Installing additional dependencies..."
brew install sdl2_image spice-protocol spice-server

# Install Python modules required for virglrenderer build
echo "Installing Python modules..."
python3 -m pip install --break-system-packages PyYAML || true
/opt/homebrew/bin/python3.12 -m pip install --break-system-packages PyYAML || true

# Verify PyYAML is available for the Python version meson will use
echo "Checking PyYAML availability:"
python3 -c "import yaml; print('PyYAML available for system python3')" || echo "PyYAML not found for system python3"
/opt/homebrew/bin/python3.12 -c "import yaml; print('PyYAML available for Homebrew python3.12')" || echo "PyYAML not found for Homebrew python3.12"

# X11 development headers (required for Mesa GL compilation, separate from XQuartz runtime)
echo "Installing X11 development headers..."
brew install libx11 libxext libxfixes libxrandr libxinerama libxi libxcursor
brew install xorgproto libxxf86vm  # X11 extension headers including xf86vmode.h

echo "Dependencies installed successfully"
echo

echo "=== Step 2.5: Setup Build Environment (Replicating GitHub Actions) ==="

# Set PKG_CONFIG_PATH to match what the formula expects
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig"

# Add libepoxy path specifically (essential for OpenGL, matching formula)
EPOXY_PATH=$(find /opt/homebrew/Cellar/libepoxy -name "pkgconfig" -type d 2>/dev/null | head -1)
if [ -n "$EPOXY_PATH" ]; then
  export PKG_CONFIG_PATH="$EPOXY_PATH:$PKG_CONFIG_PATH"
  echo "Added libepoxy pkg-config path: $EPOXY_PATH"
fi

# The formula creates its own local header structure, so we don't need to manually copy to /usr/local
# However, we need to ensure all dependencies are properly installed and available via pkg-config

echo "Current PKG_CONFIG_PATH: $PKG_CONFIG_PATH"

# Verify pixman is available via pkg-config (this is what matters for the build)
echo "Checking pixman via pkg-config:"
pkg-config --exists pixman-1 && echo "✅ pixman-1 pkg-config found" || echo "❌ pixman-1 pkg-config missing"
pkg-config --cflags pixman-1 2>/dev/null || echo "Could not get pixman-1 cflags"
pkg-config --libs pixman-1 2>/dev/null || echo "Could not get pixman-1 libs"

# Verify pixman headers are available where Homebrew installed them
echo "Checking Homebrew pixman installation:"
ls -la /opt/homebrew/include/pixman-1/ 2>/dev/null || echo "Homebrew pixman headers not found"
test -f /opt/homebrew/include/pixman-1/pixman.h && echo "✅ pixman.h found in Homebrew" || echo "❌ pixman.h missing in Homebrew"

# Check other critical dependencies that the formula expects
echo "Verifying critical build dependencies:"
for dep in glib-2.0 libepoxy sdl2 zlib; do
  if pkg-config --exists $dep; then
    echo "✅ $dep available"
  else
    echo "❌ $dep missing"
  fi
done

echo "Build environment setup complete"
echo

echo "=== Step 3: Building Formula (Verbose Mode) ==="

# Set up the same environment that GitHub Actions would have
echo "🔧 Setting up build environment to match GitHub Actions..."

# Ensure we're in the right directory
cd "$FORMULA_DIR"

# Set environment variables that GitHub Actions sets automatically
export CI=false  # Don't limit build parallelism 
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ANALYTICS=1

# Set paths that match the formula expectations
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig"

# Add libepoxy path (critical for OpenGL, matching what formula does)
EPOXY_PATH=$(find /opt/homebrew/Cellar/libepoxy -name "pkgconfig" -type d 2>/dev/null | head -1)
if [ -n "$EPOXY_PATH" ]; then
  export PKG_CONFIG_PATH="$EPOXY_PATH:$PKG_CONFIG_PATH"
fi

echo "Environment configured:"
echo "  PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
echo "  HOMEBREW_PREFIX: $(brew --prefix)"

# Replicate workflow's experimental patches setup
echo "🧪 Setting up experimental patches flag (replicating workflow behavior)..."

# Create flag file for Homebrew formula to read (matching workflow)
echo "true" > /tmp/apply_experimental_patches
echo "📝 Created flag file: /tmp/apply_experimental_patches with value 'true'"

# Check SPICE dependencies before building (matching workflow)
echo "=== Checking SPICE dependencies ==="
brew list spice-protocol || echo "⚠️ spice-protocol not installed"
brew list spice-server || echo "⚠️ spice-server not installed"

# Show pkg-config availability for SPICE
pkg-config --exists spice-protocol && echo "✅ spice-protocol pkg-config found" || echo "⚠️ spice-protocol pkg-config missing"
pkg-config --exists spice-server && echo "✅ spice-server pkg-config found" || echo "⚠️ spice-server pkg-config missing"

# Use verbose mode to see detailed output and force clean build
echo "Running brew install with experimental patches enabled..."
echo "📝 Using --force to ensure clean build..."

# IMPORTANT: Reset Homebrew completely to avoid any cached state issues
echo "🧹 Resetting Homebrew to ensure clean environment..."
echo "Clearing all Homebrew caches..."
brew cleanup --prune=all
rm -rf "$(brew --cache)"
echo "Clearing formula-specific build cache..."
rm -rf "$(brew --cache)/downloads/qemu*"
rm -rf "$(brew --cache)/Formula/qemu*"

# First, try to uninstall any existing installation to ensure clean state
brew uninstall qemu-3dfx 2>/dev/null || echo "No existing installation to remove"

# Clear any cached builds
brew cleanup qemu-3dfx 2>/dev/null || true

# Force Homebrew to re-evaluate all dependencies
echo "🔄 Forcing Homebrew to re-evaluate dependencies..."
brew deps --tree Formula/qemu-3dfx.rb

# Fix pixman linking issues if they exist (common cache problem)
echo "🔧 Resolving potential pixman linking conflicts..."
if [ -f "/opt/homebrew/include/pixman-1/pixman.h" ] && ! brew list pixman &>/dev/null; then
    echo "Found orphaned pixman headers, removing them..."
    rm -rf /opt/homebrew/include/pixman-1/ 2>/dev/null || true
fi

# Force proper pixman linking if it's installed but not linked
if brew list pixman &>/dev/null; then
    echo "Ensuring pixman is properly linked..."
    brew unlink pixman 2>/dev/null || true
    brew link --overwrite pixman || echo "Could not link pixman (continuing anyway)"
fi

# Verify critical headers are available before starting build
echo "🔍 Final verification of build environment:"
echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
pkg-config --exists pixman-1 && echo "✅ pixman-1 available" || echo "❌ pixman-1 missing"
test -f /opt/homebrew/include/pixman-1/pixman.h && echo "✅ pixman.h header found" || echo "❌ pixman.h header missing"

# Install with verbose output and force clean build from source
# Note: We use --build-from-source (not --force-bottle) since we need to apply patches
brew install --verbose --build-from-source --force Formula/qemu-3dfx.rb

echo
echo "=== Step 4: Running Formula Tests ==="
# Test the installed formula
brew test qemu-3dfx

echo
echo "=== Step 5: Manual Verification ==="
# Get the installation prefix
QEMU_PREFIX=$(brew --prefix qemu-3dfx)
echo "QEMU 3dfx installed at: $QEMU_PREFIX"

# Detect host architecture
HOST_ARCH=$(uname -m)
echo "Host architecture: $HOST_ARCH"

# Choose appropriate QEMU binary for testing
if [ "$HOST_ARCH" = "arm64" ] || [ "$HOST_ARCH" = "aarch64" ]; then
    echo "🍎 Apple Silicon detected - testing both x86_64 (emulation) and aarch64 (native)"
    QEMU_TEST_BIN="$QEMU_PREFIX/bin/qemu-system-x86_64"
    QEMU_NATIVE_BIN="$QEMU_PREFIX/bin/qemu-system-aarch64"
else
    echo "🖥️ Intel Mac detected - testing x86_64 (native)"
    QEMU_TEST_BIN="$QEMU_PREFIX/bin/qemu-system-x86_64"
    QEMU_NATIVE_BIN="$QEMU_PREFIX/bin/qemu-system-x86_64"
fi

# Test version and 3dfx signature
echo "Testing x86_64 version output:"
"$QEMU_TEST_BIN" --version

if [ "$HOST_ARCH" = "arm64" ] || [ "$HOST_ARCH" = "aarch64" ]; then
    echo
    echo "Testing aarch64 version output (native on Apple Silicon):"
    "$QEMU_NATIVE_BIN" --version
fi

echo
echo "Checking for 3dfx signature:"
if "$QEMU_TEST_BIN" --version | grep -q "qemu-3dfx@"; then
    echo "✅ 3dfx signature found in x86_64 binary"
else
    echo "❌ 3dfx signature NOT found in x86_64 binary"
fi

if [ "$HOST_ARCH" = "arm64" ] || [ "$HOST_ARCH" = "aarch64" ]; then
    if "$QEMU_NATIVE_BIN" --version | grep -q "qemu-3dfx@"; then
        echo "✅ 3dfx signature found in aarch64 binary"
    else
        echo "❌ 3dfx signature NOT found in aarch64 binary"
    fi
fi

echo
echo "Checking for SDL clipboard support (experimental patch):"
if strings "$QEMU_TEST_BIN" | grep -q "sdl2-clipboard"; then
    echo "✅ SDL clipboard support found in x86_64 binary (experimental patch applied)"
else
    echo "❌ SDL clipboard support NOT found in x86_64 binary"
fi

if [ "$HOST_ARCH" = "arm64" ] || [ "$HOST_ARCH" = "aarch64" ]; then
    if strings "$QEMU_NATIVE_BIN" | grep -q "sdl2-clipboard"; then
        echo "✅ SDL clipboard support found in aarch64 binary (experimental patch applied)"
    else
        echo "❌ SDL clipboard support NOT found in aarch64 binary"
    fi
fi

echo
echo "Checking SDL clipboard strings in x86_64 binary:"
strings "$QEMU_TEST_BIN" | grep -i "clipboard" | head -5 || echo "No clipboard strings found"

if [ "$HOST_ARCH" = "arm64" ] || [ "$HOST_ARCH" = "aarch64" ]; then
    echo
    echo "Checking SDL clipboard strings in aarch64 binary:"
    strings "$QEMU_NATIVE_BIN" | grep -i "clipboard" | head -5 || echo "No clipboard strings found"
fi

echo
echo "Testing device enumeration:"
echo "x86_64 binary devices:"
"$QEMU_TEST_BIN" -device help | grep -E "virtio-vga|virtio-gpu|3dfx" || echo "No specialized devices found"

if [ "$HOST_ARCH" = "arm64" ] || [ "$HOST_ARCH" = "aarch64" ]; then
    echo "aarch64 binary devices:"
    "$QEMU_NATIVE_BIN" -device help | grep -E "virtio-vga|virtio-gpu" || echo "No VirtIO devices found"
fi

echo
echo "Testing display support:"
echo "x86_64 display options:"
"$QEMU_TEST_BIN" -display help

if [ "$HOST_ARCH" = "arm64" ] || [ "$HOST_ARCH" = "aarch64" ]; then
    echo "aarch64 display options:"
    "$QEMU_NATIVE_BIN" -display help
fi

echo
echo "=== Performance Recommendations ==="
if [ "$HOST_ARCH" = "arm64" ] || [ "$HOST_ARCH" = "aarch64" ]; then
    echo "🍎 Apple Silicon Performance Tips:"
    echo "  For BEST performance: Use aarch64 guests (Linux ARM64, Windows ARM64)"
    echo "  For x86_64 guests: Use hvf acceleration (-accel hvf)"
    echo "  For retro gaming: x86_64 with 3dfx support works but is slower (emulation)"
    echo "  
    echo "  Example commands:"
    echo "  # Native ARM64 Linux (fastest):"
    echo "  $QEMU_NATIVE_BIN -accel hvf -M virt -cpu cortex-a72 -m 4G -device virtio-vga-gl -display sdl,gl=on"
    echo "  
    echo "  # x86_64 retro gaming (slower but supports 3dfx):"
    echo "  $QEMU_TEST_BIN -accel hvf -M pc -cpu pentium3 -m 512M -device 3dfx,voodoo=voodoo2 -display sdl"
else
    echo "🖥️ Intel Mac Performance Tips:"
    echo "  Use KVM acceleration when available (-enable-kvm)"
    echo "  x86_64 guests run natively (no emulation overhead)"
fi

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

# Cleanup
echo
echo "=== Cleanup ==="
rm -f /tmp/apply_experimental_patches
echo "Removed experimental patches flag file"
