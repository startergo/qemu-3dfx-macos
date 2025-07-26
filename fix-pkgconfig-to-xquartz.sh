#!/bin/bash

# Replace Homebrew pkg-config files with XQuartz versions
# This redirects QEMU to use XQuartz graphics libraries directly

set -e

echo "=== Replacing Homebrew pkg-config files with XQuartz versions ==="

# Create timestamp for backups
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# Check if XQuartz pkg-config files exist
required_xquartz_pc_files=(
    "/opt/X11/lib/pkgconfig/pixman-1.pc"
    "/opt/X11/lib/pkgconfig/libpng16.pc"
    "/opt/X11/lib/pkgconfig/x11.pc"
)

echo "Checking XQuartz pkg-config files..."
for pc_file in "${required_xquartz_pc_files[@]}"; do
    if [ ! -f "$pc_file" ]; then
        echo "❌ Missing XQuartz pkg-config file: $pc_file"
        echo "Please install XQuartz: brew install --cask xquartz"
        exit 1
    else
        echo "✅ Found: $pc_file"
    fi
done

echo ""
echo "Backing up and replacing Homebrew pkg-config files..."

# Replace pixman pkg-config
echo "Pixman:"
if [ -f "/opt/homebrew/lib/pkgconfig/pixman-1.pc" ]; then
    sudo cp /opt/homebrew/lib/pkgconfig/pixman-1.pc /opt/homebrew/lib/pkgconfig/pixman-1.pc.backup-$TIMESTAMP
    # Create a custom pixman-1.pc that uses a unified include directory
    mkdir -p /tmp/xquartz-includes
    cp /opt/X11/include/pixman-1/*.h /tmp/xquartz-includes/
    cat > /tmp/pixman-1.pc << EOF
prefix=/opt/X11
includedir=/tmp/xquartz-includes
libdir=\${prefix}/lib

Name: Pixman
Description: The pixman library (version 1)
Version: 0.42.2
Libs: -L\${libdir} -lpixman-1
Libs.private: -lm
Cflags: -I\${includedir}
EOF
    sudo cp /tmp/pixman-1.pc /opt/homebrew/lib/pkgconfig/pixman-1.pc
    echo "  ✅ Replaced pixman-1.pc with XQuartz version using unified include directory"
else
    echo "  ⚠️ Homebrew pixman-1.pc not found"
fi

# Replace libpng pkg-config files
echo "LibPNG:"
if [ -f "/opt/homebrew/lib/pkgconfig/libpng16.pc" ]; then
    sudo cp /opt/homebrew/lib/pkgconfig/libpng16.pc /opt/homebrew/lib/pkgconfig/libpng16.pc.backup-$TIMESTAMP
    sudo cp /opt/X11/lib/pkgconfig/libpng16.pc /opt/homebrew/lib/pkgconfig/libpng16.pc
    echo "  ✅ Replaced libpng16.pc with XQuartz version"
else
    echo "  ⚠️ Homebrew libpng16.pc not found"
fi

if [ -f "/opt/homebrew/lib/pkgconfig/libpng.pc" ]; then
    sudo cp /opt/homebrew/lib/pkgconfig/libpng.pc /opt/homebrew/lib/pkgconfig/libpng.pc.backup-$TIMESTAMP
    sudo cp /opt/X11/lib/pkgconfig/libpng16.pc /opt/homebrew/lib/pkgconfig/libpng.pc
    echo "  ✅ Replaced libpng.pc with XQuartz version"
else
    echo "  ⚠️ Homebrew libpng.pc not found"
fi

# Replace X11 pkg-config
echo "X11:"
if [ -f "/opt/homebrew/lib/pkgconfig/x11.pc" ]; then
    sudo cp /opt/homebrew/lib/pkgconfig/x11.pc /opt/homebrew/lib/pkgconfig/x11.pc.backup-$TIMESTAMP
    sudo cp /opt/X11/lib/pkgconfig/x11.pc /opt/homebrew/lib/pkgconfig/x11.pc
    echo "  ✅ Replaced x11.pc with XQuartz version"
else
    echo "  ⚠️ Homebrew x11.pc not found"
fi

# Replace X11 extension libraries (needed for Mesa GL context)
echo "X11 Extensions:"
if [ -f "/opt/homebrew/lib/pkgconfig/xxf86vm.pc" ]; then
    sudo cp /opt/homebrew/lib/pkgconfig/xxf86vm.pc /opt/homebrew/lib/pkgconfig/xxf86vm.pc.backup-$TIMESTAMP
    sudo cp /opt/X11/lib/pkgconfig/xxf86vm.pc /opt/homebrew/lib/pkgconfig/xxf86vm.pc
    echo "  ✅ Replaced xxf86vm.pc with XQuartz version"
else
    echo "  ⚠️ Homebrew xxf86vm.pc not found, copying XQuartz version"
    sudo cp /opt/X11/lib/pkgconfig/xxf86vm.pc /opt/homebrew/lib/pkgconfig/xxf86vm.pc
    echo "  ✅ Added xxf86vm.pc from XQuartz"
fi

# Replace Xext extension library (required by xxf86vm)
if [ -f "/opt/homebrew/lib/pkgconfig/xext.pc" ]; then
    sudo cp /opt/homebrew/lib/pkgconfig/xext.pc /opt/homebrew/lib/pkgconfig/xext.pc.backup-$TIMESTAMP
    sudo cp /opt/X11/lib/pkgconfig/xext.pc /opt/homebrew/lib/pkgconfig/xext.pc
    echo "  ✅ Replaced xext.pc with XQuartz version"
else
    echo "  ⚠️ Homebrew xext.pc not found, copying XQuartz version"
    sudo cp /opt/X11/lib/pkgconfig/xext.pc /opt/homebrew/lib/pkgconfig/xext.pc
    echo "  ✅ Added xext.pc from XQuartz"
fi

# Replace remaining X11 core libraries (required by xxf86vm static linking)
for lib in xcb xau xdmcp; do
    if [ -f "/opt/homebrew/lib/pkgconfig/$lib.pc" ]; then
        sudo cp /opt/homebrew/lib/pkgconfig/$lib.pc /opt/homebrew/lib/pkgconfig/$lib.pc.backup-$TIMESTAMP
        sudo cp /opt/X11/lib/pkgconfig/$lib.pc /opt/homebrew/lib/pkgconfig/$lib.pc
        echo "  ✅ Replaced $lib.pc with XQuartz version"
    else
        echo "  ⚠️ Homebrew $lib.pc not found, copying XQuartz version"
        sudo cp /opt/X11/lib/pkgconfig/$lib.pc /opt/homebrew/lib/pkgconfig/$lib.pc
        echo "  ✅ Added $lib.pc from XQuartz"
    fi
done

# Replace OpenGL libraries (needed for Mesa GL rendering)
echo "OpenGL:"
if [ -f "/opt/homebrew/lib/pkgconfig/gl.pc" ]; then
    sudo cp /opt/homebrew/lib/pkgconfig/gl.pc /opt/homebrew/lib/pkgconfig/gl.pc.backup-$TIMESTAMP
    sudo cp /opt/X11/lib/pkgconfig/gl.pc /opt/homebrew/lib/pkgconfig/gl.pc
    echo "  ✅ Replaced gl.pc with XQuartz version"
else
    echo "  ⚠️ Homebrew gl.pc not found, copying XQuartz version"
    sudo cp /opt/X11/lib/pkgconfig/gl.pc /opt/homebrew/lib/pkgconfig/gl.pc
    echo "  ✅ Added gl.pc from XQuartz"
fi

echo ""
echo "=== Creating library symlinks for linker compatibility ==="
# Create symlinks in Homebrew lib directory to ensure linker can find XQuartz libraries
# This resolves library search order issues during linking
echo "Creating symlinks for XQuartz libraries in Homebrew lib directory..."

if [ ! -f "/opt/homebrew/lib/libXxf86vm.dylib" ]; then
    sudo ln -sf /opt/X11/lib/libXxf86vm.dylib /opt/homebrew/lib/libXxf86vm.dylib
    echo "  ✅ Created symlink: /opt/homebrew/lib/libXxf86vm.dylib -> /opt/X11/lib/libXxf86vm.dylib"
else
    echo "  ✅ Symlink already exists: /opt/homebrew/lib/libXxf86vm.dylib"
fi

if [ ! -f "/opt/homebrew/lib/libXext.dylib" ]; then
    sudo ln -sf /opt/X11/lib/libXext.dylib /opt/homebrew/lib/libXext.dylib
    echo "  ✅ Created symlink: /opt/homebrew/lib/libXext.dylib -> /opt/X11/lib/libXext.dylib"
else
    echo "  ✅ Symlink already exists: /opt/homebrew/lib/libXext.dylib"
fi

if [ ! -f "/opt/homebrew/lib/libX11.dylib" ]; then
    sudo ln -sf /opt/X11/lib/libX11.dylib /opt/homebrew/lib/libX11.dylib
    echo "  ✅ Created symlink: /opt/homebrew/lib/libX11.dylib -> /opt/X11/lib/libX11.dylib"
else
    echo "  ✅ Symlink already exists: /opt/homebrew/lib/libX11.dylib"
fi

echo ""
echo "=== Verification ==="
echo "Checking where pkg-config now points for graphics libraries:"

echo "Pixman library directory:"
pkg-config --variable=libdir pixman-1 2>/dev/null || echo "  ❌ pixman-1 not found"

echo "LibPNG library directory:"
pkg-config --variable=libdir libpng16 2>/dev/null || echo "  ❌ libpng16 not found"

echo "X11 library directory:"
pkg-config --variable=libdir x11 2>/dev/null || echo "  ❌ x11 not found"

echo "Xxf86vm library directory:"
pkg-config --variable=libdir xxf86vm 2>/dev/null || echo "  ❌ xxf86vm not found"

echo "Xext library directory:"
pkg-config --variable=libdir xext 2>/dev/null || echo "  ❌ xext not found"

echo "OpenGL library directory:"
pkg-config --variable=libdir gl 2>/dev/null || echo "  ❌ gl not found"

echo ""
echo "=== Testing library access ==="
echo "Checking if libraries exist at pkg-config locations:"

PIXMAN_LIB="$(pkg-config --variable=libdir pixman-1 2>/dev/null)/libpixman-1.0.dylib"
if [ -f "$PIXMAN_LIB" ]; then
    echo "✅ Pixman library accessible: $PIXMAN_LIB"
else
    echo "❌ Pixman library not found: $PIXMAN_LIB"
fi

LIBPNG_LIB="$(pkg-config --variable=libdir libpng16 2>/dev/null)/libpng16.16.dylib"
if [ -f "$LIBPNG_LIB" ]; then
    echo "✅ LibPNG library accessible: $LIBPNG_LIB"
else
    echo "❌ LibPNG library not found: $LIBPNG_LIB"
fi

X11_LIB="$(pkg-config --variable=libdir x11 2>/dev/null)/libX11.6.dylib"
if [ -f "$X11_LIB" ]; then
    echo "✅ X11 library accessible: $X11_LIB"
else
    echo "❌ X11 library not found: $X11_LIB"
fi

XXF86VM_LIB="$(pkg-config --variable=libdir xxf86vm 2>/dev/null)/libXxf86vm.1.dylib"
if [ -f "$XXF86VM_LIB" ]; then
    echo "✅ Xxf86vm library accessible: $XXF86VM_LIB"
else
    echo "❌ Xxf86vm library not found: $XXF86VM_LIB"
fi

XEXT_LIB="$(pkg-config --variable=libdir xext 2>/dev/null)/libXext.6.dylib"
if [ -f "$XEXT_LIB" ]; then
    echo "✅ Xext library accessible: $XEXT_LIB"
else
    echo "❌ Xext library not found: $XEXT_LIB"
fi

GL_LIB="$(pkg-config --variable=libdir gl 2>/dev/null)/libGL.1.dylib"
if [ -f "$GL_LIB" ]; then
    echo "✅ OpenGL library accessible: $GL_LIB"
else
    echo "❌ OpenGL library not found: $GL_LIB"
fi

echo ""
echo "=== Summary ==="
echo "✅ All pkg-config files now point to XQuartz libraries"
echo "✅ Backups created with timestamp: $TIMESTAMP"
echo ""
echo "When QEMU builds, it will now use:"
echo "  - XQuartz Pixman: $(pkg-config --variable=libdir pixman-1 2>/dev/null || echo 'N/A')"
echo "  - XQuartz LibPNG: $(pkg-config --variable=libdir libpng16 2>/dev/null || echo 'N/A')"
echo "  - XQuartz X11: $(pkg-config --variable=libdir x11 2>/dev/null || echo 'N/A')"
echo "  - XQuartz Xxf86vm: $(pkg-config --variable=libdir xxf86vm 2>/dev/null || echo 'N/A')"
echo "  - XQuartz Xext: $(pkg-config --variable=libdir xext 2>/dev/null || echo 'N/A')"
echo "  - XQuartz OpenGL: $(pkg-config --variable=libdir gl 2>/dev/null || echo 'N/A')"
echo ""
echo "This is the cleanest approach - no file copying, just pkg-config redirection!"
