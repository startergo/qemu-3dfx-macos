# QEMU 3dfx/Virgl3D Build for macOS

This repository contains KJ's patches and a comprehensive build script to compile QEMU 9.2.2 with 3dfx Voodoo emulation and Virgl3D OpenGL acceleration support on macOS.

## Features

- **3dfx Voodoo Emulation**: Hardware-accelerated 3dfx Voodoo graphics for retro gaming
- **Virgl3D Support**: Modern OpenGL acceleration for contemporary guests  
- **SDL2 Backend**: Uses SDL2+OpenGL instead of Cocoa for better compatibility
- **Multiple Targets**: Supports i386, x86_64, and aarch64 guest architectures
- **Automated Build**: Single script handles all dependencies and compilation
- **macOS Optimized**: Properly handles Homebrew conflicts and macOS-specific issues

## Quick Start

```bash
# Clone this repository
git clone https://github.com/startergo/qemu-3dfx-macos.git
cd qemu-3dfx-macos

# Run the build script
./scripts/build-qemu-3dfx.sh

# The script will:
# 1. Check and install dependencies via Homebrew
# 2. Download QEMU 9.2.2 source code
# 3. Apply KJ's 3dfx and Virgl3D patches
# 4. Build virglrenderer from source
# 5. Build QEMU with 3dfx and Virgl3D support
# 6. Verify the build and show usage examples
```

## Prerequisites

- **macOS** (tested on macOS 10.15+)
- **Homebrew** package manager
- **Xcode Command Line Tools**: `xcode-select --install`
- **XQuartz**: Required for Mesa GL context support ([Download](https://www.xquartz.org/) or `brew install --cask xquartz`)
- **At least 4GB free disk space** for build files

## Build Script Usage

```bash
./scripts/build-qemu-3dfx.sh [COMMAND]
```

### Commands

| Command | Description |
|---------|-------------|
| `build` (default) | Build QEMU with 3dfx/Virgl3D support |
| `clean` | Clean all build directories |
| `backup-homebrew` | Backup conflicting Homebrew packages |
| `restore-homebrew` | Restore backed up Homebrew packages |
| `info` | Show build information and usage examples |
| `test` | Test the built QEMU binaries |
| `help` | Show detailed help |

### Examples

```bash
# Build everything (default)
./scripts/build-qemu-3dfx.sh

# Clean build files
./scripts/build-qemu-3dfx.sh clean

# Show build status and examples
./scripts/build-qemu-3dfx.sh info

# Test the built binaries
./scripts/build-qemu-3dfx.sh test
```

## Dependencies

The script automatically installs these dependencies via Homebrew:

**Core Build Tools:**
- `git`, `wget`, `cmake`, `ninja`, `meson`, `pkg-config`
- `glib`, `pixman`, `libepoxy`, `gettext`, `libffi`
- `python@3.12`

**SDL and Gaming Dependencies:**
- `sdl2`, `sdl2_image`, `sdl2_net`, `sdl2_sound`
- `sdl12-compat` (SDL 1.2 compatibility layer)
- `mt32emu` (Roland MT-32 emulation for retro games)

> **Note**: The SDL and gaming dependencies are essential for DOSBox-style gaming and provide enhanced audio/video support for retro games running in QEMU.

### Gaming and Multimedia Features

The included dependencies enable enhanced gaming capabilities:

- **SDL2 suite**: Modern cross-platform multimedia support
- **SDL 1.2 compatibility**: Support for legacy games requiring SDL 1.2
- **Network gaming**: `sdl2_net` enables multiplayer gaming over network
- **Enhanced audio**: `sdl2_sound` provides improved audio format support  
- **MT-32 emulation**: `mt32emu` enables Roland MT-32 sound for retro games
- **Image formats**: `sdl2_image` supports various image formats for game assets

These dependencies make QEMU 3dfx compatible with DOSBox-style gaming setups and provide comprehensive multimedia support for both retro and modern games.

### Homebrew Conflicts

The script automatically handles conflicts with:
- `virglrenderer` (backs up and removes)
- `qemu-virgl-deps` (backs up and removes)

These packages are backed up and can be restored later using `./scripts/build-qemu-3dfx.sh restore-homebrew`.

## Build Output

After a successful build, you'll find:

```
build/
├── qemu-9.2.2/                    # QEMU source with patches applied
│   └── build/                     # QEMU build directory
│       ├── qemu-system-i386       # 32-bit x86 emulator
│       ├── qemu-system-x86_64     # 64-bit x86 emulator
│       └── qemu-system-aarch64    # ARM64 emulator
├── virglrenderer/                 # virglrenderer source
└── virglrenderer-install/         # virglrenderer installation
```

## Usage Examples

### 3dfx Voodoo Gaming (DOS/Windows 9x)

```bash
# Run DOS/Windows 9x with Voodoo2 support
./build/qemu-9.2.2/build/qemu-system-i386 \
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
./build/qemu-9.2.2/build/qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -device virtio-vga-gl \
  -display sdl,gl=on \
  -hda linux.img
```

### Windows 10/11 with Virgl3D

```bash
# Run Windows with DirectX to OpenGL translation
./build/qemu-9.2.2/build/qemu-system-x86_64 \
  -enable-kvm \
  -m 4096 \
  -smp 4 \
  -device virtio-vga-gl \
  -display sdl,gl=on \
  -device virtio-scsi-pci \
  -drive file=windows10.img,if=virtio,format=qcow2
```

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

### Build Fails

1. **Check dependencies**: `./scripts/build-qemu-3dfx.sh info`
2. **Clean and rebuild**: `./scripts/build-qemu-3dfx.sh clean && ./scripts/build-qemu-3dfx.sh build`
3. **Check logs**: Build logs are in `build/qemu-9.2.2/build/`

### Homebrew Conflicts

```bash
# Backup conflicting packages
./scripts/build-qemu-3dfx.sh backup-homebrew

# Restore after build
./scripts/build-qemu-3dfx.sh restore-homebrew
```

### Missing libepoxy

```bash
# Manually install and link
brew install libepoxy
brew link libepoxy
```

### QEMU Crashes

1. **Check OpenGL support**: Ensure your Mac supports OpenGL
2. **Try different display**: Use `-display sdl` instead of `-display sdl,gl=on`
3. **Update graphics drivers**: Ensure macOS is up to date

### Performance Issues

1. **Enable KVM** (on Intel Macs): Add `-enable-kvm` flag
2. **Use hvf** (on Apple Silicon): Add `-enable-hvf` flag  
3. **Adjust memory**: Increase `-m` parameter
4. **Use SMP**: Add `-smp cores=2,threads=2`

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

### Patches Applied

1. **00-qemu92x-mesa-glide.patch**: KJ's main 3dfx/Mesa patch
2. **Virgl3D patches**: SDL2+OpenGL and macOS GLSL compatibility
3. **GL_CONTEXTALPHA fix**: Replaces deprecated constant

### Build Configuration

- **QEMU Targets**: i386-softmmu, x86_64-softmmu, aarch64-softmmu
- **Display Backend**: SDL2 (Cocoa disabled)
- **OpenGL**: Enabled with custom virglrenderer
- **Debug**: Debug symbols included

### Directory Structure

```
build/
├── qemu-9.2.2/              # QEMU source with patches
├── virglrenderer/           # virglrenderer source  
├── virglrenderer-install/   # Custom virglrenderer build
└── qemu-install/           # QEMU installation (optional)
```

## Contributing

This build script is based on KJ's excellent qemu-3dfx project. For issues with:

- **3dfx emulation**: Report to [startergo/qemu-3dfx-macos](https://github.com/startergo/qemu-3dfx-macos)
- **Build script**: Report to this repository
- **QEMU core**: Report to [QEMU project](https://www.qemu.org/)
- **Original KJ's work**: See [kjliew/qemu-3dfx](https://github.com/kjliew/qemu-3dfx)

> **Note**: This repository is a macOS-focused fork of KJ's original qemu-3dfx project, with enhanced build automation, dependency management, and comprehensive documentation for macOS users.

## License

- QEMU: GPL v2
- virglrenderer: MIT License  
- KJ's patches: See original repository
- This build script: MIT License

> **Based on**: This repository is a macOS-focused enhancement of [KJ's original qemu-3dfx project](https://github.com/kjliew/qemu-3dfx), with additional build automation and documentation.

## Acknowledgments

- **KJ (kjliew)** for the amazing 3dfx patches and Virgl3D work
- **QEMU project** for the incredible emulation platform
- **Virgl project** for OpenGL virtualization
- **Homebrew** for macOS package management
