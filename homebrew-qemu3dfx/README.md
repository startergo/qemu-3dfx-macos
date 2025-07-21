# Homebrew QEMU 3dfx Tap

A Homebrew tap for installing QEMU with 3dfx Voodoo emulation and Virgl3D OpenGL acceleration support on macOS.

## What is this?

This tap provides pre-built formulae for:

- **qemu-3dfx**: QEMU 9.2.2 with KJ's 3dfx patches and Virgl3D support
- **virglrenderer-3dfx**: Virgl3D renderer with macOS compatibility patches  
- **glide-3dfx**: 3dfx Glide wrapper libraries for legacy game support

## Key Features

### Comprehensive macOS Patching
Our formulae include essential patches for proper macOS operation:

**QEMU Patches:**
- Virgl3D SDL2+OpenGL compatibility patches
- EGL optional configuration for macOS (no EGL support needed)
- macOS-specific OpenGL context handling
- GLSL shader version fixes for macOS

**Virglrenderer Patches:**
- Apple OpenGL vendor detection and handling
- GLSL version adjustments (130→140) for macOS compatibility
- Texture storage multisample fixes for macOS
- Fragment coordinate conventions handling for Apple GL
- Uniform buffer object extension fixes for Apple GL
- Apple-specific OpenGL driver workarounds

These patches ensure proper operation with macOS OpenGL drivers and fix common compatibility issues that prevent Virgl3D from working correctly on macOS.

## Installation

### Quick Installation

```bash
# Automatic installation with cleanup
curl -fsSL https://raw.githubusercontent.com/startergo/homebrew-qemu3dfx/main/install.sh | bash

# Or manual step-by-step:
./cleanup.sh --check-only  # Check what would be removed
./cleanup.sh --backup      # Remove conflicts and backup
brew tap startergo/qemu3dfx
brew install qemu-3dfx
```

### Add the tap

```bash
brew tap startergo/qemu3dfx
```

### Install QEMU with 3dfx support

```bash
# Check for conflicting packages first
./cleanup.sh --check-only

# Install the complete QEMU 3dfx package
brew install qemu-3dfx

# Or install components separately
brew install virglrenderer-3dfx
brew install glide-3dfx
brew install qemu-3dfx
```

### Quick verification

```bash
# Check QEMU version
qemu-system-x86_64 --version

# Check for 3dfx device support
qemu-system-i386 -device help | grep 3dfx

# Check for Virgl3D support  
qemu-system-x86_64 -device help | grep virtio-vga-gl
```

## Usage Examples

### Running DOS/Windows 9x with 3dfx Voodoo

```bash
qemu-system-i386 \
  -machine pc-i440fx-2.1 \
  -cpu pentium2 \
  -m 128 \
  -device 3dfx,voodoo=voodoo2 \
  -hda dos.img \
  -display sdl
```

### Running Linux with Virgl3D acceleration

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -device virtio-vga-gl \
  -display sdl,gl=on \
  -hda linux.img
```

### Running Windows 10/11 with GPU passthrough preparation

```bash
qemu-system-x86_64 \
  -m 4096 \
  -smp 4 \
  -device virtio-vga-gl \
  -display sdl,gl=on \
  -device virtio-net,netdev=net0 \
  -netdev user,id=net0 \
  -hda windows10.img
```

## Features

### 3dfx Voodoo Emulation
- Voodoo1, Voodoo2, and Voodoo Banshee support
- Glide 2.x and 3.x API emulation
- Perfect for running classic 3dfx games from the 1990s

### Virgl3D OpenGL Acceleration
- Modern OpenGL acceleration for guest VMs
- Works with Linux guests that support Virgl
- Significantly improved graphics performance

### macOS Optimized
- Built specifically for macOS (Intel and Apple Silicon)
- Uses SDL2 instead of Cocoa for better compatibility
- No EGL/GLX dependencies (not available on macOS)

## Supported Targets

- `i386-softmmu` - For DOS, Windows 9x, early Linux
- `x86_64-softmmu` - For modern x86_64 systems
- `aarch64-softmmu` - For ARM64 systems

## Requirements

- macOS 10.15+ (Catalina or later)
- Xcode Command Line Tools
- Homebrew
- At least 4GB free disk space

## Building from Source

If you prefer to build from source instead of using the tap:

```bash
# Clone the source repository
git clone https://github.com/startergo/qemu-3dfx-macos.git
cd qemu-3dfx-macos

# Run the build script
./build-qemu-3dfx.sh
```

## Troubleshooting

### Library not found errors

If you get library not found errors, ensure the Glide libraries are properly linked:

```bash
# Check if libraries are installed
ls -la $(brew --prefix)/lib/libglide*

# Create compatibility symlinks if needed
sudo ln -sf $(brew --prefix)/lib/libglide2x.dylib /usr/local/lib/
sudo ln -sf $(brew --prefix)/lib/libglide3x.dylib /usr/local/lib/
```

### Code signing issues

If you encounter code signing issues:

```bash
# Remove quarantine attribute
sudo xattr -r -d com.apple.quarantine $(brew --prefix)/bin/qemu-*

# Or sign the binaries yourself
codesign --force --deep --sign - $(brew --prefix)/bin/qemu-*
```

### Performance issues

For best performance:
- Use SDL display (`-display sdl`)
- Enable hardware acceleration when available
- Allocate appropriate memory to the guest VM
- Use virtio devices for modern guests

## Compatibility

### Tested Games (3dfx)
- Quake II
- Unreal Tournament
- Half-Life
- Tomb Raider
- Need for Speed II SE
- Many other Glide-based games

### Tested Operating Systems
- MS-DOS 6.22 + Windows 3.1
- Windows 95/98/ME
- Various Linux distributions
- FreeDOS

## Contributing

This tap is based on the [qemu-3dfx-macos](https://github.com/startergo/qemu-3dfx-macos) project.

To contribute:
1. Fork the repository
2. Make your changes
3. Test thoroughly
4. Submit a pull request

## Credits

- **KJ**: Original QEMU 3dfx patches and Mesa/Glide integration
- **startergo**: macOS adaptation and build automation
- **QEMU Team**: Base QEMU emulator
- **Virgl Team**: Virgl3D renderer
- **3dfx Interactive**: Original Glide API (legacy)

## License

This tap and its formulae are licensed under GPL-2.0-or-later, consistent with QEMU's licensing.

Individual components may have different licenses:
- QEMU: GPL-2.0-or-later
- Virglrenderer: MIT
- 3dfx components: Various (see individual sources)

## Links

- [QEMU 3dfx macOS Project](https://github.com/startergo/qemu-3dfx-macos)
- [Original QEMU](https://www.qemu.org/)
- [Virglrenderer](https://gitlab.freedesktop.org/virgl/virglrenderer)
- [Homebrew](https://brew.sh/)
