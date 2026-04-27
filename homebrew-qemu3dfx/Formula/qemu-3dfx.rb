class Qemu3dfx < Formula
  desc "QEMU with 3dfx Voodoo and Virgl3D OpenGL acceleration support"
  homepage "https://github.com/startergo/qemu-3dfx-macos"
  url "https://download.qemu.org/qemu-11.0.0.tar.xz"
  version "11.0.0-3dfx"
  sha256 "c04ca36012653f32d11c674d370cf52a710e7d3f18c2d8b63e4932052a4854d6"
  license "GPL-2.0-or-later"
  revision 1

  head "https://github.com/startergo/qemu-3dfx-macos.git", branch: "master"

  # Build dependencies
  depends_on "cmake" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "python@3.14" => :build
  depends_on "autoconf" => :build      # Required for OpenGLide bootstrap
  depends_on "automake" => :build      # Required for OpenGLide bootstrap
  depends_on "libtool" => :build       # Required for OpenGLide

  # Runtime dependencies
  depends_on "capstone"
  depends_on "glib"
  depends_on "gettext"
  depends_on "gnutls"
  depends_on "libgcrypt"
  depends_on "libslirp"
  depends_on "libusb"
  depends_on "jpeg-turbo"
  depends_on "lz4"
  depends_on "opus"
  depends_on "sdl2"
  depends_on "zstd"
  depends_on "swtpm"
  depends_on "libffi"
  depends_on "ncurses"
  depends_on "pixman"
  depends_on "sdl2_image"

  # SPICE protocol support
  depends_on "spice-protocol"
  depends_on "spice-server"

  # macOS EGL/OpenGL via ANGLE (Metal backend) + patched libepoxy (EGL 1.5)
  depends_on "startergo/angle/angle"
  depends_on "startergo/libepoxy/libepoxy"

  # GL headers (provides GL/glcorearb.h, GL/glx.h without XQuartz)
  depends_on "mesa"

  # GLU headers (provides GL/glu.h for OpenGLide build)
  depends_on "mesa-glu"

  # X11 libraries (for GL/X11 compilation)
  depends_on "libx11"
  depends_on "libxext"
  depends_on "libxfixes"
  depends_on "libxrandr"
  depends_on "libxinerama"
  depends_on "libxi"
  depends_on "libxcursor"
  depends_on "libxxf86vm"

  # Virglrenderer resource (built with all 6 MINGW-packages patches)
  resource "virglrenderer" do
    url "https://gitlab.freedesktop.org/virgl/virglrenderer/-/archive/1.3.0/virglrenderer-1.3.0.tar.bz2"
    sha256 "a3486ff05c01d6a091176128d569138b01a36f173d56fd3195f1f24e4551be87"
  end

  # OpenGLide resource for building host-side Glide libraries
  resource "openglide" do
    url "https://github.com/startergo/qemu-xtra/archive/e1e9399f7551fc9d1f8f40d66ff89f94579ce2d1.tar.gz"
    sha256 "85cf72ae9516c1d105fb2016bc55b56723ee9525a87bb0e994f88131d7e403c7"
  end

  def install
    # ── Build environment ──────────────────────────────────────────────────
    ENV["PKG_CONFIG_PATH"] = [
      "#{HOMEBREW_PREFIX}/opt/angle/lib/pkgconfig",
      "#{HOMEBREW_PREFIX}/lib/pkgconfig",
      "#{HOMEBREW_PREFIX}/share/pkgconfig",
    ].join(":")

    ENV.append "LDFLAGS", "-L#{HOMEBREW_PREFIX}/lib -L#{HOMEBREW_PREFIX}/opt/mesa/lib"

    # ── Build virglrenderer with all 6 MINGW-packages patches ─────────────
    build_virglrenderer

    # Add virglrenderer to PKG_CONFIG_PATH
    ENV.prepend "PKG_CONFIG_PATH", "#{prefix}/lib/pkgconfig"

    # ── Apply patches via apply_qemu_patches.sh ───────────────────────────
    apply_qemu_3dfx_patches

    # ── Configure and build QEMU ──────────────────────────────────────────
    apple_frameworks = %w[
      AudioToolbox CoreAudio CoreGraphics CoreFoundation
      AppKit IOKit ForceFeedback GameController Carbon
      Cocoa CoreHaptics CoreVideo Metal MetalKit OpenGL
    ].map { |f| "-framework #{f}" }.join(" ")

    ENV.append "LDFLAGS", apple_frameworks
    ENV.append "LIBS", apple_frameworks

    mkdir "build" do
      system "../configure",
        "--prefix=#{prefix}",
        "--target-list=i386-softmmu,x86_64-softmmu,aarch64-softmmu",
        "--disable-werror",
        "--disable-stack-protector",
        "--disable-rust",
        "--enable-sdl",
        "--enable-opengl",
        "--enable-virglrenderer",
        "--enable-spice",
        "--enable-curses",
        "--enable-tpm",
        "--disable-gtk",
        "--disable-dbus-display",
        "--disable-cocoa",
        "--disable-docs",
        "-Dsdl_clipboard=enabled"

      if ENV["CI"] || ENV["GITHUB_ACTIONS"]
        system "ninja", "-j2"
      else
        system "ninja"
      end
      system "ninja", "install"
    end

    # Build Glide shared libraries from OpenGLide
    build_glide_libraries

    # Copy 3dfx wrapper sources and signing files
    copy_3dfx_wrapper_sources
    copy_signing_files

    (prefix/"VERSION").write("#{version}-#{revision}")
  end

  def post_install
    sign_dir = "#{prefix}/sign"
    sign_script = "#{sign_dir}/qemu.sign"
    return unless File.exist?(sign_script)

    chmod 0755, sign_script
    ohai "Post-install: Signing binaries"

    Dir.chdir(sign_dir) do
      system "bash", "qemu.sign"
    end
  end

  # ── Virglrenderer build (replicates CI build with all 6 patches) ────────

  def build_virglrenderer
    resource("virglrenderer").stage do
      repo_root = find_repo_root(__dir__)
      odie "Repository root not found" unless repo_root

      patches_dir = "#{repo_root}/qemu-3dfx-arch/virgil3d/MINGW-packages"
      unless Dir.exist?(patches_dir)
        # Fallback: try without submodule prefix
        patches_dir = "#{repo_root}/virgil3d/MINGW-packages"
      end
      unless Dir.exist?(patches_dir)
        odie "Virglrenderer MINGW-packages patches not found at #{patches_dir}"
      end

      python_bin = Formula["python@3.14"].opt_bin/"python3.14"
      unless quiet_system python_bin, "-c", "import yaml"
        system python_bin, "-m", "pip", "install", "--break-system-packages", "PyYAML"
      end
      ENV["PYTHON"] = python_bin
      ENV.prepend_path "PATH", Formula["python@3.14"].opt_bin

      # macOS compiler flag fixes (adapted from PKGBUILD)
      inreplace "meson.build",
        /error=switch/,
        "error=switch','-Wno-unknown-attributes','-Wno-unused-parameter"

      # Patch vrend_renderer.c for non-Quadro GPUs
      inreplace "src/vrend/vrend_renderer.c",
        /strstr.*Quadro.*NULL/,
        '1 || \0'

      # Init git for patch application
      system "git", "init"
      system "git", "add", "."
      system "git", "commit", "-m", "virglrenderer 1.3.0 source", "--quiet"

      # Apply 0001 at p2 (matching PKGBUILD)
      patch_0001 = Dir["#{patches_dir}/0001-*.patch"].first
      if patch_0001
        ohai "Applying #{File.basename(patch_0001)} (p2)"
        system "patch", "-p2", "-i", patch_0001
      end

      # Apply 0002-0008 at p1 (matching PKGBUILD)
      Dir["#{patches_dir}/000[2-8]-*.patch"].sort.each do |patch_file|
        ohai "Applying #{File.basename(patch_file)} (p1)"
        system "patch", "-p1", "-i", patch_file
      end

      # ANGLE and libepoxy paths for EGL support
      angle = Formula["startergo/angle/angle"]
      libepoxy = Formula["startergo/libepoxy/libepoxy"]
      angle_include = angle.include.to_s
      combined_pc_path = [
        "#{angle.lib}/pkgconfig",
        "#{libepoxy.lib}/pkgconfig",
        ENV["PKG_CONFIG_PATH"],
      ].compact.join(":")

      mkdir "build" do
        system "meson", "setup", "..",
          "--prefix=#{prefix}",
          "--buildtype=release",
          "-Dc_args=-I#{angle_include}",
          "-Dcpp_args=-I#{angle_include}",
          "--pkg-config-path=#{combined_pc_path}",
          "-Dtests=false",
          "-Dplatforms=",
          "-Dminigbm_allocation=false",
          "-Dvenus=false"

        system "ninja"
        system "ninja", "install"
      end
    end
  end

  # ── Apply patches via apply_qemu_patches.sh ─────────────────────────────

  def apply_qemu_3dfx_patches
    repo_root = find_repo_root(__dir__)
    odie "Repository root not found" unless repo_root

    # Locate apply_qemu_patches.sh (in submodule)
    apply_script = "#{repo_root}/qemu-3dfx-arch/scripts/apply_qemu_patches.sh"
    unless File.exist?(apply_script)
      apply_script = "#{repo_root}/scripts/apply_qemu_patches.sh"
    end
    unless File.exist?(apply_script)
      odie "apply_qemu_patches.sh not found"
    end

    # Primary patch (QEMU 11.0.x)
    primary_patch = "#{repo_root}/qemu-3dfx-arch/00-qemu110x-mesa-glide.patch"
    unless File.exist?(primary_patch)
      primary_patch = "#{repo_root}/00-qemu110x-mesa-glide.patch"
    end
    unless File.exist?(primary_patch)
      odie "Primary patch not found: #{primary_patch}"
    end

    ohai "Applying qemu-3dfx patches via apply_qemu_patches.sh"

    args = [
      "bash", apply_script,
      "--src-dir", buildpath.to_s,
      "--primary-patch", primary_patch,
    ]

    # Check for experimental patches (SDL clipboard, etc.)
    use_exp = ENV["APPLY_EXPERIMENTAL_PATCHES"] == "true" ||
              (File.exist?("/tmp/apply_experimental_patches") &&
               File.read("/tmp/apply_experimental_patches").strip == "true")
    if use_exp
      args << "--with-qemu-exp"
      ohai "Experimental patches ENABLED"
    end

    # apply_qemu_patches.sh uses pushd, so run from repo root
    Dir.chdir(repo_root) do
      system *args
    end

    # macOS-specific post-patch fixes
    Dir.chdir(buildpath) do
      # Fix GL_CONTEXTALPHA (not available on macOS)
      if File.exist?("hw/mesa/mglcntx_linux.c")
        inreplace "hw/mesa/mglcntx_linux.c", "GL_CONTEXTALPHA", "GLX_ALPHA_SIZE"
      end

      # ANGLE defines EGLNativeDisplayType as int; eglGetPlatformDisplayEXT expects void*
      if File.exist?("ui/egl-helpers.c")
        inreplace "ui/egl-helpers.c",
          "eglGetPlatformDisplayEXT(platform, native, NULL)",
          "eglGetPlatformDisplayEXT(platform, (void *)(intptr_t)native, NULL)"
      end
    end

    ohai "All qemu-3dfx patches applied"
  end

  # ── Glide libraries (host-side Glide-to-OpenGL translation) ───────────

  def build_glide_libraries
    glide_build_dir = buildpath/"openglide_build"
    glide_build_dir.mkpath

    resource("openglide").stage { cp_r ".", glide_build_dir }

    cd glide_build_dir/"openglide" do
      chmod 0o755, "bootstrap"
      system "./bootstrap"

      # GL headers from Homebrew mesa (no XQuartz needed)
      include_dir = glide_build_dir/"include"
      gl_include_dir = include_dir/"GL"
      khr_include_dir = include_dir/"KHR"
      gl_include_dir.mkpath
      khr_include_dir.mkpath

      mesa_gl = "#{HOMEBREW_PREFIX}/include/GL"
      if Dir.exist?(mesa_gl)
        Dir.glob("#{mesa_gl}/*.h").each do |h|
          (gl_include_dir/File.basename(h)).make_symlink(h)
        end
      end

      mesa_khr = "#{HOMEBREW_PREFIX}/include/KHR"
      if Dir.exist?(mesa_khr)
        Dir.glob("#{mesa_khr}/*.h").each do |h|
          (khr_include_dir/File.basename(h)).make_symlink(h)
        end
      end

      system "./configure", "--disable-sdl",
        "--prefix=#{prefix}",
        "CPPFLAGS=-I#{include_dir} -I#{HOMEBREW_PREFIX}/include -I#{HOMEBREW_PREFIX}/opt/mesa/include",
        "CFLAGS=-I#{include_dir} -I#{HOMEBREW_PREFIX}/include -I#{HOMEBREW_PREFIX}/opt/mesa/include",
        "CXXFLAGS=-I#{include_dir} -I#{HOMEBREW_PREFIX}/include -I#{HOMEBREW_PREFIX}/opt/mesa/include",
        "LDFLAGS=-L#{HOMEBREW_PREFIX}/lib",
        "LIBS=-lX11"

      system "make"
      system "make", "install"
    end
  end

  # ── Helper methods ──────────────────────────────────────────────────────

  def copy_3dfx_wrapper_sources
    repo_root = find_repo_root(__dir__)
    return unless repo_root

    wrappers_dir = "#{repo_root}/wrappers"
    return unless Dir.exist?(wrappers_dir)

    wrappers_share_dir = "#{prefix}/share/qemu-3dfx/wrappers"
    mkdir_p wrappers_share_dir
    cp_r "#{wrappers_dir}/.", wrappers_share_dir
    ohai "Copied wrapper sources to #{wrappers_share_dir}/"
  end

  def copy_signing_files
    sign_dir = "#{prefix}/sign"
    mkdir_p sign_dir

    repo_root = find_repo_root(__dir__)
    return unless repo_root

    ["qemu.rsrc", "qemu.sign"].each do |f|
      src = "#{repo_root}/#{f}"
      cp src, "#{sign_dir}/#{f}" if File.exist?(src)
    end
  end

  def find_repo_root(start_dir)
    # Key files that identify the qemu-3dfx repository root
    key_files = ["00-qemu110x-mesa-glide.patch", "qemu-0", "virgil3d"]

    # Also check for submodule-based layout
    alt_key_files = ["qemu-3dfx-arch"]

    current_dir = File.expand_path(start_dir)

    15.times do
      if key_files.all? { |f| File.exist?(File.join(current_dir, f)) }
        return current_dir
      end

      # Check submodule layout: root has qemu-3dfx-arch/ with key files inside
      if alt_key_files.all? { |f| File.exist?(File.join(current_dir, f)) }
        submodule = File.join(current_dir, "qemu-3dfx-arch")
        if File.exist?(File.join(submodule, "00-qemu110x-mesa-glide.patch")) ||
           File.exist?(File.join(submodule, "qemu-0"))
          return current_dir
        end
      end

      parent_dir = File.dirname(current_dir)
      break if parent_dir == current_dir
      current_dir = parent_dir
    end

    # Fallback: common locations
    [
      ENV["GITHUB_WORKSPACE"],
      ENV["RUNNER_WORKSPACE"] ? File.join(ENV["RUNNER_WORKSPACE"], "qemu-3dfx-macos") : nil,
      File.expand_path("~"),
    ].compact.each do |base_dir|
      next unless Dir.exist?(base_dir)
      if key_files.all? { |f| File.exist?(File.join(base_dir, f)) }
        return base_dir
      end
      Dir.glob("#{base_dir}/*qemu-3dfx*").each do |candidate|
        next unless File.directory?(candidate)
        return candidate if key_files.all? { |f| File.exist?(File.join(candidate, f)) }
      end
    end

    nil
  end

  test do
    version_output = shell_output("#{bin}/qemu-system-x86_64 --version")
    assert_match(/qemu-3dfx(-arch)?@/, version_output, "3dfx signature not found")

    system "#{bin}/qemu-system-x86_64", "--version"

    device_output = shell_output("#{bin}/qemu-system-x86_64 -device help")
    assert device_output.match?(/virtio-vga-gl|virtio-vga/), "Virgl3D support not found"

    display_output = shell_output("#{bin}/qemu-system-x86_64 -display help")
    assert_match "sdl", display_output, "SDL display support not found"
  end
end
