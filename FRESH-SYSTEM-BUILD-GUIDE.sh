#!/bin/bash

# QEMU 3dfx Fresh System Build Guide
# This script sets up everything needed to build QEMU 3dfx on a fresh macOS system

set -e

echo "🚀 QEMU 3dfx Fresh System Setup Guide"
echo "===================================="
echo ""

# Check system requirements
echo "📋 Step 1: System Requirements Check"
echo "-----------------------------------"
echo "✅ macOS with Apple Silicon (ARM64) or Intel"
echo "✅ Xcode Command Line Tools"
echo "✅ Homebrew package manager"
echo "✅ XQuartz (X11 for macOS)"
echo ""

# Check if requirements are met
missing_requirements=()

if ! command -v xcode-select &> /dev/null || ! xcode-select -p &> /dev/null; then
    missing_requirements+=("Xcode Command Line Tools")
fi

if ! command -v brew &> /dev/null; then
    missing_requirements+=("Homebrew")
fi

if [ ! -d "/opt/X11" ]; then
    missing_requirements+=("XQuartz")
fi

if [ ${#missing_requirements[@]} -gt 0 ]; then
    echo "❌ Missing requirements:"
    printf '   %s\n' "${missing_requirements[@]}"
    echo ""
    echo "Please install the missing requirements:"
    echo ""
    echo "1. Xcode Command Line Tools:"
    echo "   xcode-select --install"
    echo ""
    echo "2. Homebrew:"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo ""
    echo "3. XQuartz:"
    echo "   brew install --cask xquartz"
    echo "   # Then log out and back in to activate XQuartz"
    echo ""
    exit 1
fi

echo "✅ All basic requirements met!"
echo ""

echo "🔧 Step 2: Required Setup Steps"
echo "------------------------------"
echo ""
echo "To reproduce the QEMU 3dfx build on a fresh system, you need:"
echo ""

echo "1️⃣  Clone the qemu-3dfx-macos repository:"
echo "   git clone https://github.com/startergo/qemu-3dfx-macos.git"
echo "   cd qemu-3dfx-macos"
echo ""

echo "2️⃣  Install build dependencies via Homebrew:"
echo "   # Build tools"
echo "   brew install cmake meson ninja pkg-config python@3.12"
echo ""
echo "   # Core QEMU dependencies"
echo "   brew install capstone glib gettext gnutls libepoxy libgcrypt"
echo "   brew install libslirp libusb jpeg-turbo lz4 opus sdl2 zstd"
echo "   brew install libffi ncurses pixman sdl2_image"
echo ""
echo "   # SPICE and audio support"
echo "   brew install spice-protocol spice-server mt32emu"
echo "   brew install sdl12-compat sdl2_net sdl2_sound"
echo ""

echo "3️⃣  **CRITICAL**: Run the XQuartz pkg-config redirection script:"
echo "   bash fix-pkgconfig-to-xquartz.sh"
echo ""
echo "   ⚠️  This step is ESSENTIAL - it redirects pixman and libpng from"
echo "       Homebrew to XQuartz to avoid graphics library conflicts."
echo ""

echo "4️⃣  Create and install the Homebrew formula:"
echo "   # Create local tap directory"
echo "   mkdir -p homebrew-qemu3dfx/Formula"
echo ""
echo "   # Copy the formula (assumed to be in the repo)"
echo "   cp Formula/qemu-3dfx.rb homebrew-qemu3dfx/Formula/"
echo ""
echo "   # Install via local formula"
echo "   brew install --build-from-source ./homebrew-qemu3dfx/Formula/qemu-3dfx.rb"
echo ""

echo "5️⃣  Post-installation setup (optional):"
echo "   # Run the library symlink setup script"
echo "   bash setup-complete-3dfx-libraries.sh"
echo ""

echo "🎯 Alternative: One-Command Build"
echo "--------------------------------"
echo ""
echo "If all files are properly structured in the repository, the build can be"
echo "reproduced with these commands on a fresh system:"
echo ""
echo "# Install system requirements"
echo "xcode-select --install"
echo "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
echo "brew install --cask xquartz"
echo "# Log out and back in for XQuartz"
echo ""
echo "# Clone and build"
echo "git clone https://github.com/startergo/qemu-3dfx-macos.git"
echo "cd qemu-3dfx-macos"
echo "bash fix-pkgconfig-to-xquartz.sh  # CRITICAL STEP"
echo "brew install --build-from-source ./homebrew-qemu3dfx/Formula/qemu-3dfx.rb"
echo ""

echo "📝 Key Success Factors"
echo "---------------------"
echo ""
echo "✅ XQuartz must be installed and active (requires reboot/re-login)"
echo "✅ The fix-pkgconfig-to-xquartz.sh script MUST be run before building"
echo "✅ All repository files (patches, source code) must be present"
echo "✅ The Homebrew formula must be properly structured"
echo ""

echo "🔍 Build Dependencies Summary"
echo "----------------------------"
echo ""
echo "The formula handles these automatically when run:"
echo "• Python 3.12 with PyYAML (for virglrenderer)"
echo "• Mesa GL context sources (qemu-0/, qemu-1/ directories)"
echo "• 3dfx patches (00-qemu92x-mesa-glide.patch)"
echo "• Virglrenderer 1.1.1 with macOS patches"
echo "• XQuartz graphics library redirection"
echo "• Code signing with git commit information"
echo ""

echo "🎉 The formula is designed to be self-contained and handle all the"
echo "   complex build steps automatically, provided the prerequisites"
echo "   (XQuartz, fix-pkgconfig script) are properly set up."
echo ""

echo "💡 TIP: The most common failure point is forgetting to run the"
echo "         fix-pkgconfig-to-xquartz.sh script before building!"
