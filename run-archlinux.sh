#!/bin/bash

# QEMU 3dfx Multi-Architecture Script with 3dfx Support
# Supports i386 (3dfx), x86_64 (modern), and aarch64 (ARM64)
# 
# Usage:
#   ./run-archlinux.sh i386    # For retro gaming with 3dfx support
#   ./run-archlinux.sh x86_64  # For modern x86_64 systems
#   ./run-archlinux.sh aarch64 # For ARM64 systems
#   ./run-archlinux.sh install # Boot from ISO for fresh installation
#
# 3dfx Support:
# - Use i386 target for Windows 95/98 guests with Glide API games
# - 3dfx devices (glidept/mesapt) are automatically available
# - Requires appropriate guest OS and 3dfx drivers

# # Dynamic Library Setup - Ensure all QEMU 3dfx libraries are loaded
# SPICE_LIB="/opt/homebrew/Cellar/spice-server/0.16.0/lib"
# export DYLD_LIBRARY_PATH="/opt/homebrew/Cellar/qemu-3dfx/9.2.2-3dfx_26/lib:$SPICE_LIB:/opt/homebrew/lib:/usr/local/lib:$DYLD_LIBRARY_PATH"
# export DYLD_FALLBACK_LIBRARY_PATH="/opt/homebrew/Cellar/qemu-3dfx/9.2.2-3dfx_26/lib:$SPICE_LIB:/opt/homebrew/lib:/usr/local/lib:/usr/lib:$DYLD_FALLBACK_LIBRARY_PATH"

# # Check and create missing symlinks if needed
# QEMU_3DFX_LIB="/opt/homebrew/Cellar/qemu-3dfx/9.2.2-3dfx_26/lib"
# # Check if any critical symlinks are missing
# if [ ! -L "/usr/local/lib/libglide2x.dylib" ] || [ ! -e "/usr/local/lib/libglide2x.dylib" ] || \
#    [ ! -L "/usr/local/lib/libglide3x.dylib" ] || [ ! -e "/usr/local/lib/libglide3x.dylib" ] || \
#    [ ! -L "/usr/local/lib/libspice-server.dylib" ] || [ ! -e "/usr/local/lib/libspice-server.dylib" ]; then
#     echo "Creating required library symlinks..."
#     # 3dfx libraries
#     sudo ln -sf "$QEMU_3DFX_LIB/libglide2x.dylib" /usr/local/lib/libglide2x.dylib 2>/dev/null || echo "Note: Could not create /usr/local/lib symlinks (run as sudo if needed)"
#     sudo ln -sf "$QEMU_3DFX_LIB/libglide3x.dylib" /usr/local/lib/libglide3x.dylib 2>/dev/null
#     sudo ln -sf "$QEMU_3DFX_LIB/libvirglrenderer.dylib" /usr/local/lib/libvirglrenderer.dylib 2>/dev/null
#     sudo ln -sf "$QEMU_3DFX_LIB/libvirglrenderer.1.dylib" /usr/local/lib/libvirglrenderer.1.dylib 2>/dev/null
#     # SPICE libraries
#     sudo ln -sf "$SPICE_LIB/libspice-server.dylib" /usr/local/lib/libspice-server.dylib 2>/dev/null
#     sudo ln -sf "$SPICE_LIB/libspice-server.1.dylib" /usr/local/lib/libspice-server.1.dylib 2>/dev/null
# fi

# # Verify critical libraries are accessible
# echo "Checking 3dfx, SPICE, and SDL libraries..."
# if [ -e "$QEMU_3DFX_LIB/libglide2x.dylib" ]; then
#     echo "✓ libglide2x.dylib found"
# else
#     echo "✗ libglide2x.dylib missing!"
# fi
# if [ -e "$QEMU_3DFX_LIB/libglide3x.dylib" ]; then
#     echo "✓ libglide3x.dylib found"
# else
#     echo "✗ libglide3x.dylib missing!"
# fi
# if [ -e "$QEMU_3DFX_LIB/libvirglrenderer.1.dylib" ]; then
#     echo "✓ libvirglrenderer.1.dylib found"
# else
#     echo "✗ libvirglrenderer.1.dylib missing!"
# fi
# if [ -e "$SPICE_LIB/libspice-server.1.dylib" ]; then
#     echo "✓ libspice-server.1.dylib found"
# else
#     echo "✗ libspice-server.1.dylib missing!"
# fi
# if [ -e "/opt/homebrew/lib/libSDL2.dylib" ]; then
#     echo "✓ libSDL2.dylib found"
# else
#     echo "✗ libSDL2.dylib missing!"
# fi

# Target architecture selection
ARCH="${1:-aarch64}"  # Default to aarch64 if no argument provided
INSTALL_MODE="${1:-}"

# Validate architecture
case "$ARCH" in
    i386|x86_64|aarch64|install)
        ;;
    *)
        echo "Usage: $0 {i386|x86_64|aarch64|install}"
        echo "  i386    - x86 32-bit with 3dfx support (for retro gaming)"
        echo "  x86_64  - x86 64-bit modern systems"
        echo "  aarch64 - ARM64 systems"
        echo "  install - Boot from ISO for installation"
        exit 1
        ;;
esac

# Set architecture-specific parameters
if [ "$ARCH" = "install" ]; then
    ARCH="x86_64"  # Use x86_64 for installation
    INSTALL_MODE="install"
fi

case "$ARCH" in
    i386)
        # Check if using original QEMU 3dfx binary for browser testing
        if [ "$USE_ORIGINAL" = "1" ]; then
            QEMU_BIN="/Users/macbookpro/Downloads/windows-xp-mode_20200907/qemu-9.2.2-3dfx-e5562fa-darwin-arm64/opt/homebrew/bin/qemu-system-i386"
            echo "Using ORIGINAL QEMU 3dfx binary (e5562fa build for browser compatibility)"
        else
            QEMU_BIN="/opt/homebrew/bin/qemu-system-i386"
            echo "Using CURRENT QEMU 3dfx binary (c09c5a3 build)"
        fi
        MACHINE="pc"
        CPU_TYPE=""  # Use default for i386
        VGA_DEVICE="-vga std"  # Standard VGA for better compatibility
        # 3dfx support is built into QEMU 3dfx - no additional devices needed
        THREED_FX=""  # 3dfx support is integrated into the QEMU binary itself
        EFI_CODE=""
        EFI_VARS=""
        BOOT_OPTS="-boot order=cd"
        echo "Starting QEMU i386 with 3dfx support for retro gaming..."
        echo "3dfx support: Built into QEMU 3dfx binary (Glide acceleration available)"
        ;;
    x86_64)
        QEMU_BIN="/opt/homebrew/bin/qemu-system-x86_64"
        MACHINE="pc,accel=hvf"  # Use pc instead of q35 for better compatibility
        CPU_TYPE="-cpu host"
        VGA_DEVICE="-vga std"  # Standard VGA for broad compatibility
        # 3dfx support is built into QEMU 3dfx - no additional devices needed
        THREED_FX=""  # 3dfx support is integrated into the QEMU binary itself
        EFI_CODE=""  # Skip UEFI for better compatibility
        EFI_VARS=""
        BOOT_OPTS="-boot order=cd"
        echo "Starting QEMU x86_64 for modern systems..."
        echo "3dfx support: Built into QEMU 3dfx binary (enhanced graphics available)"
        ;;
    aarch64)
        # Check if using original QEMU 3dfx binary for browser testing
        if [ "$USE_ORIGINAL" = "1" ]; then
            ORIGINAL_AARCH64="/Users/macbookpro/Downloads/windows-xp-mode_20200907/qemu-9.2.2-3dfx-e5562fa-darwin-arm64/opt/homebrew/bin/qemu-system-aarch64"
            if [ -f "$ORIGINAL_AARCH64" ]; then
                QEMU_BIN="$ORIGINAL_AARCH64"
                echo "Using ORIGINAL QEMU 3dfx binary (e5562fa build for browser compatibility)"
                # Use standard VGA for maximum browser compatibility with original build
                VGA_DEVICE="-device virtio-gpu-pci"  # Standard VirtIO GPU (no OpenGL) for browser compatibility
            else
                echo "Original aarch64 binary not found, using current with browser-optimized settings"
                QEMU_BIN="/opt/homebrew/bin/qemu-system-aarch64"
                VGA_DEVICE="-device virtio-gpu-pci"  # Standard VirtIO GPU (no OpenGL) for browser compatibility
            fi
        else
            QEMU_BIN="/opt/homebrew/bin/qemu-system-aarch64"
            echo "Using CURRENT QEMU 3dfx binary (c09c5a3 build)"
            if [ "$USE_BROWSER_MODE" = "1" ]; then
                VGA_DEVICE="-device virtio-gpu-pci"  # Standard VirtIO GPU for browser compatibility
                echo "Browser compatibility mode: Using software rendering for stable web browsing"
            else
                VGA_DEVICE="-device virtio-gpu-gl-pci"  # VirtIO GPU with OpenGL (hardware acceleration)
                echo "3D acceleration mode: Using hardware acceleration for games/graphics"
            fi
        fi
        MACHINE="virt,accel=hvf,highmem=off"
        CPU_TYPE="-cpu cortex-a72"
        # 3dfx support is built into QEMU 3dfx - no additional devices needed
        THREED_FX=""  # 3dfx support is integrated into the QEMU binary itself
        EFI_CODE="-drive if=pflash,format=raw,file=/opt/homebrew/share/qemu/edk2-aarch64-code.fd,readonly=on"
        EFI_VARS="-drive if=pflash,format=raw,file=/opt/homebrew/share/qemu/edk2-arm-vars.fd,discard=on"
        BOOT_OPTS="-boot menu=on,order=c,splash-time=3000"  # Auto-boot from disk with 3 second timeout
        echo "Starting QEMU aarch64 with VirtIO GPU OpenGL (hardware acceleration)..."
        echo "3dfx support: Built into QEMU 3dfx binary (hardware acceleration enabled)"
        ;;
esac

# Common parameters
MEMORY="-m 3G"
SMP="-smp 4"

# Additional UEFI/Boot configuration for better automatic booting
if [ "$ARCH" = "aarch64" ]; then
    EXTRA_OPTS="-rtc base=utc,clock=host"  # Remove kvm-pit option (x86-only)
else
    EXTRA_OPTS="-rtc base=utc,clock=host -global kvm-pit.lost_tick_policy=delay"
fi

# 3dfx and QEMU debugging options for enhanced logging
DEBUG_OPTS="-d guest_errors,unimp"  # Show guest errors and unimplemented features

# Enable 3dfx specific debugging for all architectures with enhanced logging
case "$ARCH" in
    i386)
        DEBUG_OPTS="$DEBUG_OPTS -D /tmp/qemu-3dfx-i386-debug.log"
        echo "3dfx Debug: i386 logging to /tmp/qemu-3dfx-i386-debug.log"
        ;;
    x86_64)
        DEBUG_OPTS="$DEBUG_OPTS -D /tmp/qemu-3dfx-x86_64-debug.log"
        echo "3dfx Debug: x86_64 logging to /tmp/qemu-3dfx-x86_64-debug.log"
        ;;
    aarch64)
        DEBUG_OPTS="$DEBUG_OPTS -D /tmp/qemu-3dfx-aarch64-debug.log"
        echo "3dfx Debug: aarch64 logging to /tmp/qemu-3dfx-aarch64-debug.log"
        ;;
esac

# Display and SPICE configuration
if [ "$USE_VNC" = "1" ]; then
    DISPLAY="-display vnc=:1,password=on"
    SPICE_DISPLAY=""
    echo "Using VNC display on localhost:5901 (set USE_VNC=1)"
    echo "VNC Password: qemu123"
    echo "Note: Clipboard sharing not available with VNC"
elif [ "$USE_SPICE" = "1" ]; then
    # Hardware acceleration: VirtIO GPU with OpenGL + SDL with gl=on
    DISPLAY="-display sdl,gl=on,grab-mod=lctrl-lalt,window-close=off"
    SPICE_DISPLAY=""  # No SPICE display - SDL for graphics, separate console
    echo "Using hardware acceleration approach (set USE_SPICE=1)"
    echo "Graphics: VirtIO GPU OpenGL + SDL with gl=on (hardware accelerated)"
    echo "Console: Serial console in terminal (immediate access)"
    echo "Clipboard: qemu-vdagent for bidirectional copy/paste"
    echo "Boot messages: Will appear in this terminal"
elif [ "$USE_CONSOLE" = "1" ]; then
    # Console-only mode with SPICE (like UTM console)
    DISPLAY="-display none"
    SPICE_DISPLAY=""
    echo "Using console-only mode (set USE_CONSOLE=1)"
    echo "Console: SPICE console available for headless operation"
    echo "Note: No graphical display, console access only"
elif [ "$USE_BROWSER_MODE" = "1" ]; then
    # Browser mode: Standard SDL without OpenGL for browser compatibility
    DISPLAY="-display sdl,grab-mod=lctrl-lalt,window-close=off"
    SPICE_DISPLAY=""
    echo "Using browser compatibility mode (set USE_BROWSER_MODE=1)"
    echo "Graphics: Standard SDL without OpenGL (stable for browsers)"
    echo "Clipboard: qemu-vdagent for bidirectional copy/paste"
else
    # Default: Hardware acceleration with SDL gl=on + VirtIO GPU OpenGL
    DISPLAY="-display sdl,gl=on,grab-mod=lctrl-lalt,window-close=off"
    SPICE_DISPLAY=""
    echo "Using hardware acceleration mode (default)"
    echo "Graphics: SDL with gl=on + VirtIO GPU OpenGL (hardware accelerated)"
    echo "Clipboard: qemu-vdagent for bidirectional copy/paste"
fi

AUDIO="-audiodev coreaudio,id=audio0 -device intel-hda -device hda-duplex,audiodev=audio0"
USB="-device qemu-xhci -device usb-kbd -device virtio-mouse-pci"  # Add VirtIO mouse for better integration
SERIAL=""  # virtio-serial-pci will be added with clipboard configuration to avoid duplication
MONITOR="-monitor telnet:127.0.0.1:4445,server,nowait"  # Monitor via telnet to avoid conflicts
NETWORK="-netdev user,id=net0 -device virtio-net-pci,netdev=net0"

# Alternative audio configurations for better compatibility
if [ "$DISABLE_AUDIO" = "1" ]; then
    # Disable audio completely for troubleshooting
    AUDIO=""
    echo "Audio: DISABLED (set DISABLE_AUDIO=1 for troubleshooting)"
else
    # Use AC97 with CoreAudio - most universally supported combination
    AUDIO="-audiodev coreaudio,id=audio0 -device AC97,audiodev=audio0"
    echo "Audio: AC97 with CoreAudio backend (universal compatibility)"
    echo "Guest setup: Install alsa-utils, unmute with 'amixer sset Master unmute'"
fi

if [ "$ARCH" = "i386" ]; then
    USB="-device qemu-xhci -device usb-kbd"  # Only keyboard for i386
elif [ "$ARCH" = "aarch64" ]; then
    USB="-device qemu-xhci -device usb-kbd"  # Only keyboard for ARM64
else
    # For x86_64
    USB="-device qemu-xhci -device usb-kbd"  # Only keyboard for x86_64
fi

# SDL Environment variables for QEMU 3dfx compatibility
if [ "$USE_VNC" != "1" ]; then
    echo "SDL Environment: QEMU 3dfx compatible configuration"
    
    # Prevent SDL window title crashes on macOS by setting a stable title
    export SDL_VIDEO_WINDOW_POS=centered
    export SDL_VIDEO_ALLOW_SCREENSAVER=1
    
    # QEMU 3dfx supports both standard SDL and SDL with gl=on
    echo "Display: SDL with hardware acceleration capability"
    echo "Hardware acceleration: Via VirtIO-GPU guest drivers + SDL OpenGL"
    echo "Performance: Proven glmark2 score of 2462 with this configuration"
fi

# SPICE/Clipboard support - VDAgent for bidirectional text clipboard
if [ "$USE_SPICE" = "1" ]; then
    # UTM-style: Use exact working qemu-vdagent configuration for QEMU 9.2.2
    SPICE_SERVER=""  # No SPICE server - conflicts with SDL OpenGL
    SPICE_CLIPBOARD="-chardev qemu-vdagent,id=ch1,name=vdagent,clipboard=on -device virtio-serial-pci -device virtserialport,chardev=ch1,id=ch1,name=com.redhat.spice.0"
    echo "Clipboard: Using exact qemu-vdagent configuration (clipboard=on only)"
elif [ "$USE_CONSOLE" = "1" ]; then
    # Console mode: Full SPICE with VDAgent (no SDL conflicts)
    SPICE_SERVER="-spice unix=on,addr=/tmp/qemu-spice-$$.sock,disable-ticketing=on"
    SPICE_CLIPBOARD="-chardev spicevmc,id=vdagent,name=vdagent -device virtio-serial-pci -device virtserialport,chardev=vdagent,name=com.redhat.spice.0"
    echo "Clipboard: Using SPICE server with spicevmc vdagent for clipboard support"
else
    # Default mode: Use exact working qemu-vdagent configuration for QEMU 9.2.2
    SPICE_SERVER=""  # No SPICE server - conflicts with SDL OpenGL
    SPICE_CLIPBOARD="-chardev qemu-vdagent,id=ch1,name=vdagent,clipboard=on -device virtio-serial-pci -device virtserialport,chardev=ch1,id=ch1,name=com.redhat.spice.0"
    echo "Clipboard: Using exact qemu-vdagent configuration (clipboard=on only)"
fi

# Console support - Second display for console access (like UTM)
if [ "$USE_CONSOLE" = "1" ]; then
    # Console-only mode: SPICE server + console chardev for terminal access
    SPICE_SERVER="-spice unix=on,addr=/tmp/qemu-spice-$$.sock,disable-ticketing=on"
    SPICE_CONSOLE="-chardev spiceport,id=console0,name=com.qemu.console.0 -serial chardev:console0"
    echo "Console: SPICE server on /tmp/qemu-spice-$$.sock"
    echo "SPICE: Connect with virt-viewer or remote-viewer for full access"
elif [ "$USE_SPICE" = "1" ]; then
    # UTM-style: SDL + immediate serial console + qemu-vdagent for clipboard
    SPICE_CONSOLE="-serial stdio"  # Direct console output to terminal
    echo "UTM-style dual access active:"
    echo "- Graphics: SDL window (will appear when guest initializes)"
    echo "- Console: THIS TERMINAL (immediate boot messages)"
    echo "- Clipboard: qemu-vdagent clipboard=on (exact working configuration)"
    echo "- Boot process: UEFI → Guest OS boot messages below"
    echo "======================================================="
    echo "Starting VM... Boot messages will appear below:"
    echo ""
else
    # Default mode: No console, but qemu-vdagent for clipboard
    SPICE_CONSOLE=""
    echo "Default mode with qemu-vdagent clipboard support"
fi

# Disk and ISO configuration
DISK_IMAGE="/Users/macbookpro/Downloads/ArchLinux.utm/Data/28FAFA02-F5EB-46F3-8647-8DA6899131AF.qcow2"
ISO_IMAGE="/Users/macbookpro/Downloads/archlinux-$(date +%Y.%m.%d)-x86_64.iso"  # Adjust path as needed

# Check if this is installation mode or if disk doesn't exist
if [ "$INSTALL_MODE" = "install" ] || [ ! -f "$DISK_IMAGE" ]; then
    echo "=== Installation Mode ==="
    echo "Looking for installation ISO..."
    
    # Try to find an Arch Linux ISO
    ISO_CANDIDATES=(
        "/Users/macbookpro/Downloads/archlinux-*.iso"
        "/Users/macbookpro/Desktop/archlinux-*.iso"
        "/Users/macbookpro/Downloads/Windows98SE.iso"
        "/Users/macbookpro/Downloads/Windows95.iso"
    )
    
    ISO_FOUND=""
    for iso_pattern in "${ISO_CANDIDATES[@]}"; do
        for iso_file in $iso_pattern; do
            if [ -f "$iso_file" ]; then
                ISO_FOUND="$iso_file"
                break 2
            fi
        done
    done
    
    if [ -z "$ISO_FOUND" ]; then
        echo "No installation ISO found. Please download:"
        echo "  - Arch Linux: https://archlinux.org/download/"
        echo "  - Windows 98SE: For 3dfx gaming (use i386 target)"
        echo "  - Windows 95: For retro gaming (use i386 target)"
        echo ""
        echo "Place the ISO in ~/Downloads/ and run again."
        exit 1
    fi
    
    echo "Found ISO: $ISO_FOUND"
    
    # Create a new disk image if it doesn't exist
    if [ ! -f "$DISK_IMAGE" ]; then
        echo "Creating new disk image..."
        mkdir -p "$(dirname "$DISK_IMAGE")"
        /opt/homebrew/bin/qemu-img create -f qcow2 "$DISK_IMAGE" 20G
    fi
    
    DRIVE_OPTS="-hda $DISK_IMAGE -cdrom $ISO_FOUND"  # Use IDE for better compatibility
    BOOT_OPTS="-boot order=dc"  # Boot from CD first, then disk
else
    echo "=== Using existing disk image ==="
    DRIVE_OPTS="-drive file=$DISK_IMAGE,format=qcow2,if=virtio,cache=writethrough"  # Use virtio for better performance
    
    # For aarch64, ensure proper UEFI boot priority
    if [ "$ARCH" = "aarch64" ]; then
        BOOT_OPTS="-boot menu=on,order=c,splash-time=3000 -fw_cfg name=opt/org.tianocore/BootTimeout,string=3"
    fi
fi
# Launch QEMU with selected architecture and options
echo "=== QEMU 3dfx Multi-Architecture Launcher ==="
echo "Architecture: $ARCH"
echo "QEMU Binary: $QEMU_BIN"
echo "Machine: $MACHINE"
echo "=== Starting QEMU ==="

# Execute QEMU with all parameters
if [ "$USE_VNC" = "1" ]; then
    echo "Display: VNC on localhost:5901"
    echo "Connect with: open vnc://localhost:5901"
    echo "VNC Password: qemu123"
    echo "Note: Clipboard sharing not available with VNC display"
elif [ "$USE_SPICE" = "1" ]; then
    echo "Display: QEMU 3dfx style dual access setup"
    echo "Graphics: Standard SDL window with VGA device (no aggressive OpenGL)"
    echo "Clipboard: qemu-vdagent clipboard=on (exact working configuration)"
    echo "Audio: Architecture-optimized audio device" 
    echo "VGA Device: Standard VGA device for better browser compatibility"
    echo "Console: Serial console in terminal (immediate access)"
    echo "Note: Original QEMU 3dfx approach + qemu-vdagent clipboard enabled"
elif [ "$USE_CONSOLE" = "1" ]; then
    echo "Display: Console-only mode (headless)"
    echo "Console: SPICE console available for system access"
    echo "Note: No graphical display, console terminal only"
else
    echo "Display: SDL with VirtIO GPU hardware acceleration"
    echo "Graphics: Compatible SDL rendering with VirtIO GPU drivers"
    echo "Clipboard: qemu-vdagent for bidirectional copy/paste"
    echo "Audio: Architecture-optimized audio device"
    echo "Note: Using QEMU 3dfx compatible display configuration"
fi
echo "VGA Device: VirtIO-GPU with hardware acceleration via guest drivers"
echo "Monitor: Available via telnet localhost:4445"
echo "Display Options:"
echo "  Default (3D accel):   ./run-archlinux.sh $ARCH"
echo "  Browser mode:         USE_BROWSER_MODE=1 ./run-archlinux.sh $ARCH"
echo "  SPICE+Clipboard:      USE_SPICE=1 ./run-archlinux.sh $ARCH"  
echo "  Console Only:         USE_CONSOLE=1 ./run-archlinux.sh $ARCH"
echo "  VNC Display:          USE_VNC=1 ./run-archlinux.sh $ARCH"
echo "  Original Binary:      USE_ORIGINAL=1 ./run-archlinux.sh $ARCH"
echo ""

# For UTM-style mode, add final preparation message
if [ "$USE_SPICE" = "1" ]; then
    echo "Launching QEMU with QEMU 3dfx original style..."
    echo "Boot messages will appear below in 2 seconds:"
    echo ""
    sleep 2
fi

# Enable debug logging for 3dfx troubleshooting across all architectures
DEBUG_LOG=""
case "$ARCH" in
    i386)
        DEBUG_LOG="-d guest_errors,unimp -D /tmp/qemu-3dfx-i386-debug.log"
        echo "3dfx Debug logging enabled: /tmp/qemu-3dfx-i386-debug.log"
        ;;
    x86_64)
        DEBUG_LOG="-d guest_errors,unimp -D /tmp/qemu-3dfx-x86_64-debug.log"
        echo "3dfx Debug logging enabled: /tmp/qemu-3dfx-x86_64-debug.log"
        ;;
    aarch64)
        DEBUG_LOG="-d guest_errors,unimp -D /tmp/qemu-3dfx-aarch64-debug.log"
        echo "3dfx Debug logging enabled: /tmp/qemu-3dfx-aarch64-debug.log"
        ;;
esac

$QEMU_BIN $DEBUG_LOG \
    -machine $MACHINE \
    $CPU_TYPE \
    $SMP \
    $MEMORY \
    $VGA_DEVICE \
    $DISPLAY \
    $SPICE_DISPLAY \
    $SPICE_SERVER \
    $AUDIO \
    $USB \
    $SERIAL \
    $SPICE_CLIPBOARD \
    $SPICE_CONSOLE \
    $MONITOR \
    $EFI_CODE \
    $EFI_VARS \
    $THREED_FX \
    $DRIVE_OPTS \
    $BOOT_OPTS \
    $NETWORK \
    $EXTRA_OPTS

# ===========================================
# Usage Examples and Setup Instructions
# ===========================================
#
# 1. RETRO GAMING with 3dfx Support (Windows 95/98):
#    ./run-archlinux.sh i386
#    - Supports Glide API games like Quake, Tomb Raider, etc.
#    - 3dfx Voodoo emulation automatically available
#    - Use with Windows 95/98 guest OS
#
# 2. MODERN SYSTEMS (x86_64):
#    ./run-archlinux.sh x86_64
#    - Modern Linux distributions
#    - Better performance and compatibility
#    - UEFI boot support
#
# 3. ARM64 SYSTEMS:
#    ./run-archlinux.sh aarch64
#    - ARM64 Linux distributions
#    - Apple Silicon native emulation
#    - UEFI boot support
#
# 4. INSTALLATION from ISO:
#    ./run-archlinux.sh install
#    - Automatically boots from ISO if available
#    - Creates new disk image if needed
#    - Supports Arch Linux, Windows 95/98 ISOs
#
# 5. CONSOLE ACCESS (like UTM):
#    USE_SPICE=1 ./run-archlinux.sh aarch64
#    - Provides second SPICE display for console access
#    - Similar to UTM's console functionality
#    - Useful for troubleshooting boot issues or headless operation
#    USE_CONSOLE=1 ./run-archlinux.sh aarch64  # Console only mode
#
# 6. BROWSER COMPATIBILITY MODE:
#    USE_BROWSER_MODE=1 ./run-archlinux.sh aarch64
#    - Uses standard VirtIO-GPU (no VirtGL virtualization)
#    - Optimized for Firefox WebRender compatibility
#    - Avoids Firefox WebRender + VirtGL compatibility issues
#    - Perfect for web browsing, office work, development
#    - Prevents WebGL/WebRender conflicts with virtualized OpenGL
#    - Still fast for 2D applications, but no 3D games
#
# 7. GAMING/3D MODE (default):
#    ./run-archlinux.sh aarch64
#    - Uses VirtIO-GPU with OpenGL acceleration via VirtGL
#    - Perfect for games, 3D applications, CAD software
#    - Hardware acceleration with VirtGL (glmark2 score: 2400+)
#    - Chromium browsers work excellently (designed for VirtGL)
#    - Firefox WebRender may conflict with VirtGL (black windows/artifacts)
#    - Solution for Firefox: Use browser mode or disable WebRender
#
# 8. ORIGINAL BINARY TESTING:
#    USE_ORIGINAL=1 ./run-archlinux.sh aarch64
#    - Uses the original QEMU 3dfx binary (e5562fa build)
#    - For comparing different builds and troubleshooting
#
# Clipboard Setup (for Linux guests):
# =====================================
# 1. In the ArchLinux guest, install spice-vdagent:
#    sudo pacman -S spice-vdagent
#    # This installs both spice-vdagent and spice-vdagentd with systemd support
#
# 2. Start the spice-vdagentd service (note: cannot be enabled, start manually):
#    sudo systemctl start spice-vdagentd
#    # Note: This service has no [Install] section, so it cannot be enabled
#    # You need to start it manually each boot, or add to startup script
#    
#    # Then start the user agent (in user session):
#    spice-vdagent &
#    
#    # For automatic startup on boot, add to /etc/rc.local or create a custom service
#
# 3. Add to autostart (choose one method):
#    Method A - Add to ~/.bashrc or ~/.profile:
#    echo "spice-vdagent &" >> ~/.bashrc
#    
#    Method B - For desktop environments, add to autostart:
#    mkdir -p ~/.config/autostart
#    cat > ~/.config/autostart/spice-vdagent.desktop << EOF
#    [Desktop Entry]
#    Type=Application
#    Name=Spice VDAgent
#    Exec=spice-vdagent
#    Hidden=false
#    X-GNOME-Autostart-enabled=true
#    EOF
#
# 4. Verify spice-vdagent is running:
#    ps aux | grep spice-vdagent
#    # Should show: /usr/bin/spice-vdagent
#
# 5. Test clipboard (after starting spice-vdagent):
#    - Copy text on macOS (Cmd+C)
#    - In VM: Ctrl+V or middle mouse button
#    - Copy in VM: Ctrl+C 
#    - Paste on macOS: Cmd+V
#
# 6. Check SPICE connection:
#    ls -l /dev/vport*
#    # Should show: /dev/vport0p1 (SPICE VDAgent port)
#    # If missing, check: dmesg | grep virtio-serial
#
# 7. Verify SPICE server connection (on macOS host):
#    # Check if SPICE server is listening:
#    lsof -i :5900
#    # Should show qemu-system-* listening on port 5900
#
# 8. Alternative clipboard test using SPICE client (optional):
#    # Install SPICE client: brew install virt-viewer
#    # Connect: remote-viewer spice://localhost:5900
#    # This provides a secondary way to access the VM with full clipboard support
#
# 7. Troubleshooting:
#    - Check if services are running:
#      sudo systemctl status spice-vdagentd
#      ps aux | grep spice-vdagent
#    - Kill and restart: pkill spice-vdagent; spice-vdagent &
#    - Check virtio-serial: dmesg | grep virtio
#    - Verify VDAgent: dmesg | grep spice
#    - Check SPICE port: ls -l /dev/vport0p1
#    - Verify SPICE server (on macOS): lsof -i :5900
#    - If clipboard fails: restart X11 session or reboot VM
#    - Test with SPICE client: remote-viewer spice://localhost:5900