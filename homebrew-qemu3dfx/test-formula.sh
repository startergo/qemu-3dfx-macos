#!/bin/bash

# Test script for QEMU 3dfx Homebrew formula
# This script builds the formula from source and runs debugging tests
# Patch stack replicated from qemu-3dfx-arch/.github/workflows/build.yaml

set -e  # Exit on any error

echo "=== QEMU 3dfx Formula Test and Debug Script ==="
echo "Starting at: $(date)"
echo

# ── Version configuration (must match build.yaml) ──────────────────────
QEMU_VERSION="11.0.0"
QEMU_REF="v${QEMU_VERSION}"
PRIMARY_PATCH="00-qemu110x-mesa-glide.patch"

# ── Set up environment ─────────────────────────────────────────────────
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMULA_DIR="$SCRIPT_DIR"
FORMULA_FILE="$FORMULA_DIR/Formula/qemu-3dfx.rb"

echo "Formula directory: $FORMULA_DIR"
echo "Formula file: $FORMULA_FILE"
echo

if [ ! -f "$FORMULA_FILE" ]; then
    echo "ERROR: Formula file not found at $FORMULA_FILE"
    exit 1
fi

# ── Locate submodule repository root ───────────────────────────────────
# The qemu-3dfx-arch submodule contains the patches and scripts
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARCH_SUBMODULE="$REPO_ROOT/qemu-3dfx-arch"

if [ ! -d "$ARCH_SUBMODULE" ]; then
    echo "ERROR: qemu-3dfx-arch submodule not found at $ARCH_SUBMODULE"
    echo "Run: git submodule update --init --remote"
    exit 1
fi

echo "Repository root: $REPO_ROOT"
echo "qemu-3dfx-arch submodule: $ARCH_SUBMODULE"
echo

# ── Step 1: Validate Formula Syntax ────────────────────────────────────
echo "=== Step 1: Validating Formula Syntax ==="
cd "$FORMULA_DIR"
echo "Skipping brew audit (requires tap) - will validate during install"
echo

# ── Step 2: Install Dependencies ───────────────────────────────────────
echo "=== Step 2: Installing Dependencies ==="

echo "Installing Xcode command line tools..."
xcode-select --install 2>/dev/null || true

echo "Installing build tools and dependencies..."

# Install ANGLE (provides libEGL.dylib, libGLESv2.dylib for macOS via Metal)
brew tap startergo/gn
brew tap startergo/angle
brew install startergo/angle/angle

# Install patched libepoxy with EGL 1.5 support on macOS
brew tap startergo/libepoxy
brew install startergo/libepoxy/libepoxy

brew install git wget meson ninja pkg-config \
    capstone glib gettext gnutls libgcrypt libslirp libusb jpeg-turbo \
    lz4 opus sdl2 zstd swtpm libffi ncurses pixman sdl2_image \
    spice-protocol spice-server libx11 libxext libxfixes libxrandr \
    libxinerama libxi libxcursor libxxf86vm \
    autoconf automake libtool cmake

# Install mesa first and force-link (conflicts with angle EGL and xorgproto GL headers)
brew install mesa || true
brew link --overwrite mesa || true

# Install mesa-glu for GL/glu.h (needed by OpenGLide)
brew install mesa-glu || true
brew link --overwrite mesa-glu || true

echo "Dependencies installed"
echo

# ── Step 2.5: Setup Build Environment ──────────────────────────────────
echo "=== Step 2.5: Setup Build Environment ==="

export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/opt/homebrew/opt/angle/lib/pkgconfig"
echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"

# Verify OpenGL framework
echo "Verifying OpenGL framework availability:"
if [ -d "/System/Library/Frameworks/OpenGL.framework" ]; then
    echo "  macOS OpenGL framework found"
    if echo '#include <OpenGL/OpenGL.h>
int main() { return 0; }' | clang -x c - -framework OpenGL -o /tmp/gl_test 2>/dev/null; then
        echo "  OpenGL framework linkable"
        rm -f /tmp/gl_test
    else
        echo "  WARNING: OpenGL framework found but not linkable"
    fi
else
    echo "  WARNING: macOS OpenGL framework missing"
fi

# Check epoxy
if pkg-config --exists epoxy; then
    echo "  libepoxy pkg-config available"
else
    echo "  WARNING: libepoxy pkg-config missing"
fi

echo "Build environment setup complete"
echo

# ── Step 3: Build virglrenderer (replicating build.yaml PKGBUILD) ──────
echo "=== Step 3: Building virglrenderer (replicating MINGW-packages/PKGBUILD) ==="

VIRGL_VERSION="1.3.0"
VIRGL_BUILD_DIR="/tmp/virglrenderer-build"
VIRGL_PREFIX="$(brew --prefix)/opt/virglrenderer-3dfx"

echo "Virglrenderer version: $VIRGL_VERSION"
echo "Build directory: $VIRGL_BUILD_DIR"
echo "Install prefix: $VIRGL_PREFIX"

# Clean any previous build
rm -rf "$VIRGL_BUILD_DIR"
mkdir -p "$VIRGL_BUILD_DIR"
cd "$VIRGL_BUILD_DIR"

# Download virglrenderer source (matching PKGBUILD source)
echo "Downloading virglrenderer ${VIRGL_VERSION}..."
curl -L -o "virglrenderer-${VIRGL_VERSION}.tar.bz2" \
    "https://gitlab.freedesktop.org/virgl/virglrenderer/-/archive/${VIRGL_VERSION}/virglrenderer-${VIRGL_VERSION}.tar.bz2"

# Extract
echo "Extracting virglrenderer..."
tar -xjf "virglrenderer-${VIRGL_VERSION}.tar.bz2"
cd "virglrenderer-${VIRGL_VERSION}"

# Replicate PKGBUILD prepare() — apply all 8 patches from virgil3d/MINGW-packages/
echo "Applying virglrenderer patches (replicating PKGBUILD prepare())..."

VIRGL_PATCHES_DIR="$ARCH_SUBMODULE/virgil3d/MINGW-packages"

if [ ! -d "$VIRGL_PATCHES_DIR" ]; then
    echo "ERROR: Virglrenderer patches not found at $VIRGL_PATCHES_DIR"
    exit 1
fi

# macOS-specific sed fixes (adapted from PKGBUILD MSYS fixes)
# PKGBUILD: sed "s/\(error=switch\)/\1','\-Wno\-unknown\-attributes','\-Wno\-unused-parameter/" -i meson.build
echo "  Adjusting meson.build compiler flags for macOS..."
sed -i '' "s/\(error=switch\)/\1','-Wno-unknown-attributes','-Wno-unused-parameter/" meson.build

# PKGBUILD: sed "s/\(fvisibility=hidden\)/\1','\-mno\-ms\-bitfields/" -i meson.build
# (mno-ms-bitfields is MSYS-specific, skip on macOS)

# PKGBUILD: sed "s/\(strstr.*Quadro.*\ NULL\)/1\ ||\ \1/" -i src/vrend/vrend_renderer.c
echo "  Patching vrend_renderer.c for non-Quadro GPUs..."
sed -i '' "s/\(strstr.*Quadro.*\ NULL\)/1 || \1/" src/vrend/vrend_renderer.c

# Initialize git for patch application
git init
git add -A
git commit -m "virglrenderer ${VIRGL_VERSION} source" --quiet

# Apply patch 0001 — main Windows/macOS compatibility (p2 as in PKGBUILD)
echo "  Applying 0001-Virglrenderer-on-Windows-and-macOS.patch (p2)..."
patch -p2 -i "$VIRGL_PATCHES_DIR/0001-Virglrenderer-on-Windows-and-macOS.patch"

# Apply patches 0002-0008 (p1 as in PKGBUILD)
for patch_num in 0002 0003 0004 0005 0006 0007 0008; do
    patch_file="$VIRGL_PATCHES_DIR/${patch_num}-"*.patch
    patch_file=$(ls $patch_file 2>/dev/null | head -1)
    if [ -n "$patch_file" ] && [ -f "$patch_file" ]; then
        echo "  Applying $(basename "$patch_file") (p1)..."
        patch -p1 -i "$patch_file"
    else
        echo "  WARNING: Patch ${patch_num} not found in $VIRGL_PATCHES_DIR"
    fi
done

echo "Virglrenderer patches applied successfully"

# Build virglrenderer with meson (replicating PKGBUILD build())
echo "Building virglrenderer..."

# Install PyYAML if needed (PKGBUILD uses a venv)
python3 -m pip install --break-system-packages PyYAML 2>/dev/null || true

# Ensure Homebrew meson/ninja are in PATH
export PATH="$(brew --prefix)/bin:$PATH"

# ANGLE and libepoxy paths for EGL support
ANGLE_INCLUDE="$(brew --prefix)/opt/angle/include"
COMBINED_PC_PATH="$(brew --prefix)/opt/angle/lib/pkgconfig:$(brew --prefix)/opt/libepoxy/lib/pkgconfig:${PKG_CONFIG_PATH}"

mkdir -p build
cd build
"$(brew --prefix)/bin/meson" setup .. \
    --prefix="$VIRGL_PREFIX" \
    --buildtype=release \
    -Dc_args="-I${ANGLE_INCLUDE}" \
    -Dcpp_args="-I${ANGLE_INCLUDE}" \
    --pkg-config-path="$COMBINED_PC_PATH" \
    -Dtests=false \
    -Dplatforms= \
    -Dminigbm_allocation=false \
    -Dvenus=false

"$(brew --prefix)/bin/ninja" -j$(sysctl -n hw.ncpu)
"$(brew --prefix)/bin/ninja" install

# Update PKG_CONFIG_PATH to include our custom virglrenderer
export PKG_CONFIG_PATH="$VIRGL_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
echo "virglrenderer installed. PKG_CONFIG_PATH updated."
echo

# ── Step 4: Download and patch QEMU (replicating build.yaml) ───────────
echo "=== Step 4: Downloading and Patching QEMU (replicating build.yaml) ==="

QEMU_SRC_DIR="/tmp/qemu-${QEMU_VERSION}-3dfx"

# Clean any previous build
rm -rf "$QEMU_SRC_DIR"
mkdir -p "$QEMU_SRC_DIR"

echo "Cloning QEMU source (ref: ${QEMU_REF})..."
git clone --depth 1 --branch "$QEMU_REF" https://github.com/qemu/qemu.git "$QEMU_SRC_DIR/qemu-src"
cd "$QEMU_SRC_DIR/qemu-src"
echo "Fetched QEMU tag: $(git describe --tags)"
echo

# ── Apply patches using apply_qemu_patches.sh directly ──────────────────
echo "Applying qemu-3dfx patch stack via apply_qemu_patches.sh..."

cd "$ARCH_SUBMODULE"
PATCH_ARGS=(
    --src-dir "$QEMU_SRC_DIR/qemu-src"
    --primary-patch "$ARCH_SUBMODULE/$PRIMARY_PATCH"
)
case "$(echo "${QEMU_3DFX_EXPERIMENTAL_PATCHES}" | tr '[:upper:]' '[:lower:]')" in
    true|1|yes|on)
        PATCH_ARGS+=(--with-qemu-exp)
        echo "✅ Experimental patches ENABLED"
        ;;
    *)
        echo "ℹ️  Experimental patches DISABLED"
        ;;
esac
bash scripts/apply_qemu_patches.sh "${PATCH_ARGS[@]}"

echo "All patches applied!"

# macOS fixes after patching
cd "$QEMU_SRC_DIR/qemu-src"

# Fix macOS OpenGL context attribute name
sed -i '' 's/GL_CONTEXTALPHA/GLX_ALPHA_SIZE/' hw/mesa/mglcntx_linux.c 2>/dev/null || true

# ANGLE defines EGLNativeDisplayType as int on macOS, but eglGetPlatformDisplayEXT expects void*
sed -i '' 's/eglGetPlatformDisplayEXT(platform, native, NULL)/eglGetPlatformDisplayEXT(platform, (void *)(intptr_t)native, NULL)/' ui/egl-helpers.c

echo

# ── Step 5: Configure and build QEMU ───────────────────────────────────
echo "=== Step 5: Configuring and Building QEMU ==="

# macOS-specific build adjustments
# Remove -flto=auto from flags (as in build.yaml configure step)
export CFLAGS="${CFLAGS//-flto=auto/}"
export CXXFLAGS="${CXXFLAGS//-flto=auto/}"
export LDFLAGS="${LDFLAGS//-flto=auto/}"

# Ensure Homebrew lib path for X11/GL/Xxf86vm (needed when XQuartz is absent)
export LDFLAGS="$LDFLAGS -L/opt/homebrew/lib -L/opt/homebrew/opt/mesa/lib"

# Apple framework linker flags for SDL2
APPLE_FRAMEWORKS="-framework AudioToolbox -framework CoreAudio -framework CoreGraphics -framework CoreFoundation -framework AppKit -framework IOKit -framework ForceFeedback -framework GameController -framework Carbon -framework Cocoa -framework CoreHaptics -framework CoreVideo -framework Metal -framework MetalKit -framework OpenGL"
export LDFLAGS="$LDFLAGS $APPLE_FRAMEWORKS"
export LIBS="$LIBS $APPLE_FRAMEWORKS"

# Create separate build directory (matching build.yaml: working-directory: ./build)
QEMU_BUILD_DIR="$QEMU_SRC_DIR/build"
mkdir -p "$QEMU_BUILD_DIR"
cd "$QEMU_BUILD_DIR"

echo "Configuring QEMU..."
# Adapted from build.yaml configure — macOS equivalents of Windows flags
../qemu-src/configure \
    --target-list="x86_64-softmmu,i386-softmmu,aarch64-softmmu" \
    --disable-werror \
    --disable-stack-protector \
    --disable-rust \
    --enable-virglrenderer \
    --enable-opengl \
    --enable-sdl \
    --enable-spice \
    --enable-curses \
    --enable-tpm \
    --disable-gtk \
    --disable-dbus-display \
    --disable-docs \
    --disable-cocoa \
    -Dsdl_clipboard=enabled \
    --prefix="$QEMU_SRC_DIR/install_dir"

echo "Compiling QEMU..."
ninja -j$(sysctl -n hw.ncpu)

echo "Installing QEMU..."
ninja install

echo "QEMU build complete!"
echo

# ── Step 5.5: Build Glide libraries from OpenGLide ─────────────────────
echo "=== Step 5.5: Building Glide Libraries (OpenGLide) ==="

GLIDE_SRC_DIR="/tmp/openglide-build"
GLIDE_INSTALL_PREFIX="$QEMU_SRC_DIR/install_dir"

rm -rf "$GLIDE_SRC_DIR"
mkdir -p "$GLIDE_SRC_DIR"

echo "Downloading OpenGLide from qemu-xtra..."
curl -L -o "$GLIDE_SRC_DIR/qemu-xtra.tar.gz" \
    "https://github.com/startergo/qemu-xtra/archive/e1e9399f7551fc9d1f8f40d66ff89f94579ce2d1.tar.gz"

cd "$GLIDE_SRC_DIR"
tar -xzf qemu-xtra.tar.gz
cd qemu-xtra-*/openglide

echo "Bootstrapping OpenGLide..."
chmod +x bootstrap
./bootstrap

# Set up GL headers from Homebrew mesa and mesa-glu
INCLUDE_DIR="$GLIDE_SRC_DIR/include"
mkdir -p "$INCLUDE_DIR/GL" "$INCLUDE_DIR/KHR"

BREW_PREFIX="$(brew --prefix)"

# Symlink GL headers from Homebrew mesa
MESA_GL_INCLUDE="${BREW_PREFIX}/include/GL"
MESA_KHR_INCLUDE="${BREW_PREFIX}/include/KHR"
if [ -d "$MESA_GL_INCLUDE" ]; then
    for header in "$MESA_GL_INCLUDE"/*.h; do
        ln -sf "$header" "$INCLUDE_DIR/GL/$(basename "$header")"
    done
fi
if [ -d "$MESA_KHR_INCLUDE" ]; then
    for header in "$MESA_KHR_INCLUDE"/*.h; do
        ln -sf "$header" "$INCLUDE_DIR/KHR/$(basename "$header")"
    done
fi

# Symlink GL/glu.h from mesa-glu (may not be linked into HOMEBREW_PREFIX/include)
MESA_GLU_GL="${BREW_PREFIX}/opt/mesa-glu/include/GL"
if [ -d "$MESA_GLU_GL" ]; then
    for header in "$MESA_GLU_GL"/*.h; do
        ln -sf "$header" "$INCLUDE_DIR/GL/$(basename "$header")"
    done
fi

echo "Configuring OpenGLide..."
./configure --disable-sdl \
    --prefix="$GLIDE_INSTALL_PREFIX" \
    "CPPFLAGS=-I$INCLUDE_DIR -I${BREW_PREFIX}/include -I${BREW_PREFIX}/opt/mesa/include -I${BREW_PREFIX}/opt/mesa-glu/include" \
    "CFLAGS=-I$INCLUDE_DIR -I${BREW_PREFIX}/include -I${BREW_PREFIX}/opt/mesa/include -I${BREW_PREFIX}/opt/mesa-glu/include" \
    "CXXFLAGS=-I$INCLUDE_DIR -I${BREW_PREFIX}/include -I${BREW_PREFIX}/opt/mesa/include -I${BREW_PREFIX}/opt/mesa-glu/include" \
    "LDFLAGS=-L${BREW_PREFIX}/lib" \
    "LIBS=-lX11"

echo "Building OpenGLide..."
make

echo "Installing Glide libraries..."
make install

echo "Verifying Glide libraries:"
ls -la "$GLIDE_INSTALL_PREFIX/lib/"*glide* 2>/dev/null || echo "  WARNING: No Glide libraries found"
echo

# ── Step 6: Verification ───────────────────────────────────────────────
echo "=== Step 6: Verification ==="

INSTALL_DIR="$QEMU_SRC_DIR/install_dir"
HOST_ARCH=$(uname -m)

if [ "$HOST_ARCH" = "arm64" ] || [ "$HOST_ARCH" = "aarch64" ]; then
    QEMU_TEST_BIN="$INSTALL_DIR/bin/qemu-system-x86_64"
    QEMU_NATIVE_BIN="$INSTALL_DIR/bin/qemu-system-aarch64"
else
    QEMU_TEST_BIN="$INSTALL_DIR/bin/qemu-system-x86_64"
    QEMU_NATIVE_BIN="$INSTALL_DIR/bin/qemu-system-x86_64"
fi

echo "Host architecture: $HOST_ARCH"

echo
echo "Testing x86_64 version output:"
"$QEMU_TEST_BIN" --version

echo
echo "Checking for 3dfx signature:"
if "$QEMU_TEST_BIN" --version | grep -q "qemu-3dfx"; then
    echo "  3dfx signature found in x86_64 binary"
else
    echo "  3dfx signature NOT found in x86_64 binary"
fi

echo
echo "Checking for SDL clipboard support (experimental patch):"
if strings "$QEMU_TEST_BIN" | grep -q "sdl2-clipboard"; then
    echo "  SDL clipboard support found (experimental patch applied)"
else
    echo "  SDL clipboard support NOT found"
fi

echo
echo "Checking Virgl3D device support:"
"$QEMU_TEST_BIN" -device help | grep -E "virtio-vga|virtio-gpu|3dfx" || echo "  No specialized devices found"

echo
echo "Testing display support:"
"$QEMU_TEST_BIN" -display help

echo
echo "Installed binaries:"
ls -la "$INSTALL_DIR/bin/"

echo
echo "=== Build and Test Complete ==="
echo "Finished at: $(date)"
echo
echo "Install directory: $INSTALL_DIR"
echo "Virglrenderer: $VIRGL_PREFIX"
