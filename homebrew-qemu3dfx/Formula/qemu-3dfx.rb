class Qemu3dfx < Formula
  desc "QEMU with 3dfx Voodoo and Virgl3D OpenGL acceleration support"
  homepage "https://github.com/startergo/qemu-3dfx-macos"
  url "https://download.qemu.org/qemu-10.0.0.tar.xz"
  version "10.0.0-3dfx"
  sha256 "22c075601fdcf8c7b2671a839ebdcef1d4f2973eb6735254fd2e1bd0f30b3896"
  license "GPL-2.0-or-later"
  revision 1

  head "https://github.com/startergo/qemu-3dfx-macos.git", branch: "master"

  # Build dependencies
  depends_on "cmake" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "python@3.13" => :build
  depends_on "autoconf" => :build      # Required for OpenGLide
  depends_on "automake" => :build      # Required for OpenGLide
  depends_on "libtool" => :build       # Required for OpenGLide

  # Runtime dependencies (matching official prerequisites for fresh system)
  # Core QEMU prerequisites from official documentation
  depends_on "capstone"       # Required for disassembly support
  depends_on "glib"           # Required for QEMU core
  depends_on "gettext"        # Required for QEMU basic functionality
  depends_on "gnutls"         # Required for crypto support
  depends_on "libepoxy"       # Required for --enable-opengl
  depends_on "libgcrypt"      # Required for crypto support
  depends_on "libslirp"       # Required for networking
  depends_on "libusb"         # Required for USB host support
  depends_on "jpeg-turbo"     # Required for image formats
  depends_on "lz4"            # Required for compression
  depends_on "opus"           # Required for audio
  depends_on "sdl2"           # Required for --enable-sdl
  depends_on "zstd"           # Required for compression
  depends_on "swtpm"          # Required for TPM support

  # Additional dependencies for full functionality
  depends_on "libffi"         # Used by GLib
  depends_on "ncurses"        # Required for --enable-curses
  depends_on "pixman"         # Required for QEMU graphics
  depends_on "sdl2_image"     # Image format support
  
  # SPICE protocol support
  depends_on "spice-protocol" # SPICE protocol definitions
  depends_on "spice-server"   # SPICE server library
  
  # DOSBox SVN Games essentials (from prerequisites)
  depends_on "mt32emu"        # MIDI emulation
  depends_on "sdl12-compat"   # SDL 1.2 compatibility
  depends_on "sdl2_net"       # Network support
  depends_on "sdl2_sound"     # Audio support

  # X11 libraries (required for Mesa GL compilation - provides GL/glcorearb.h)
  depends_on "libx11"         # Core X11 client library
  depends_on "libxext"        # X11 extension library
  depends_on "libxfixes"      # X11 fixes extension
  depends_on "libxrandr"      # X11 randr extension
  depends_on "libxinerama"    # X11 xinerama extension
  depends_on "libxi"          # X11 input extension
  depends_on "libxcursor"     # X11 cursor library
  depends_on "xorgproto"      # X.Org protocol headers
  depends_on "libxxf86vm"     # X11 XF86VidMode extension

  # Note: XQuartz needed for X11 and OpenGL support - install with: brew install --cask xquartz

  # Virglrenderer resource - updated to version 1.2.0 (matching upstream)
  resource "virglrenderer" do
    url "https://gitlab.freedesktop.org/virgl/virglrenderer/-/archive/virglrenderer-1.2.0/virglrenderer-virglrenderer-1.2.0.tar.gz"
    sha256 "b181b668afae817953c84635fac2dc4c2e5786c710b7d225ae215d15674a15c7"
  end

  # OpenGLide resource for building real Glide libraries
  resource "openglide" do
    url "https://github.com/startergo/qemu-xtra/archive/refs/heads/master.tar.gz"
    # Note: Using master branch for latest OpenGLide code
    # sha256 will be dynamically determined
  end

  def install
    # Set up build environment (minimal, matching build script)
    ENV["PKG_CONFIG_PATH"] = "#{HOMEBREW_PREFIX}/lib/pkgconfig"

    # Add libepoxy path specifically (essential for OpenGL)
    epoxy_path = Dir["#{HOMEBREW_PREFIX}/Cellar/libepoxy/*/lib/pkgconfig"].first
    ENV["PKG_CONFIG_PATH"] = "#{epoxy_path}:#{ENV["PKG_CONFIG_PATH"]}" if epoxy_path

    # Setup X11 headers for Mesa GL compilation (matching GitHub Actions workflow)
    setup_x11_headers_for_mesa

    # Build virglrenderer first with macOS patches
    resource("virglrenderer").stage do
      # virglrenderer 1.2.0 needs PyYAML for u_format_table generation
      # Use Python 3.13 for better compatibility (3.14 is too new)
      python_bin = Formula["python@3.13"].opt_bin/"python3.13"
      
      # Install PyYAML and distlib if needed
      unless quiet_system python_bin, "-c", "import yaml"
        ohai "Installing PyYAML in Python 3.13..."
        system python_bin, "-m", "pip", "install", "--break-system-packages", "PyYAML"
      end
      
      unless quiet_system python_bin, "-c", "import distlib"
        ohai "Installing distlib in Python 3.13..."
        system python_bin, "-m", "pip", "install", "--break-system-packages", "distlib"
      end
      
      ohai "PyYAML available for virglrenderer build"
      
      # Apply macOS compatibility patches to virglrenderer
      # Find the repository root by looking for key files
      repo_root = find_repo_root(__dir__)
      macos_virgl_patch = "#{repo_root}/virgil3d/MINGW-packages/0001-Virglrenderer-on-Windows-and-macOS.patch" if repo_root
      
      if macos_virgl_patch
        # This patch contains essential macOS OpenGL compatibility fixes for virglrenderer:
        # - Apple-specific OpenGL vendor detection and handling (gl_apple flag)
        # - GLSL version adjustments (130->140) for macOS OpenGL compatibility
        # - Texture storage multisample fixes for macOS
        # - Fragment coordinate conventions handling for Apple GL
        # - Uniform buffer object extension fixes for Apple GL
        # - glClearTexSubImage feature detection

        ohai "Applying virglrenderer macOS patch with proper path conversion"
        
        # Initialize git repository for patch application
        unless Dir.exist?(".git")
          system "git", "init"
          system "git", "add", "."
          system "git", "commit", "-m", "Initial virglrenderer source"
        end
        
        # Read and convert patch from diff format to git apply format
        patch_content = File.read(macos_virgl_patch)
        
        # Convert from diff -Nru format to git diff format
        # Replace "diff -Nru orig/virglrenderer-1.2.0/path src/virglrenderer-1.2.0/path"
        # with "diff --git a/path b/path"
        fixed_content = patch_content.gsub(/^diff -Nru orig\/virglrenderer-[\d.]+\/(.+?) src\/virglrenderer-[\d.]+\/(.+?)$/m) do |match|
          file_path = $1
          "diff --git a/#{file_path} b/#{file_path}"
        end
        
        # Replace "--- orig/virglrenderer-1.2.0/path" with "--- a/path"
        fixed_content = fixed_content.gsub(/^--- orig\/virglrenderer-[\d.]+\/(.+)$/m, "--- a/\\1")
        
        # Replace "+++ src/virglrenderer-1.2.0/path" with "+++ b/path"
        fixed_content = fixed_content.gsub(/^\+\+\+ src\/virglrenderer-[\d.]+\/(.+)$/m, "+++ b/\\1")
        
        # CRITICAL FIX: Remove any remaining virglrenderer-x.x.x/ prefixes from file paths
        # This handles cases where the patch still contains version-specific directory prefixes
        fixed_content = fixed_content.gsub(/virglrenderer-[\d.]+\//, "")
        
        # Write and apply the converted patch
        fixed_patch = buildpath/"virgl_macos_converted.patch"
        File.write(fixed_patch, fixed_content)
        
        # Apply the converted patch
        system "git", "apply", "--verbose", fixed_patch
        
        # Clean up
        rm fixed_patch
      else
        ohai "Warning: virglrenderer macOS patch not found at #{macos_virgl_patch}"
      end

      mkdir "build" do
        # Set Python path to ensure virglrenderer uses Python 3.13 with PyYAML
        # Override PATH to ensure meson finds the correct Python
        python_bin = Formula["python@3.13"].opt_bin/"python3.13"
        ENV["PYTHON"] = python_bin
        ENV.prepend_path "PATH", Formula["python@3.13"].opt_bin
        
        system "meson", "setup", "..",
               "--prefix=#{prefix}",
               "--buildtype=release",
               "-Dtests=false",
               "-Dplatforms=",
               "-Dminigbm_allocation=false",
               "-Dvenus=false"
               
        # Build and install virglrenderer
        system "ninja"
        system "ninja", "install"
      end
    end

    # Update PKG_CONFIG_PATH to include our custom virglrenderer FIRST (like build script)
    ENV["PKG_CONFIG_PATH"] = "#{prefix}/lib/pkgconfig:#{HOMEBREW_PREFIX}/lib/pkgconfig:#{HOMEBREW_PREFIX}/share/pkgconfig"

    # Add libepoxy path specifically (matching build script approach)
    epoxy_path = Dir["#{HOMEBREW_PREFIX}/Cellar/libepoxy/*/lib/pkgconfig"].first
    ENV["PKG_CONFIG_PATH"] = "#{prefix}/lib/pkgconfig:#{epoxy_path}:#{HOMEBREW_PREFIX}/lib/pkgconfig:#{HOMEBREW_PREFIX}/share/pkgconfig" if epoxy_path

    # CRITICAL FIX: Apply patches from within the extracted QEMU source directory
    # Upstream sequence: cd qemu-9.2.2, then apply patches from within that directory
    # The Homebrew buildpath is where qemu-9.2.2.tar.xz gets extracted
    
    # Debug: Show current working directory and paths
    ohai "Current working directory: #{Dir.pwd}"
    ohai "Formula __dir__: #{__dir__}"
    ohai "Buildpath contents: #{Dir.entries(buildpath).reject { |f| f.start_with?('.') }}"
    
    # Check if we have QEMU source files in the current buildpath
    if File.exist?("#{buildpath}/configure") && File.exist?("#{buildpath}/meson.build")
      ohai "QEMU source files detected in buildpath - applying patches directly"
      
      # Apply patches from the buildpath (which contains the QEMU source)
      Dir.chdir(buildpath) do
        ohai "Now in QEMU source directory: #{Dir.pwd}"
        ohai "About to apply 3dfx patches (upstream sequence)..."
        
        # Apply patches from within the QEMU source directory (matching upstream exactly)
        apply_3dfx_patches
        
        ohai "3dfx patches application completed from within QEMU source directory"
      end
    else
      # Find the extracted QEMU source directory (alternative case)
      qemu_source_dir = Dir.glob("#{buildpath}/qemu-*").select { |path| File.directory?(path) }.first
      if qemu_source_dir.nil?
        odie "QEMU source directory not found in buildpath!"
      end
      
      ohai "Found QEMU source directory: #{qemu_source_dir}"
      ohai "Changing to QEMU source directory to apply patches (matching upstream sequence)"
      
      # Change to the QEMU source directory and apply patches from there
      Dir.chdir(qemu_source_dir) do
        ohai "Now in QEMU source directory: #{Dir.pwd}"
        ohai "About to apply 3dfx patches (upstream sequence: cd qemu-10.0.0 && apply patches)..."
        
        # Apply patches from within qemu-10.0.0/ directory (matching upstream exactly)
        apply_3dfx_patches
        
        ohai "3dfx patches application completed from within QEMU source directory"
      end
    end

    # Configure QEMU (following upstream build sequence: mkdir ../build && cd ../build)
    # Upstream: ../qemu-10.0.0/configure --target-list=i386-softmmu --prefix=$(pwd)/../install_dir
    ohai "Creating separate build directory (upstream sequence: mkdir ../build && cd ../build)"
    
    # Add essential Apple framework linker flags for SDL2 support on macOS
    # SDL2 requires these frameworks to link properly
    apple_frameworks = [
      "-framework AudioToolbox",
      "-framework CoreAudio", 
      "-framework CoreGraphics",
      "-framework CoreFoundation",
      "-framework AppKit",
      "-framework IOKit",
      "-framework ForceFeedback",
      "-framework GameController",
      "-framework Carbon",
      "-framework Cocoa",
      "-framework CoreHaptics",
      "-framework CoreVideo",
      "-framework Metal",
      "-framework MetalKit",
      "-framework OpenGL"
    ].join(" ")
    
    ENV.append "LDFLAGS", apple_frameworks
    ENV.append "LIBS", apple_frameworks
    
    ohai "Added Apple framework linker flags for SDL2 support"
    
    # Create build directory at buildpath level (since QEMU source is in buildpath)
    mkdir "build" do
      ohai "Configuring QEMU from build directory (upstream: ../qemu-10.0.0/configure)..."
      ohai "Building all targets: i386-softmmu (3dfx), x86_64-softmmu (modern), aarch64-softmmu (ARM)"
      
      # Configure from build directory pointing to the QEMU source in buildpath
      system "../configure",
             "--prefix=#{prefix}",
             "--target-list=i386-softmmu,x86_64-softmmu,aarch64-softmmu",
             "--enable-sdl",
             "--enable-opengl",
             "--disable-cocoa",
             "--enable-virglrenderer",
             "--disable-gtk",
             "--disable-dbus-display",
             "--enable-curses",
             "--enable-spice",
             "--disable-tcg-interpreter",
             "--enable-tpm",
             "--disable-docs"
             # Note: SDL clipboard functionality is enabled in the manual integration step

      ohai "Building and installing QEMU 3dfx (upstream: make install)..."
      
      # Optimize ninja build for CI environments but keep all targets
      if ENV["CI"] || ENV["GITHUB_ACTIONS"]
        # Limit parallel jobs in CI to avoid resource exhaustion
        ohai "CI detected: Using limited parallel jobs to prevent timeout"
        system "ninja", "-j2"  # Limit to 2 parallel jobs in CI
      else
        # Local builds can use all available cores
        system "ninja"
      end
      
      system "ninja", "install"
    end

    # Build Glide shared libraries for guest OS use
    build_glide_libraries

    # Copy 3dfx wrapper sources for manual building
    copy_3dfx_wrapper_sources

    # Create version info
    (prefix/"VERSION").write("#{version}-#{revision}")
  end

  def post_install
    # Sign the binaries with matching commit ID after installation
    repo_dir = find_repo_root(__dir__)
    return unless repo_dir
    
    # Get the same commit ID used during build
    commit_id = `cd #{repo_dir} && git rev-parse --short HEAD`.strip
    
    ohai "Post-install: Signing binaries with commit ID #{commit_id}"
    
    # Set environment variable for qemu.sign script
    ENV["QEMU_3DFX_COMMIT"] = commit_id
    
    # Run the qemu.sign script if it exists
    sign_binary_script = "#{prefix}/sign/qemu.sign"
    if File.exist?(sign_binary_script)
      chmod 0755, sign_binary_script
      
      # Change to the sign directory and run the script
      Dir.chdir("#{prefix}/sign") do
        system "bash", "qemu.sign"
      end
    else
      # Try the original location
      original_sign_script = "#{repo_dir}/qemu.sign"
      if File.exist?(original_sign_script)
        # Copy to our prefix and run
        cp original_sign_script, "#{prefix}/sign/"
        chmod 0755, "#{prefix}/sign/qemu.sign"
        
        Dir.chdir("#{prefix}/sign") do
          system "bash", "qemu.sign"
        end
      else
        ohai "Warning: qemu.sign script not found - binaries not signed"
        ohai "3dfx drivers may not load properly without matching signatures"
      end
    end
  end

  def apply_3dfx_patches
    ohai "=== Starting apply_3dfx_patches function ==="
    ohai "Working directory: #{Dir.pwd}"
    ohai "Modified qemu-3dfx build sequence (sign_commit moved to AFTER all patches):"
    ohai "1. Copy 3dfx/mesa source files (rsync -r ../qemu-0/hw/3dfx ../qemu-1/hw/mesa ./hw/)"
    ohai "2. Apply 3dfx Mesa/Glide patch (patch -p0 -i ../00-qemu100x-mesa-glide.patch)"
    ohai "3. Apply experimental patches (if enabled)"
    ohai "4. Apply Virgl3D patches"
    ohai "5. Run sign_commit script AFTER all patches (modified from upstream)"
    
    # Initialize git repository for patch application (required for git apply)
    unless Dir.exist?(".git")
      ohai "Initializing git repository for patch application..."
      system "git", "init"
      system "git", "add", "."
      system "git", "commit", "-m", "Initial QEMU source import"
    end
    
    # Find repository root using helper method
    repo_root = find_repo_root(__dir__)
    if repo_root.nil?
      odie "Could not locate qemu-3dfx repository root! Ensure all required files are present."
    end
    
    ohai "Repository root: #{repo_root}"
    
    # Step 1: Copy 3dfx and mesa source files FIRST (matching upstream rsync command)
    # Upstream: rsync -r ../qemu-0/hw/3dfx ../qemu-1/hw/mesa ./hw/
    qemu0_hw = "#{repo_root}/qemu-0/hw"
    qemu1_hw = "#{repo_root}/qemu-1/hw"

    mkdir_p "hw"
    
    if Dir.exist?("#{qemu0_hw}/3dfx")
      ohai "Step 1a: Copying 3dfx hardware files (upstream: ../qemu-0/hw/3dfx)"
      cp_r "#{qemu0_hw}/3dfx", "hw/"
    else
      ohai "Warning: 3dfx directory not found at #{qemu0_hw}/3dfx"
    end

    if Dir.exist?("#{qemu1_hw}/mesa")
      ohai "Step 1b: Copying Mesa hardware files (upstream: ../qemu-1/hw/mesa)"
      cp_r "#{qemu1_hw}/mesa", "hw/"
    else
      ohai "Warning: Mesa directory not found at #{qemu1_hw}/mesa"
    end

    # Step 2: Apply KJ's Mesa/Glide patches (patch -p0 -i ../00-qemu100x-mesa-glide.patch)
    patch_file = "#{repo_root}/00-qemu100x-mesa-glide.patch"
    ohai "Step 2: Looking for QEMU 10.0.0 patch file at: #{patch_file}"
    
    if File.exist?(patch_file)
      ohai "Step 2: Applying QEMU 10.0.0 3dfx Mesa/Glide patch with -p0 (upstream sequence)"
      # Use -p0 to match upstream build sequence exactly: patch -p0 -i ../00-qemu100x-mesa-glide.patch
      system "patch", "-p0", "-i", patch_file
    else
      ohai "QEMU 10.0.0 3dfx patch file not found at: #{patch_file}"
    end

    # Additional patches for macOS compatibility (applied AFTER 3dfx patch to avoid conflicts)
    # Apply SDL clipboard patch for QEMU 10.0.0 (conditional on experimental flag)
    # Check both environment variable and flag file for maximum reliability
    experimental_patches_env = ENV["APPLY_EXPERIMENTAL_PATCHES"]
    flag_file_value = File.exist?("/tmp/apply_experimental_patches") ? File.read("/tmp/apply_experimental_patches").strip : nil
    
    ohai "Environment variable APPLY_EXPERIMENTAL_PATCHES = '#{experimental_patches_env}'"
    ohai "Flag file value = '#{flag_file_value}'"
    
    # Use flag file value if available, fallback to environment variable
    use_experimental = (flag_file_value == "true") || (flag_file_value.nil? && experimental_patches_env == "true")
    
    if use_experimental
      ohai "✅ Experimental patches enabled - applying SDL clipboard patch AFTER 3dfx patch"
      
      # Apply the cleaned SDL clipboard patch for QEMU 10.0.0
      sdl_clipboard_patch = "#{repo_root}/patches/qemu-10.0.0-sdl-clipboard-post-3dfx-corrected-final.patch"
      if File.exist?(sdl_clipboard_patch)
        ohai "Applying cleaned SDL clipboard patch: #{File.basename(sdl_clipboard_patch)}"
        apply_patch_with_path_fixing(sdl_clipboard_patch)
      else
        ohai "Warning: SDL clipboard patch not found at #{sdl_clipboard_patch}"
      end
    else
      ohai "❌ Experimental patches disabled - skipping SDL clipboard patch"
      ohai "To enable: set APPLY_EXPERIMENTAL_PATCHES=true in workflow"
      ohai "Current env value: APPLY_EXPERIMENTAL_PATCHES='#{experimental_patches_env}'"
      ohai "Current flag file value: '#{flag_file_value}'"
    end

    # Apply Virgl3D patches for QEMU (SDL2+OpenGL compatibility on macOS)
    virgl_patches_dir = "#{repo_root}/virgil3d"
    if Dir.exist?(virgl_patches_dir)
      Dir["#{virgl_patches_dir}/*.patch"].each do |patch|
        # These patches fix QEMU's SDL2+OpenGL implementation for macOS:
        # - 0001-Virgil3D-with-SDL2-OpenGL.patch: Makes EGL optional, adds CONFIG_EGL
        # - 0002-Virgil3D-macOS-GLSL-version.patch: Sets proper OpenGL context for macOS
        ohai "Applying QEMU Virgl3D patch: #{File.basename(patch)}"
        apply_patch_with_path_fixing(patch)
      end
    end

    # Step 3: Sign commit (bash ../scripts/sign_commit) - AFTER all patches are applied
    sign_script = "#{repo_root}/scripts/sign_commit"
    if File.exist?(sign_script)
      ohai "Step 3: Running sign_commit script AFTER all patches (upstream sequence: bash ../scripts/sign_commit)"
      # The sign_commit script embeds git commit info from the qemu-3dfx repository
      # and ensures proper signature matching between QEMU and 3dfx drivers
      
      # Get commit ID for naming and signing
      commit_id = `cd #{repo_root} && git rev-parse --short HEAD`.strip
      
      ohai "Using commit ID: #{commit_id}"
      
      # Export commit ID for binary signing process
      ENV["QEMU_3DFX_COMMIT"] = commit_id
      
      # Run sign_commit matching upstream: bash ../scripts/sign_commit
      system "bash", sign_script, "-git=#{repo_root}", "-commit=#{commit_id}", "HEAD"
    else
      ohai "Warning: sign_commit script not found - 3dfx drivers may not load properly"
    end

    # Apply critical EGL fix for macOS (from build script)
    if File.exist?("meson.build")
      inreplace "meson.build",
                "error('epoxy/egl.h not found')",
                "warning('epoxy/egl.h not found - EGL disabled')"
    end

    # Apply GL_CONTEXTALPHA fix
    inreplace "hw/mesa/mglcntx_linux.c", "GL_CONTEXTALPHA", "GLX_ALPHA_SIZE" if File.exist?("hw/mesa/mglcntx_linux.c")
  end

  def apply_patch_with_path_fixing(patch_file)
    # Helper method to apply patches with dynamic path fixing
    # This handles patches that may contain version-specific or incorrect paths

    patch_content = File.read(patch_file)
    needs_fixing = false

    # Check if patch contains common path issues that need fixing
    # Only look for version-specific paths, not standard git diff paths
    if patch_content.match?(%r{\b(?:orig/)?(?:qemu|virglrenderer)-[\d.]+/})
      needs_fixing = true
    end

    if needs_fixing
      # Create a fixed version of the patch
      fixed_patch = buildpath/"#{File.basename(patch_file, ".patch")}_fixed.patch"

      # Apply path fixes - only remove version prefixes, preserve git diff format
      fixed_content = patch_content
                      .gsub(%r{\b(?:orig/)?(?:qemu|virglrenderer)-[\d.]+/}, "") # Remove version prefixes only

      # Write and apply fixed patch
      File.write(fixed_patch, fixed_content)
      system "git", "apply", fixed_patch
      rm fixed_patch
    else
      # Apply patch directly if no fixing needed
      system "git", "apply", patch_file
    end
  end

  def build_glide_libraries
    # Create a clean build environment for OpenGLide
    glide_build_dir = buildpath/"openglide_build"
    glide_build_dir.mkpath

    cd glide_build_dir do
      # Clean clone and setup OpenGLide
      system "git", "clone", "https://github.com/startergo/qemu-xtra.git", "."
      cd "openglide" do
        # Make bootstrap script executable
        chmod 0755, "bootstrap"
        system "./bootstrap"
        
        # Use Homebrew-compatible header approach
        # Create symlinks to make GL headers discoverable in a way that superenv won't remove
        include_dir = buildpath/"openglide_build/include"
        gl_include_dir = include_dir/"GL"
        khr_include_dir = include_dir/"KHR"
        gl_include_dir.mkpath
        khr_include_dir.mkpath
        
        # Symlink GL headers to local include directory that superenv won't touch
        # XQuartz is installed as a cask, not a formula, so use direct path
        xquartz_gl_include = "/opt/X11/include/GL"
        xquartz_khr_include = "/opt/X11/include/KHR"
        
        if Dir.exist?(xquartz_gl_include)
          Dir.glob("#{xquartz_gl_include}/*.h").each do |header|
            header_name = File.basename(header)
            (gl_include_dir/header_name).make_symlink(header)
          end
        else
          ohai "Warning: XQuartz GL headers not found at #{xquartz_gl_include}"
          ohai "Please install XQuartz: brew install --cask xquartz"
        end
        
        # Symlink KHR headers (required by GL headers)
        if Dir.exist?(xquartz_khr_include)
          Dir.glob("#{xquartz_khr_include}/*.h").each do |header|
            header_name = File.basename(header)
            (khr_include_dir/header_name).make_symlink(header)
          end
        else
          ohai "Warning: XQuartz KHR headers not found at #{xquartz_khr_include}"
        end
        
        system "./configure", "--disable-sdl", 
               "--prefix=#{prefix}",
               "CPPFLAGS=-I#{buildpath}/openglide_build/include",
               "CFLAGS=-I#{buildpath}/openglide_build/include", 
               "CXXFLAGS=-I#{buildpath}/openglide_build/include",
               "LDFLAGS=-L/opt/X11/lib -Wl,-rpath,/opt/X11/lib -Wl,-force_load,/opt/X11/lib/libGL.dylib",
               "LIBS=-lX11"
        system "make"
        
        # Install OpenGLide libraries directly to Homebrew prefix
        system "make", "install"
        
        ohai "OpenGLide libraries installed to Homebrew prefix:"
        ohai "  Access via: $(brew --prefix qemu-3dfx)/lib/"
        ohai "  libglide2x: $(brew --prefix qemu-3dfx)/lib/libglide2x.dylib"
        ohai "  libglide3x: $(brew --prefix qemu-3dfx)/lib/libglide3x.dylib"
        ohai "  Headers: $(brew --prefix qemu-3dfx)/include/openglide/"
      end
    end

    glide_build_dir
  end

  def copy_3dfx_wrapper_sources
    # Find repository root and use relative paths
    repo_root = find_repo_root(__dir__)
    return unless repo_root
    
    wrappers_dir = "#{repo_root}/wrappers"
    return unless Dir.exist?(wrappers_dir)

    ohai "Copying 3dfx wrapper sources for manual building..."
    
    # Copy wrapper source files to share directory for manual building
    wrappers_share_dir = "#{prefix}/share/qemu-3dfx/wrappers"
    mkdir_p wrappers_share_dir
    
    # Copy all wrapper source files (from original source)
    cp_r "#{wrappers_dir}/.", wrappers_share_dir
    ohai "Copied wrapper sources to #{wrappers_share_dir}/"
    
    # Copy signing files to match original structure
    copy_signing_files
    
    ohai "3dfx wrapper sources available for manual cross-compilation"
    ohai "Requires: mingw32, Open-Watcom, i586-pc-msdosdjgpp toolchains"
  end

  def create_compatibility_symlinks
    # Create a basic qemu-3dfx directory structure for compatibility
    qemu_3dfx_root = "#{prefix}/qemu-3dfx"
    
    # Create the directory structure matching original distribution
    mkdir_p "#{qemu_3dfx_root}/opt/homebrew/bin"
    mkdir_p "#{qemu_3dfx_root}/opt/homebrew/share/qemu"
    mkdir_p "#{qemu_3dfx_root}/opt/homebrew/sign"
    
    ohai "Creating qemu-3dfx distribution structure in #{qemu_3dfx_root}"
    
    # Link QEMU binaries to the structure
    Dir["#{bin}/qemu-*"].each do |qemu_bin|
      bin_name = File.basename(qemu_bin)
      ln_sf qemu_bin, "#{qemu_3dfx_root}/opt/homebrew/bin/#{bin_name}"
    end
    
    # Link QEMU data files to the structure
    if Dir.exist?("#{share}/qemu")
      Dir["#{share}/qemu/*"].each do |qemu_file|
        file_name = File.basename(qemu_file)
        if File.file?(qemu_file)
          ln_sf qemu_file, "#{qemu_3dfx_root}/opt/homebrew/share/qemu/#{file_name}"
        elsif File.directory?(qemu_file)
          mkdir_p "#{qemu_3dfx_root}/opt/homebrew/share/qemu/#{file_name}"
          Dir["#{qemu_file}/*"].each do |sub_file|
            sub_name = File.basename(sub_file)
            ln_sf sub_file, "#{qemu_3dfx_root}/opt/homebrew/share/qemu/#{file_name}/#{sub_name}"
          end
        end
      end
    end
    
    # Link signing files to the structure
    if Dir.exist?("#{prefix}/sign")
      Dir["#{prefix}/sign/*"].each do |sign_file|
        file_name = File.basename(sign_file)
        ln_sf sign_file, "#{qemu_3dfx_root}/opt/homebrew/sign/#{file_name}"
      end
    end
  end

  def setup_x11_headers_for_mesa
    # Setup X11 headers for Mesa GL compilation (matching GitHub Actions workflow)
    ohai "Setting up X11 headers for Mesa GL compilation..."
    
    # Create local X11 directory structure in our build prefix
    local_x11_include = "#{buildpath}/local-x11-headers"
    mkdir_p "#{local_x11_include}/X11/extensions"
    mkdir_p "#{local_x11_include}/GL"
    mkdir_p "#{local_x11_include}/KHR"
    
    # Copy X11 extension headers from Homebrew (needed for Mesa GL compilation)
    homebrew_x11_include = "#{HOMEBREW_PREFIX}/include/X11"
    if Dir.exist?(homebrew_x11_include)
      ohai "Copying X11 headers from Homebrew to local build directory"
      # Copy the entire X11 directory structure
      cp_r homebrew_x11_include, "#{local_x11_include}/"
    end
    
    # Copy X11 extension headers from XQuartz (essential for Mesa GL compilation)
    # XQuartz has the complete X11 headers including extensions like xf86vmode.h
    if Dir.exist?("/opt/X11/include/X11")
      ohai "Copying X11 extension headers from XQuartz (overwriting Homebrew headers)"
      # Remove existing X11 directory first to avoid conflicts
      rm_rf "#{local_x11_include}/X11" if Dir.exist?("#{local_x11_include}/X11")
      # Copy complete X11 headers from XQuartz, including extensions directory
      cp_r "/opt/X11/include/X11", "#{local_x11_include}/"
    end
    
    # Copy OpenGL headers from XQuartz
    if Dir.exist?("/opt/X11/include/GL")
      ohai "Copying OpenGL headers from XQuartz"
      cp_r "/opt/X11/include/GL", "#{local_x11_include}/"
    end
    
    # Copy KHR platform headers from XQuartz (required by OpenGL headers)
    if Dir.exist?("/opt/X11/include/KHR")
      ohai "Copying KHR platform headers from XQuartz"
      cp_r "/opt/X11/include/KHR", "#{local_x11_include}/"
    end
    
    # Add Homebrew pixman headers (critical for QEMU compilation)
    pixman_include = "#{HOMEBREW_PREFIX}/include/pixman-1"
    if Dir.exist?(pixman_include)
      ohai "Adding Homebrew pixman headers to include path"
      mkdir_p "#{local_x11_include}/pixman-1"
      cp_r "#{pixman_include}/.", "#{local_x11_include}/pixman-1/"
    end
    
    # Add our local headers to the include path
    ENV.append "CPPFLAGS", "-I#{local_x11_include}"
    ENV.append "CFLAGS", "-I#{local_x11_include}"
    ENV.append "CXXFLAGS", "-I#{local_x11_include}"
    
    # Add GLX library linking for Mesa GL support (from XQuartz)
    ENV.append "LDFLAGS", "-L/opt/X11/lib"
    ENV.append "LIBS", "-lGL -lX11"
    
    # Ensure XQuartz's libGL comes first in the search path (contains GLX functions)
    ENV.prepend "LDFLAGS", "-L/opt/X11/lib"
    
    # Add XQuartz paths to dynamic linker fallback (critical for macOS)
    # This addresses the issue where XQuartz libraries aren't found by the dynamic linker
    ENV["DYLD_FALLBACK_LIBRARY_PATH"] = "#{ENV["DYLD_FALLBACK_LIBRARY_PATH"]}:/opt/X11/lib:/usr/X11/lib:/usr/lib"
    
    # Also add to library path for build-time linking
    ENV.append "LIBRARY_PATH", "/opt/X11/lib:/usr/X11/lib"
    
    # Force linking to XQuartz's GL library specifically (instead of Homebrew's Mesa)
    ENV.append "LDFLAGS", "/opt/X11/lib/libGL.dylib"
    
    # Verify the headers are available
    ohai "Verifying X11 and GL headers setup:"
    if File.exist?("#{local_x11_include}/X11/extensions/xf86vmode.h")
      ohai "✅ xf86vmode.h found"
    else
      ohai "⚠️ xf86vmode.h missing"
    end
    
    if File.exist?("#{local_x11_include}/GL/glcorearb.h")
      ohai "✅ GL/glcorearb.h found"
    else
      ohai "⚠️ GL/glcorearb.h missing"
    end
    
    if File.exist?("#{local_x11_include}/KHR/khrplatform.h")
      ohai "✅ KHR/khrplatform.h found"
    else
      ohai "⚠️ KHR/khrplatform.h missing"
    end
    
    if File.exist?("#{local_x11_include}/pixman-1/pixman.h")
      ohai "✅ pixman.h found"
    else
      ohai "⚠️ pixman.h missing"
    end
    
    if File.exist?("#{local_x11_include}/pixman-1/pixman-version.h")
      ohai "✅ pixman-version.h found"
    else
      ohai "⚠️ pixman-version.h missing"
    end
  end

  def copy_signing_files
    # Copy qemu.rsrc and qemu.sign to match original structure
    sign_dir = "#{prefix}/sign"
    mkdir_p sign_dir
    
    # Find repository root and use relative paths
    repo_root = find_repo_root(__dir__)
    if repo_root
      rsrc_file = "#{repo_root}/qemu.rsrc"
      sign_file = "#{repo_root}/qemu.sign"
      
      if File.exist?(rsrc_file)
        cp rsrc_file, "#{sign_dir}/qemu.rsrc"
        ohai "Copied qemu.rsrc to #{sign_dir}/"
      end
      
      if File.exist?(sign_file)
        cp sign_file, "#{sign_dir}/qemu.sign"
        ohai "Copied qemu.sign to #{sign_dir}/"
      end
    else
      ohai "Warning: Could not locate repository root - signing files not copied"
    end
  end

  def find_repo_root(start_dir)
    # Look for key files that indicate we're in the qemu-3dfx repository root
    key_files = ["00-qemu100x-mesa-glide.patch", "qemu-0", "virgil3d"]
    
    # First, try to find the repository root by walking up from start_dir
    current_dir = File.expand_path(start_dir)
    
    # Walk up the directory tree looking for the repository root
    15.times do  # Increased limit for deeper directory structures
      if key_files.all? { |file| File.exist?(File.join(current_dir, file)) }
        ohai "Repository root found: #{current_dir}"
        return current_dir
      end
      
      parent_dir = File.dirname(current_dir)
      break if parent_dir == current_dir  # Reached filesystem root
      current_dir = parent_dir
    end
    
    # If not found by walking up, try common locations where the repo might be
    potential_locations = [
      # GitHub Actions workspace (highest priority)
      ENV["GITHUB_WORKSPACE"],
      ENV["RUNNER_WORKSPACE"] ? File.join(ENV["RUNNER_WORKSPACE"], "qemu-3dfx-macos") : nil,
      "/Users/#{ENV["USER"]}/work/qemu-3dfx-macos/qemu-3dfx-macos",  # GitHub Actions path
      # When running from Homebrew tap, look for the original repo
      ENV["HOMEBREW_CACHE"],
      "/tmp",
      File.expand_path("~"),
      "/Users/#{ENV["USER"]}",
      # Look in common development directories
      "/Users/#{ENV["USER"]}/qemu-3dfx-1",
      "/Users/#{ENV["USER"]}/qemu-3dfx-macos", 
      "/Users/#{ENV["USER"]}/Documents/qemu-3dfx-1",
      "/Users/#{ENV["USER"]}/Downloads/qemu-3dfx-1"
    ].compact
    
    potential_locations.each do |base_dir|
      next unless base_dir && Dir.exist?(base_dir)
      
      # First check if the base directory itself is the repository root
      if key_files.all? { |file| File.exist?(File.join(base_dir, file)) }
        ohai "Repository root found at location: #{base_dir}"
        return base_dir
      end
      
      # Look for qemu-3dfx directories in this location
      Dir.glob("#{base_dir}/*qemu-3dfx*").each do |candidate|
        next unless File.directory?(candidate)
        
        if key_files.all? { |file| File.exist?(File.join(candidate, file)) }
          ohai "Repository root found in subdirectory: #{candidate}"
          return candidate
        end
      end
    end
    
    # Last resort: check if we can find files relative to the current working directory
    if Dir.pwd != start_dir
      cwd_check = find_repo_root(Dir.pwd)
      return cwd_check if cwd_check
    end
    
    ohai "Warning: Repository root not found. Searched from #{start_dir}"
    ohai "Looking for files: #{key_files.join(', ')}"
    ohai "Checked locations: #{potential_locations.join(', ')}"
    nil  # Repository root not found
  end

  test do
    # Test version and 3dfx signature
    version_output = shell_output("#{bin}/qemu-system-x86_64 --version")
    assert_match(/qemu-3dfx(-arch)?@/, version_output, "3dfx signature not found in version")

    # Test basic functionality
    system "#{bin}/qemu-system-x86_64", "--version"

    # Test Virgl support (virtio-vga or virtio-vga-gl device should be available)
    device_output = shell_output("#{bin}/qemu-system-x86_64 -device help")
    assert device_output.match?(/virtio-vga-gl|virtio-vga/), "Virgl3D support not found (neither virtio-vga-gl nor virtio-vga)"

    # Test that SDL display is available (required for 3dfx)
    display_output = shell_output("#{bin}/qemu-system-x86_64 -display help")
    assert_match "sdl", display_output, "SDL display support not found"
  end
end
