# QEMU 3dfx/Virgl3D for macOS

This repository contains KJ's patches packaged as a Homebrew formula to easily install QEMU 10.0.0 with 3dfx Voodoo emulation and Virgl3D OpenGL acceleration support on macOS.

## Features

- **3dfx Voodoo Emulation**: Hardware-accelerated 3dfx Voodoo graphics for retro gaming
- **Virgl3D Support**: Modern OpenGL acceleration for contemporary guests  
- **SDL2 Backend**: Uses SDL2+OpenGL instead of Cocoa for better compatibility
- **Multiple Targets**: Supports i386, x86_64, and aarch64 guest architectures
- **Homebrew Formula**: Easy installation and dependency management
- **macOS Optimized**: Properly handles ARM64 and Intel Macs with XQuartz integration

## Quick Start

```bash
# Clone this repository
git clone https://github.com/startergo/qemu-3dfx-macos.git
cd qemu-3dfx-macos

# RECOMMENDED: Use the comprehensive test script (handles all setup automatically)
./homebrew-qemu3dfx/test-formula.sh

# The test script will automatically:
# 1. Install Xcode Command Line Tools
# 2. Install XQuartz and set up X11 libraries
# 3. Install all required dependencies via Homebrew
# 4. Set up X11 headers for Mesa GL support
# 5. Configure experimental patches (replicating CI workflow)
# 6. Build QEMU 10.0.0 with 3dfx and Virgl3D support
# 7. Run verification tests and show usage examples

# Alternative (only if you've already installed ALL prerequisites manually):
# brew install ./homebrew-qemu3dfx/Formula/qemu-3dfx.rb
```

> **Important**: On a fresh system, always use `./homebrew-qemu3dfx/test-formula.sh` as it performs essential setup steps that the direct formula install does not handle.

## Prerequisites

Before installing QEMU 3dfx, you need to set up the required dependencies:

### 1. Install Xcode Command Line Tools
```bash
xcode-select --install
```

### 2. Install Homebrew (if not already installed)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 3. Install XQuartz
```bash
# Install XQuartz (required for Mesa GL context support)
brew install --cask xquartz

# After installation, log out and log back in, or restart your Mac
# This ensures XQuartz is properly integrated with the system
```

### 4. Install Required Dependencies
```bash
# Install core dependencies that the formula needs
brew install cmake meson ninja pkg-config python@3.12

# Install X11 and OpenGL libraries
brew install libx11 libxext libxfixes libxrandr libxinerama libxi libxcursor xorgproto

# Install additional dependencies
brew install glib pixman libepoxy sdl2 gettext libffi
```

### System Requirements
- **macOS** 10.15+ (supports both Intel and Apple Silicon)
- **At least 4GB free disk space** for building QEMU
- **Internet connection** for downloading source code and dependencies

## Installation Methods

### Method 1: Comprehensive Setup Script (Recommended for Fresh Systems)

The `test-formula.sh` script replicates the CI workflow and handles all setup automatically:

```bash
# Clone the repository
git clone https://github.com/startergo/qemu-3dfx-macos.git
cd qemu-3dfx-macos

# Run the comprehensive setup script
./homebrew-qemu3dfx/test-formula.sh

# This script automatically performs:
# - Xcode Command Line Tools installation
# - XQuartz installation and X11 library setup
# - All Homebrew dependencies installation
# - X11 headers setup for Mesa GL support
# - Experimental patches configuration (matching CI workflow)
# - Formula building with verbose output
# - Installation verification and testing
```

### Method 2: Direct Formula (Only if Prerequisites Already Installed)

```bash
# ⚠️ WARNING: This will FAIL on fresh systems without proper setup
# Only use this if you've manually installed ALL prerequisites
brew install ./homebrew-qemu3dfx/Formula/qemu-3dfx.rb
```

### Method 3: Manual Setup + Formula (Advanced Users)

If you prefer to install prerequisites manually, follow the complete setup guide below:

```bash
# Step 1: Install Xcode Command Line Tools
xcode-select --install

# Step 2: Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Step 3: Install XQuartz and set up X11 structure
brew install --cask xquartz
sudo mkdir -p /opt/X11/lib /opt/X11/include

# Step 4: Install ALL required dependencies
brew install capstone glib gettext gnutls libepoxy libgcrypt libslirp libusb
brew install jpeg-turbo lz4 opus sdl2 zstd sdl12-compat sdl2_net sdl2_sound mt32emu
brew install git wget cmake ninja meson pkg-config pixman libffi python@3.12
brew install sdl2_image spice-protocol spice-server
brew install libx11 libxext libxfixes libxrandr libxinerama libxi libxcursor
brew install xorgproto libxxf86vm

# Step 5: Set up X11 headers for Mesa GL
sudo mkdir -p /usr/local/include/X11/extensions
sudo cp -rf /opt/homebrew/include/X11/* /usr/local/include/X11/ 2>/dev/null || true

# Step 6: Install Python modules
python3 -m pip install --break-system-packages PyYAML || true

# Step 7: Clone and install
git clone https://github.com/startergo/qemu-3dfx-macos.git
cd qemu-3dfx-macos
brew install ./homebrew-qemu3dfx/Formula/qemu-3dfx.rb
```

## Dependencies

The Homebrew formula automatically installs these dependencies:

**Core Build Tools:**
- `cmake`, `meson`, `ninja`, `pkg-config`
- `python@3.12`

**QEMU Core Dependencies:**
- `capstone`, `glib`, `gettext`, `gnutls`
- `libepoxy`, `libgcrypt`, `libslirp`, `libusb`
- `jpeg-turbo`, `lz4`, `opus`, `sdl2`, `zstd`
- `pixman`, `libffi`, `ncurses`, `sdl2_image`

**SPICE Protocol Support:**
- `spice-protocol`, `spice-server`

**Gaming and Multimedia Features:**
- `sdl12-compat` (SDL 1.2 compatibility layer)
- `sdl2_net` (network gaming support)
- `sdl2_sound` (enhanced audio formats)
- `mt32emu` (Roland MT-32 emulation for retro games)

**X11/OpenGL Support:**
- `libx11`, `libxext`, `libxfixes`, `libxrandr`
- `libxinerama`, `libxi`, `libxcursor`
- `xorgproto`, `libxxf86vm`

> **Note**: The formula handles XQuartz integration and X11 header setup automatically.

## Installation Output

After successful installation via Homebrew:

```
/opt/homebrew/                       # Homebrew prefix
├── bin/
│   ├── qemu-system-i386            # 32-bit x86 emulator
│   ├── qemu-system-x86_64          # 64-bit x86 emulator
│   └── qemu-system-aarch64         # ARM64 emulator
├── share/qemu/                     # QEMU data files
└── Cellar/qemu-3dfx/               # Formula installation
```

## Usage Examples

### 3dfx Voodoo Gaming (DOS/Windows 9x)

```bash
# Run DOS/Windows 9x with Voodoo2 support
qemu-system-i386 \
  -machine pc-i440fx-2.1 \
  -cpu pentium2 \
  -m 128 \
  -device 3dfx,voodoo=voodoo2 \
  -hda dos.img \
  -display sdl
```

### Modern Linux with Virgl3D

```bash
# Run Linux with hardware OpenGL acceleration
qemu-system-x86_64 \
  -accel hvf \
  -m 2048 \
  -device virtio-vga-gl \
  -display sdl,gl=on \
  -hda linux.img
```

### Windows 10/11 with Virgl3D

```bash
# Run Windows with DirectX to OpenGL translation
qemu-system-x86_64 \
  -accel hvf \
  -m 4096 \
  -smp 4 \
  -device virtio-vga-gl \
  -display sdl,gl=on \
  -device virtio-scsi-pci \
  -drive file=windows10.img,if=virtio,format=qcow2
```

> **Note**: On macOS, use `-accel hvf` (Hypervisor Framework) instead of `-enable-kvm`.

## 3dfx Device Options

| Option | Description |
|--------|-------------|
| `3dfx,voodoo=voodoo1` | Voodoo Graphics (original) |
| `3dfx,voodoo=voodoo2` | Voodoo2 (recommended for most games) |
| `3dfx,voodoo=banshee` | Voodoo Banshee |

## Virgl3D Options

| Option | Description |
|--------|-------------|
| `virtio-vga-gl` | VirtIO GPU with OpenGL support |
| `virtio-gpu-gl-pci` | VirtIO GPU PCI with OpenGL |
| `-display sdl,gl=on` | Enable OpenGL in SDL display |
| `-display gtk,gl=on` | Enable OpenGL in GTK display |

## Troubleshooting

### Installation Issues

1. **Check dependencies**: `brew list | grep qemu-3dfx`
2. **Reinstall formula**: `brew uninstall qemu-3dfx && brew install ./homebrew-qemu3dfx/Formula/qemu-3dfx.rb`
3. **Use debug script**: `./homebrew-qemu3dfx/test-formula.sh`
4. **Check logs**: `brew gist-logs qemu-3dfx` for sharing error details

### Formula Validation

```bash
# Validate formula syntax
cd homebrew-qemu3dfx
brew audit --strict Formula/qemu-3dfx.rb

# Test the formula
brew test qemu-3dfx
```

### Missing Dependencies

```bash
# XQuartz installation
brew install --cask xquartz

# Manual X11 headers setup (if needed)
sudo mkdir -p /usr/local/include/X11/extensions
sudo cp /opt/homebrew/include/X11/extensions/* /usr/local/include/X11/extensions/
```

### Performance Issues

1. **Enable HVF** (on both Intel and Apple Silicon): Add `-accel hvf` flag
2. **Adjust memory**: Increase `-m` parameter
3. **Use SMP**: Add `-smp cores=2,threads=2`
4. **Check OpenGL**: Verify with `glxinfo` (install with `brew install mesa`)

### Verification Commands

```bash
# Check QEMU 3dfx signature
qemu-system-x86_64 --version | grep "qemu-3dfx@"

# Test 3dfx device support
qemu-system-i386 -device help | grep 3dfx

# Check installed location
brew --prefix qemu-3dfx
```

## Supported Games and Software

### 3dfx Voodoo Games
- Quake II, Unreal, Half-Life
- Need for Speed series
- Tomb Raider series
- And hundreds more Glide games

### Virgl3D Applications
- Modern Linux distributions
- Windows 10/11 (with virtio drivers)
- OpenGL applications and games

## Technical Details

### Current Version

- **QEMU Version**: 10.0.0 (upgraded from 9.2.2)
- **Formula Version**: 10.0.0-3dfx
- **Architecture Support**: x86_64, i386, aarch64

### Patches Applied

1. **KJ's 3dfx patches**: Voodoo 1/2/Banshee emulation
2. **Virgl3D SDL2 patches**: SDL2+OpenGL backend
3. **macOS GLSL compatibility**: Metal/OpenGL interoperability
4. **ARM64 build fixes**: Apple Silicon compilation support

### Build Configuration

- **QEMU Targets**: i386-softmmu, x86_64-softmmu, aarch64-softmmu
- **Display Backend**: SDL2 (Cocoa disabled for 3dfx compatibility)
- **OpenGL**: Enabled with custom virglrenderer
- **Acceleration**: HVF (Hypervisor Framework) for macOS

### Formula Structure

```
homebrew-qemu3dfx/
├── Formula/
│   └── qemu-3dfx.rb           # Main Homebrew formula
├── test-formula.sh            # Testing and debug script
└── patches/                   # KJ's patches applied during build
```

### Installation Verification

```bash
# Check installation
brew list qemu-3dfx

# Verify 3dfx signature
$(brew --prefix qemu-3dfx)/bin/qemu-system-x86_64 --version

# Test formula
brew test qemu-3dfx
```

## Contributing

This Homebrew formula is based on KJ's excellent qemu-3dfx project. For issues with:

- **Formula/Installation**: Report to [startergo/qemu-3dfx-macos](https://github.com/startergo/qemu-3dfx-macos)
- **3dfx emulation**: Report to the original [kjliew/qemu-3dfx](https://github.com/kjliew/qemu-3dfx)
- **QEMU core**: Report to [QEMU project](https://www.qemu.org/)
- **Homebrew issues**: Check [Homebrew troubleshooting](https://docs.brew.sh/Troubleshooting)

### Development

```bash
# Test local formula changes
brew install --build-from-source ./homebrew-qemu3dfx/Formula/qemu-3dfx.rb

# Debug with verbose output
./homebrew-qemu3dfx/test-formula.sh

# Formula validation
brew audit --strict ./homebrew-qemu3dfx/Formula/qemu-3dfx.rb
```

> **Note**: This repository provides a Homebrew-packaged version of KJ's original qemu-3dfx project, with enhanced macOS integration and ARM64 support.

## License

- QEMU: GPL v2
- virglrenderer: MIT License  
- KJ's patches: See original repository
- This Homebrew formula: MIT License

> **Based on**: This repository is a macOS-focused enhancement of [KJ's original qemu-3dfx project](https://github.com/kjliew/qemu-3dfx), with Homebrew packaging and comprehensive macOS integration.

## Acknowledgments

- **KJ (kjliew)** for the amazing 3dfx patches and Virgl3D work
- **QEMU project** for the incredible emulation platform
- **Virgl project** for OpenGL virtualization
- **Homebrew** for macOS package management
