# QEMU 3dfx/Virgl3D for macOS

This repository contains patches packaged as a Homebrew formula to easily install QEMU 10.0.0 with 3dfx Voodoo emulation and Virgl3D OpenGL acceleration support on macOS.

## Features

- **3dfx Voodoo Emulation**: Hardware-accelerated 3dfx Voodoo graphics for retro gaming
- **Virgl3D Support**: Modern OpenGL acceleration for contemporary guests  
- **SDL2 Backend**: Uses SDL2+OpenGL instead of Cocoa for better compatibility
- **Multiple Targets**: Supports i386, x86_64, and aarch64 guest architectures
- **Homebrew Formula**: Easy installation and dependency management
- **macOS Optimized**: Properly handles ARM64 and Intel Macs with XQuartz integration

## Quick Start

```bash
# Clone this repository (homebrew-qemu-3dfx branch)
git clone -b homebrew-qemu-3dfx https://github.com/startergo/qemu-3dfx-macos.git
cd qemu-3dfx-macos

# Run the comprehensive setup and build script
./homebrew-qemu3dfx/test-formula.sh

# Sign the QEMU binary for proper macOS execution (recommended)
cd $(brew --prefix qemu-3dfx)/sign
export QEMU_3DFX_COMMIT=$(cd ~/qemu-3dfx-macos && git rev-parse --short HEAD)
sudo /usr/bin/xattr -c ../bin/qemu-system-* ../bin/qemu-* ../lib/*.dylib
sudo -E bash ./qemu.sign
```

The test script automatically handles:
- Xcode Command Line Tools installation
- XQuartz and X11 libraries setup  
- All Homebrew dependencies installation
- QEMU 10.0.0 building with 3dfx and Virgl3D support
- Installation verification and testing

> **That's it!** The script handles everything needed on fresh systems.

## System Requirements

- **macOS** 10.15+ (supports both Intel and Apple Silicon)
- **At least 4GB free disk space** for building QEMU
- **Internet connection** for downloading source code and dependencies

> **Note**: All dependencies and prerequisites are automatically installed by the test script.

## Binary Signing (Recommended)

After installation, sign the QEMU binary for proper macOS execution:

```bash
# Sign the binary (removes security warnings and enables proper execution)
cd $(brew --prefix qemu-3dfx)/sign
export QEMU_3DFX_COMMIT=$(cd ~/qemu-3dfx-macos && git rev-parse --short HEAD)
sudo /usr/bin/xattr -c ../bin/qemu-system-* ../bin/qemu-* ../lib/*.dylib
sudo -E bash ./qemu.sign

# The script will:
# 1. Create a self-signed certificate if needed
# 2. Sign all QEMU binaries and Glide libraries
# 3. Add proper entitlements and icons
# 4. Verify signatures
```

> **Why sign?** macOS requires signed binaries for hypervisor access and removes security warnings.

### Custom Commit Hash (Advanced)

For build reproducibility or custom versioning, you can specify a custom commit hash:

```bash
# Method 1: Set environment variable before building
export QEMU_3DFX_COMMIT=abc1234
./homebrew-qemu3dfx/test-formula.sh

# Method 2: Manual signing with custom commit
cd $(brew --prefix qemu-3dfx)/sign
export QEMU_3DFX_COMMIT=abc1234
sudo -E bash ./qemu.sign
```

**Commit Hash Priority:**
1. `QEMU_3DFX_COMMIT` environment variable (manual override)
2. Auto-detection from git repository

> **Note**: The formula ensures both build-time `sign_commit` and post-install `qemu.sign` scripts use the same commit hash for signature consistency.

## Dependencies

The test script and Homebrew formula automatically install these dependencies:

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

> **Note**: The formula handles XQuartz integration automatically.

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

1. **Re-run the test script**: `./homebrew-qemu3dfx/test-formula.sh`
2. **Check installation**: `brew list | grep qemu-3dfx`
3. **Sign the binary**: 
   ```bash
   cd $(brew --prefix qemu-3dfx)/sign
   export QEMU_3DFX_COMMIT=$(cd ~/qemu-3dfx-macos && git rev-parse --short HEAD)
   sudo /usr/bin/xattr -c ../bin/qemu-system-* ../bin/qemu-* ../lib/*.dylib
   sudo -E bash ./qemu.sign
   ```
4. **Check logs**: `brew gist-logs qemu-3dfx` for sharing build logs or error details

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

### Technical Details

### Current Version

- **QEMU Version**: 10.0.0 (upgraded from 9.2.2)
- **Formula Version**: 10.0.0-3dfx
- **Architecture Support**: x86_64, i386, aarch64
- **Branch**: homebrew-qemu-3dfx (enhanced Homebrew integration)

### Patches Applied

1. **KJ's 3dfx patches**: Voodoo 1/2/Banshee emulation
2. **Virgl3D SDL2 patches**: SDL2+OpenGL backend
3. **macOS GLSL compatibility**: Metal/OpenGL interoperability
4. **ARM64 build fixes**: Apple Silicon compilation support
5. **Commit hash consistency**: Ensures signature matching between build and post-install phases

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

- **Formula/Installation**: Report to [startergo/qemu-3dfx-macos](https://github.com/startergo/qemu-3dfx-macos) (homebrew-qemu-3dfx branch)
- **3dfx emulation**: Report to the original [kjliew/qemu-3dfx](https://github.com/kjliew/qemu-3dfx)
- **QEMU core**: Report to [QEMU project](https://www.qemu.org/)
- **Homebrew issues**: Check [Homebrew troubleshooting](https://docs.brew.sh/Troubleshooting)

### Development

```bash
# Clone the homebrew-qemu-3dfx branch for development
git clone -b homebrew-qemu-3dfx https://github.com/startergo/qemu-3dfx-macos.git

# Test local formula changes
brew install --build-from-source ./homebrew-qemu3dfx/Formula/qemu-3dfx.rb

# Debug with verbose output
./homebrew-qemu3dfx/test-formula.sh

# Test with custom commit hash
export QEMU_3DFX_COMMIT=abc1234
./homebrew-qemu3dfx/test-formula.sh

# Formula validation
brew audit --strict ./homebrew-qemu3dfx/Formula/qemu-3dfx.rb
```

### Repository Structure

- **Main branch**: Original upstream synchronization
- **homebrew-qemu-3dfx branch**: Enhanced Homebrew formula with:
  - Submodule + symlinks architecture for automatic upstream sync
  - Commit hash consistency between build and signing phases
  - Enhanced macOS integration and signing support
  - GitHub Actions workflows preservation

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
