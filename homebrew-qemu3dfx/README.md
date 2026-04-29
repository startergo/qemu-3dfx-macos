# QEMU 3dfx — macOS Homebrew Install

Build and install QEMU with 3dfx/Glide and Virgl3D acceleration directly into your Homebrew prefix.

## Requirements

- macOS (Apple Silicon or Intel)
- Xcode Command Line Tools
- Homebrew

## Install

```bash
git clone https://github.com/startergo/qemu-3dfx-macos.git
cd qemu-3dfx-macos
git submodule update --init --remote
cd homebrew-qemu3dfx
./test-formula.sh
```

The script will:

1. Install all dependencies via Homebrew
2. Build virglrenderer with macOS EGL support
3. Download, patch, and build QEMU 11.0.0 with 3dfx + Virgl3D
4. Build Glide libraries (OpenGLide)
5. Install everything into `$(brew --prefix)` — binaries are immediately in PATH
6. Ad-hoc code-sign all binaries

### Experimental patches

To enable SDL clipboard and other experimental patches:

```bash
QEMU_3DFX_EXPERIMENTAL_PATCHES=true ./test-formula.sh
```

## Verify

```bash
qemu-system-x86_64 --version
qemu-system-i386 --version
```

## Usage

### 3dfx acceleration (32-bit guests)

```bash
qemu-system-i386 -machine pc-i440fx-2.1 -cpu pentium2 -m 128 -hda game.img
```

### Virgl3D acceleration (64-bit guests)

```bash
qemu-system-x86_64 -device virtio-vga-gl -display sdl,gl=on -hda os.img
```

## Uninstall

```bash
BREW_PREFIX="$(brew --prefix)"

# Remove QEMU binaries
rm -f "$BREW_PREFIX"/bin/qemu-system-*
rm -f "$BREW_PREFIX"/bin/qemu-img "$BREW_PREFIX"/bin/qemu-io "$BREW_PREFIX"/bin/qemu-edid
rm -f "$BREW_PREFIX"/bin/qemu-ga "$BREW_PREFIX"/bin/qemu-pr-helper

# Remove QEMU shared data
rm -rf "$BREW_PREFIX"/share/qemu

# Remove Glide libraries
rm -f "$BREW_PREFIX"/lib/*glide*

# Remove virglrenderer
rm -rf "$BREW_PREFIX/opt/virglrenderer-3dfx"

# Remove signing directory
rm -rf "$BREW_PREFIX"/sign
```

## Build source locations

Builds happen in `/tmp/` and are cleaned automatically. Source is retained until the next run or system restart.
