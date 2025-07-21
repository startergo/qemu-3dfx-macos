class Qemu3dfxLocal < Formula
  desc "QEMU with 3dfx Voodoo and Virgl3D OpenGL acceleration support (local test)"
  homepage "https://github.com/startergo/qemu-3dfx-macos"
  url "file:///Users/macbookpro/myqemu/qemu-3dfx/qemu-9.2.2.tar.xz"
  version "9.2.2-3dfx"
  sha256 "752eaeeb772923a73d536b231e05bcc09c9b1f51690a41ad9973d900e4ec9fbf"
  license "GPL-2.0-or-later"
  revision 1

  # Build dependencies
  depends_on "cmake" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "python@3.12" => :build

  # Runtime dependencies
  depends_on "gettext"
  depends_on "glib"
  depends_on "libepoxy"
  depends_on "libffi"
  depends_on "mt32emu"
  depends_on "pixman"
  depends_on "sdl12-compat"
  depends_on "sdl2"
  depends_on "sdl2_image"
  depends_on "sdl2_net"
  depends_on "sdl2_sound"

  # Virglrenderer resource
  resource "virglrenderer" do
    url "https://gitlab.freedesktop.org/virgl/virglrenderer.git",
        revision: "main"
  end

  def install
    # Set up build environment
    ENV["PKG_CONFIG_PATH"] = "#{HOMEBREW_PREFIX}/lib/pkgconfig"

    # Add libepoxy path specifically
    epoxy_path = Dir["#{HOMEBREW_PREFIX}/Cellar/libepoxy/*/lib/pkgconfig"].first
    ENV["PKG_CONFIG_PATH"] = "#{epoxy_path}:#{ENV["PKG_CONFIG_PATH"]}" if epoxy_path

    # Build virglrenderer first with macOS patches
    resource("virglrenderer").stage do
      # Apply macOS compatibility patches to virglrenderer
      bundle_dir = "#{__dir__}"
      macos_virgl_patch = "#{bundle_dir}/patches/0001-Virglrenderer-on-Windows-and-macOS-fixed.patch"
      if File.exist?(macos_virgl_patch)
        ohai "Applying virglrenderer macOS patch"
        system "git", "apply", macos_virgl_patch
      end

      mkdir "build" do
        system "meson", "setup", ".",
               "--prefix=#{prefix}",
               "--buildtype=release",
               "-Dtests=false",
               "-Dplatforms=",
               "-Dminigbm_allocation=false",
               "-Dvenus=false"
        system "ninja"
        system "ninja", "install"
      end
    end

    # Update PKG_CONFIG_PATH to include our virglrenderer
    ENV["PKG_CONFIG_PATH"] = "#{prefix}/lib/pkgconfig:#{ENV["PKG_CONFIG_PATH"]}"

    # Apply patches
    apply_3dfx_patches

    # Configure QEMU
    mkdir "build" do
      system "../configure",
             "--prefix=#{prefix}",
             "--target-list=i386-softmmu,x86_64-softmmu,aarch64-softmmu",
             "--enable-sdl",
             "--enable-opengl",
             "--disable-cocoa",
             "--enable-virglrenderer",
             "--disable-gtk",
             "--disable-dbus-display",
             "--disable-curses",
             "--enable-vnc"

      system "ninja"
      system "ninja", "install"
    end

    # Create version info
    (prefix/"VERSION").write("#{version}-#{revision}")
  end

  def apply_3dfx_patches
    bundle_dir = "#{__dir__}"
    
    # Apply KJ's Mesa/Glide patches
    patch_file = "#{bundle_dir}/patches/00-qemu92x-mesa-glide.patch"
    if File.exist?(patch_file)
      ohai "Applying QEMU 3dfx patch"
      system "git", "apply", patch_file
    end

    # Apply Virgl3D patches for QEMU
    ["0001-Virgil3D-with-SDL2-OpenGL.patch", "0002-Virgil3D-macOS-GLSL-version.patch"].each do |patch_name|
      patch_file = "#{bundle_dir}/patches/#{patch_name}"
      if File.exist?(patch_file)
        ohai "Applying QEMU Virgl3D patch: #{patch_name}"
        system "git", "apply", patch_file
      end
    end

    # Apply critical EGL fix for macOS
    if File.exist?("meson.build")
      ohai "Applying EGL compatibility fix for macOS"
      inreplace "meson.build",
                "error('epoxy/egl.h not found')",
                "warning('epoxy/egl.h not found - EGL disabled')"
    end

    # Copy 3dfx and mesa source files
    source_3dfx = "#{bundle_dir}/source/3dfx"
    source_mesa = "#{bundle_dir}/source/mesa"

    if Dir.exist?(source_3dfx)
      ohai "Installing 3dfx sources"
      mkdir_p "hw/3dfx"
      cp_r "#{source_3dfx}/.", "hw/3dfx/"
    end

    if Dir.exist?(source_mesa)
      ohai "Installing mesa sources"
      mkdir_p "hw/mesa"
      cp_r "#{source_mesa}/.", "hw/mesa/"
    end

    # Apply GL_CONTEXTALPHA fix
    if File.exist?("hw/mesa/mglcntx_linux.c")
      ohai "Applying GL_CONTEXTALPHA fix"
      inreplace "hw/mesa/mglcntx_linux.c", "GL_CONTEXTALPHA", "GLX_ALPHA_SIZE"
    end

    # Sign commit if script exists
    sign_script = "#{bundle_dir}/sign_commit"
    if File.exist?(sign_script)
      ohai "Signing commit"
      system "bash", sign_script
    end
  end

  test do
    # Test version
    system "#{bin}/qemu-system-x86_64", "--version"

    # Test 3dfx device support
    output = shell_output("#{bin}/qemu-system-i386 -device help")
    assert_match "3dfx", output, "3dfx device support not found"

    # Test Virgl support
    output = shell_output("#{bin}/qemu-system-x86_64 -device help")
    assert_match "virtio-vga-gl", output, "Virgl3D support not found"
  end
end
