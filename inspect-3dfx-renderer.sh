#!/bin/bash

# QEMU 3dfx Renderer Inspection Script
# This script helps inspect 3dfx rendering from the host system

set -e

echo "🔍 QEMU 3dfx Renderer Inspection Tools"
echo "====================================="

QEMU_BIN="/opt/homebrew/Cellar/qemu-3dfx/9.2.2-3dfx_26/bin/qemu-system-x86_64"

if [ ! -f "$QEMU_BIN" ]; then
    echo "❌ QEMU 3dfx binary not found. Please build it first."
    exit 1
fi

echo ""
echo "🔧 1. QEMU 3dfx Device Support:"
echo "=============================="
echo "Available VGA devices with 3dfx support:"
"$QEMU_BIN" -device help | grep -E "(vga|display|virtio)" | head -10

echo ""
echo "🖥️  2. Display Backend Support:"
echo "==============================="
echo "Available display backends:"
"$QEMU_BIN" -display help

echo ""
echo "🎮 3. 3dfx-Specific Device Options:"
echo "=================================="
echo "Checking for 3dfx device parameters..."
"$QEMU_BIN" -device VGA,help 2>/dev/null || echo "Standard VGA options"

echo ""
echo "📊 4. Host System 3dfx Libraries:"
echo "================================="
echo "3dfx libraries in system:"
find /opt/homebrew /usr/local/lib -name "*glide*" -o -name "*3dfx*" 2>/dev/null | head -10

echo ""
echo "🔍 5. Runtime Inspection Commands:"
echo "=================================="
echo ""
echo "To monitor QEMU 3dfx rendering while running:"
echo ""
echo "A) Monitor QEMU process and libraries:"
echo "   lsof -p \$(pgrep qemu-system) | grep -E '(glide|mesa|virgl|SDL)'"
echo ""
echo "B) Check OpenGL context creation:"
echo "   Console.app -> search for 'qemu' or 'OpenGL'"
echo ""
echo "C) Monitor graphics API calls (if available):"
echo "   sudo dtruss -f -p \$(pgrep qemu-system) 2>&1 | grep -E '(opengl|glide|mesa)'"
echo ""
echo "D) Check QEMU monitor for 3dfx status:"
echo "   In QEMU monitor: 'info qtree' or 'info pci'"
echo ""
echo "E) Memory mapping inspection:"
echo "   vmmap \$(pgrep qemu-system) | grep -E '(glide|mesa|SDL|OpenGL)'"

echo ""
echo "🚀 6. Example QEMU 3dfx Launch Commands (macOS):"
echo "================================================"
echo ""
echo "Note: On macOS, use HVF (Hypervisor Framework) instead of KVM"
echo ""
cat << 'EOF'

# Basic 3dfx test with Windows 98:
qemu-system-x86_64 \
  -M pc \
  -cpu pentium3 \
  -m 512 \
  -vga std \
  -device glide,model=voodoo1 \
  -display sdl,gl=on \
  -hda win98.img

# Advanced 3dfx with Voodoo2:
qemu-system-x86_64 \
  -M pc \
  -cpu pentium3 \
  -m 512 \
  -vga cirrus \
  -device glide,model=voodoo2 \
  -device glide,model=voodoo2 \
  -display sdl,gl=on \
  -netdev user,id=net0 \
  -device rtl8139,netdev=net0 \
  -hda dos_games.img

# 3dfx with VirtIO-GL acceleration (macOS with HVF):
qemu-system-x86_64 \
  -M pc \
  -cpu host \
  -accel hvf \
  -m 1G \
  -device virtio-vga-gl \
  -display sdl,gl=on \
  -device glide,model=voodoo2 \
  -hda modern_guest.img

# 3dfx with Apple Silicon optimization:
qemu-system-x86_64 \
  -M pc \
  -cpu max \
  -accel hvf \
  -m 2G \
  -device virtio-vga-gl \
  -display sdl,gl=on \
  -device glide,model=voodoo2 \
  -hda retro_games.img

EOF

echo ""
echo "🍎 macOS-Specific Acceleration:"
echo "==============================="
cat << 'EOF'

# Check available accelerators on macOS:
qemu-system-x86_64 -accel help

# Available on macOS:
# - hvf    (Hypervisor Framework - recommended)
# - tcg    (Software emulation - slower but compatible)

# For Apple Silicon Macs:
# - Use -cpu max for best compatibility
# - Use -accel hvf for hardware acceleration
# - Avoid -enable-kvm (Linux/Windows only)

# Performance tip for Apple Silicon:
# Add these for better performance:
#   -smp 4                    # Use multiple cores
#   -machine usb=off          # Disable USB for older guests
#   -rtc base=localtime       # Better time sync

EOF

echo ""
echo "📝 7. Logging and Debug Options:"
echo "==============================="
cat << 'EOF'

# Enable 3dfx debug logging:
export QEMU_3DFX_DEBUG=1
export MESA_DEBUG=1
export LIBGL_DEBUG=verbose

# Run with detailed logging:
qemu-system-x86_64 -d guest_errors,unimp,trace:glide* [other options]

# Log to file:
qemu-system-x86_64 -D qemu-3dfx.log -d guest_errors,unimp [other options]

EOF

echo "✅ Inspection tools ready!"
echo "   Run this script anytime to get inspection commands."
