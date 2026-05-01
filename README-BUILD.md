# QEMU 3dfx/Virgl3D for macOS

QEMU 11.0.0 with 3dfx Voodoo emulation and Virgl3D OpenGL acceleration for macOS.

## Features

- **3dfx Voodoo Emulation**: Hardware-accelerated 3dfx Voodoo graphics for retro gaming
- **Virgl3D Support**: Modern OpenGL acceleration for contemporary guests
- **SDL2 Backend**: SDL2+OpenGL display with optional Cocoa fallback
- **Multiple Targets**: i386, x86_64, and aarch64 guest architectures
- **ANGLE/libepoxy**: EGL 1.5 via Metal backend on macOS

## Install from Source

### Requirements

- macOS (Apple Silicon or Intel)
- Xcode Command Line Tools
- Homebrew
- ~10GB disk space for building

### Build and Install

```bash
git clone https://github.com/startergo/qemu-3dfx-macos.git
cd qemu-3dfx-macos
git submodule update --init --remote
cd homebrew-qemu3dfx
./test-formula.sh
```

The script handles everything: dependencies, virglrenderer build, QEMU patch+build, Glide libraries, and code signing. Binaries install directly into `$(brew --prefix)` and are immediately in PATH.

### Experimental Patches (SDL Clipboard)

```bash
QEMU_3DFX_EXPERIMENTAL_PATCHES=true ./test-formula.sh
```

### Verify

```bash
qemu-system-x86_64 --version
qemu-system-i386 --version
```

## Install from CI Tarball

Download the latest tarball from [GitHub Actions](https://github.com/startergo/qemu-3dfx-macos/actions) and:

```bash
# Extract (tarball contains opt/homebrew/ and usr/local/)
sudo tar --zstd -xf qemu-11.0.0-3dfx-*-darwin-$(uname -m).tar.zst -C /

# Sign binaries
cd /opt/homebrew/sign
sudo /usr/bin/xattr -c ../bin/qemu-system-* ../bin/qemu-* ../lib/*.dylib
sudo -E bash ./qemu.sign
```

## Uninstall

```bash
BREW_PREFIX="$(brew --prefix)"

# QEMU binaries
rm -f "$BREW_PREFIX"/bin/qemu-system-* "$BREW_PREFIX"/bin/qemu-img
rm -f "$BREW_PREFIX"/bin/qemu-io "$BREW_PREFIX"/bin/qemu-nbd
rm -f "$BREW_PREFIX"/bin/qemu-edid "$BREW_PREFIX"/bin/qemu-ga
rm -f "$BREW_PREFIX"/bin/qemu-pr-helper "$BREW_PREFIX"/bin/qemu-storage-daemon

# QEMU data files
rm -rf "$BREW_PREFIX"/share/qemu

# Glide libraries
rm -f "$BREW_PREFIX"/lib/*glide*

# Virglrenderer
rm -rf "$BREW_PREFIX/opt/virglrenderer-3dfx"

# Signing directory
rm -rf "$BREW_PREFIX"/sign
```

## Usage

### CPU Invocation

Guest wrappers (since commit 5112b64) are optimized for x86-64-v2 SIMD instruction sets (SSE4.2, AVX). When using QEMU TCG (software emulation), pass `-cpu max` to enable the full x86-64-v2 architecture level:

```bash
qemu-system-i386 -cpu max ...
qemu-system-x86_64 -cpu max ...
```

Intel/AMD hosts with KVM/WHPX acceleration already support x86-64-v2 natively.

### 3dfx (32-bit DOS/Windows guests)

```bash
qemu-system-i386 -machine pc-i440fx-2.1 -cpu max -m 128 -hda game.img
```

Requires guest-side Glide wrapper DLLs (glide2x.dll, glide3x.dll, fxmemmap.vxd).

### Virgl3D (64-bit guests)

```bash
qemu-system-x86_64 -cpu max -device virtio-vga-gl -display sdl,gl=on -hda os.img
```

## Building Guest Wrappers (Docker)

Guest wrapper DLLs/DXE/OVL are built using cross-compilation toolchains. A Docker setup is provided:

```bash
# Build the image
docker build --platform linux/amd64 \
  --build-arg COMMIT_ID=$(git rev-parse --short HEAD) \
  -t qemu-3dfx-wrappers .

# Extract the ISO
mkdir -p output
docker run --rm -v "$(pwd)/output:/output" qemu-3dfx-wrappers
```

The ISO contains Glide wrappers, Mesa GL wrappers, and g2xwrap for guest installation.

## CI Workflows

| Workflow | Description |
|----------|-------------|
| `build-and-package.yml` | macOS ARM64 + x86_64 build, tarball packaging |
| `build-windows.yml` | Windows MINGW64 + UCRT64 build, guest wrappers, nightly release |

Both are triggered via `workflow_dispatch` from the Actions tab.

## What Gets Built

**Host-side (macOS):**
- QEMU 11.0.0 with 3dfx Mesa GL pass-through patches
- Custom virglrenderer 1.3.0 (patched for macOS EGL)
- Glide host libraries (OpenGLide — libglide2x, libglide3x)

**Guest-side (via Docker/CI):**
- Glide wrapper DLLs (glide2x.dll, glide3x.dll)
- Glide VXD/SYS drivers (fxmemmap.vxd, fxptl.sys)
- DOS DXE and OVL wrappers
- Mesa OpenGL wrapper (opengl32.dll)
- g2xwrap

## License

- QEMU: GPL v2
- virglrenderer: MIT
- KJ's patches: See [qemu-3dfx-arch](https://github.com/startergo/qemu-3dfx-arch)
- This packaging: MIT
