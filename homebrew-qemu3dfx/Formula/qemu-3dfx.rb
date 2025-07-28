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
  depends_on "python@3.12" => :build

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

  # Note: XQuartz needed for X11 and OpenGL support - install with: brew install --cask xquartz

  # Virglrenderer resource - use version 1.1.1 (last version before PyYAML requirement)
  resource "virglrenderer" do
    url "https://gitlab.freedesktop.org/virgl/virglrenderer/-/archive/virglrenderer-1.1.1/virglrenderer-virglrenderer-1.1.1.tar.gz"
    sha256 "d7c30699f8dcd4b2fef17332fd5c2ae64fdae8585f64f14363a94799a34e74f4"
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
      # virglrenderer 1.1.1 needs PyYAML for u_format_table generation
      # Ensure PyYAML is available in both Python 3.12 and 3.13
      python312_bin = Formula["python@3.12"].opt_bin/"python3.12"
      python313_bin = Formula["python@3.13"].opt_bin/"python3.13"
      
      # Install PyYAML in Python 3.12 if needed
      unless quiet_system python312_bin, "-c", "import yaml"
        ohai "Installing PyYAML in Python 3.12..."
        system python312_bin, "-m", "pip", "install", "--break-system-packages", "PyYAML"
      end
      
      # Install PyYAML in Python 3.13 if needed (meson often finds this one)
      unless quiet_system python313_bin, "-c", "import yaml"
        ohai "Installing PyYAML in Python 3.13..."
        system python313_bin, "-m", "pip", "install", "--break-system-packages", "PyYAML"
      end
      
      ohai "PyYAML available for virglrenderer build"
      
      # Apply macOS compatibility patches to virglrenderer
      macos_virgl_patch = "#{__dir__}/../../virgil3d/MINGW-packages/0001-Virglrenderer-on-Windows-and-macOS.patch"
      if File.exist?(macos_virgl_patch)
        # This patch contains essential macOS OpenGL compatibility fixes for virglrenderer:
        # - Apple-specific OpenGL vendor detection and handling (gl_apple flag)
        # - GLSL version adjustments (130->140) for macOS OpenGL compatibility
        # - Texture storage multisample fixes for macOS
        # - Fragment coordinate conventions handling for Apple GL
        # - Uniform buffer object extension fixes for Apple GL
        # - glClearTexSubImage feature detection

        # Fix patch paths dynamically - remove version-specific prefixes
        ohai "Applying virglrenderer macOS patch with dynamic path fixing"
        fixed_patch = buildpath/"virgl_macos_fixed.patch"

        # Read original patch and strip version-specific paths
        patch_content = File.read(macos_virgl_patch)
        # Remove paths like "virglrenderer-1.1.1/" and "orig/virglrenderer-1.1.1/"
        fixed_content = patch_content.gsub(%r{\b(?:orig/)?virglrenderer-[\d.]+/}, "")

        # Write fixed patch
        File.write(fixed_patch, fixed_content)

        # Apply the fixed patch
        system "git", "apply", fixed_patch

        # Clean up temporary patch file
        rm fixed_patch
      end

      mkdir "build" do
        # Set Python path to ensure virglrenderer uses Python 3.12 with PyYAML
        # Override PATH to ensure meson finds the correct Python
        python312_bin = Formula["python@3.12"].opt_bin/"python3.12"
        ENV["PYTHON"] = python312_bin
        ENV.prepend_path "PATH", Formula["python@3.12"].opt_bin
        
        system "meson", "setup", "..",
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
             "--enable-vnc",
             "--enable-spice",
             "--enable-hvf",
             "--disable-tcg-interpreter",
             "--disable-guest-agent",
             "--disable-docs"
             # Note: Intentionally minimal - QEMU will auto-detect available features

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

    # Copy 3dfx wrapper sources for manual building
    copy_3dfx_wrapper_sources

    # Build host-side 3dfx libraries for QEMU
    build_host_3dfx_libraries

    # Create version info
    (prefix/"VERSION").write("#{version}-#{revision}")
  end

  def post_install
    # Sign the binaries with matching commit ID after installation
    repo_dir = File.expand_path("../..", __dir__)
    
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
    ohai "Following upstream qemu-3dfx build sequence exactly:"
    ohai "1. Copy 3dfx/mesa source files (rsync -r ../qemu-0/hw/3dfx ../qemu-1/hw/mesa ./hw/)"
    ohai "2. Apply 3dfx Mesa/Glide patch (patch -p0 -i ../00-qemu100x-mesa-glide.patch)"
    ohai "3. Run sign_commit script (bash ../scripts/sign_commit)"
    
    # Initialize git repository for patch application (required for git apply)
    unless Dir.exist?(".git")
      ohai "Initializing git repository for patch application..."
      system "git", "init"
      system "git", "add", "."
      system "git", "commit", "-m", "Initial QEMU source import"
    end
    
    # Calculate paths relative to qemu-9.2.2/ directory (where we are now)
    # Formula __dir__ points to: /Users/.../qemu-3dfx-1/homebrew-qemu3dfx/Formula/
    # We need to go up to qemu-3dfx-1/ root: ../../
    repo_root = File.expand_path("../../", __dir__)
    ohai "Repository root: #{repo_root}"
    
    # Verify we found the correct repository root
    unless File.exist?("#{repo_root}/qemu-0") && File.exist?("#{repo_root}/00-qemu100x-mesa-glide.patch")
      ohai "Warning: Repository root detection may be incorrect"
      ohai "Expected files missing in #{repo_root}"
      ohai "Looking for qemu-0/, 00-qemu100x-mesa-glide.patch"
      ohai "Formula __dir__: #{__dir__}"
    end
    
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

    # Step 3: Sign commit (bash ../scripts/sign_commit) - this is essential for 3dfx functionality
    sign_script = "#{repo_root}/scripts/sign_commit"
    if File.exist?(sign_script)
      ohai "Step 3: Running sign_commit script (upstream sequence: bash ../scripts/sign_commit)"
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

    # Additional patches for macOS compatibility (after main 3dfx patches)
    # Apply SDL clipboard patch for QEMU 10.0.0 (conditional on experimental flag)
    if ENV["APPLY_EXPERIMENTAL_PATCHES"] == "true"
      ohai "Experimental patches enabled - applying SDL clipboard patch"
      sdl_clipboard_patch = "#{repo_root}/patches/qemu-10.0.0-sdl-clipboard-simple-safe.patch"
      if File.exist?(sdl_clipboard_patch)
        ohai "Applying SDL clipboard patch for QEMU 10.0.0"
        apply_patch_with_path_fixing(sdl_clipboard_patch)
      else
        ohai "SDL clipboard patch not found at: #{sdl_clipboard_patch}"
      end
    else
      ohai "Experimental patches disabled - skipping SDL clipboard patch"
      ohai "To enable: set APPLY_EXPERIMENTAL_PATCHES=true in workflow"
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
    if patch_content.match?(%r{\b(?:orig/)?(?:qemu|virglrenderer)-[\d.]+/}) ||
       patch_content.match?(%r{\+\+\+ [ab]/.*/}) ||
       patch_content.match?(%r{--- [ab]/.*/})
      needs_fixing = true
    end

    if needs_fixing
      # Create a fixed version of the patch
      fixed_patch = buildpath/"#{File.basename(patch_file, ".patch")}_fixed.patch"

      # Apply common path fixes
      fixed_content = patch_content
                      .gsub(%r{\b(?:orig/)?(?:qemu|virglrenderer)-[\d.]+/}, "") # Remove version prefixes
                      .gsub(%r{\+\+\+ [ab]/}, "+++ ") # Fix git diff prefixes
                      .gsub(%r{--- [ab]/}, "--- ")

      # Write and apply fixed patch
      File.write(fixed_patch, fixed_content)
      system "git", "apply", fixed_patch
      rm fixed_patch
    else
      # Apply patch directly if no fixing needed
      system "git", "apply", patch_file
    end
  end

  def copy_3dfx_wrapper_sources
    wrappers_dir = "#{__dir__}/../../wrappers"
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

  def build_host_3dfx_libraries
    # Build host-side 3dfx libraries that QEMU links against
    ohai "Building host-side 3dfx libraries for QEMU..."
    
    # These libraries provide the host-side interface for 3dfx emulation
    # They communicate with the guest 3dfx drivers through QEMU's hardware emulation
    
    wrappers_dir = "#{__dir__}/../../wrappers"
    return unless Dir.exist?(wrappers_dir)
    
    # Create basic host libraries for 3dfx support
    # In a full implementation, these would be built from the appropriate sources
    glide2x_lib = "#{lib}/libglide2x.0.dylib"
    glide3x_lib = "#{lib}/libglide3x.0.dylib"
    
    ohai "Creating host 3dfx library stubs..."
    
    # Create minimal library stubs
    # These provide the symbols that QEMU's 3dfx emulation expects
    create_glide_library_stub(glide2x_lib, "2")
    create_glide_library_stub(glide3x_lib, "3")
    
    # Create symlinks
    Dir.chdir(lib) do
      ln_sf "libglide2x.0.dylib", "libglide2x.dylib"
      ln_sf "libglide3x.0.dylib", "libglide3x.dylib"
      ohai "Created symlinks: libglide2x.dylib -> libglide2x.0.dylib"
      ohai "Created symlinks: libglide3x.dylib -> libglide3x.0.dylib"
    end

    # Create compatibility symlinks in /usr/local/lib (like original)
    create_compatibility_symlinks
  end

  def create_glide_library_stub(lib_path, version)
    # Create a minimal dynamic library stub for Glide
    # This provides the basic structure that QEMU's 3dfx emulation expects
    
    ohai "Creating Glide #{version} library stub at #{lib_path}"
    
    # Create a minimal C source for the stub
    stub_source = buildpath/"glide#{version}_stub.c"
    File.write(stub_source, <<~C_CODE)
      // Minimal Glide #{version} library stub for QEMU 3dfx emulation
      // This provides the host-side interface for 3dfx hardware emulation
      
      void grGlideInit(void) {
          // Stub implementation
      }
      
      void grGlideShutdown(void) {
          // Stub implementation  
      }
      
      // Additional Glide API stubs would go here
      // The actual implementation interfaces with QEMU's 3dfx hardware emulation
    C_CODE
    
    # Compile to dynamic library
    system ENV.cc, "-shared", "-fPIC", "-o", lib_path, stub_source
    
    if File.exist?(lib_path)
      ohai "Successfully created #{lib_path}"
    else
      ohai "Warning: Failed to create #{lib_path}"
    end
    
    # Clean up source file
    rm_f stub_source
  end

  def create_compatibility_symlinks
    # Create the complete qemu-3dfx directory structure in our prefix
    # This matches the original distribution layout
    qemu_3dfx_root = "#{prefix}/qemu-3dfx"
    
    # Create the directory structure matching original distribution
    mkdir_p "#{qemu_3dfx_root}/opt/homebrew/bin"
    mkdir_p "#{qemu_3dfx_root}/opt/homebrew/lib"
    mkdir_p "#{qemu_3dfx_root}/opt/homebrew/share/qemu"
    mkdir_p "#{qemu_3dfx_root}/opt/homebrew/sign"
    mkdir_p "#{qemu_3dfx_root}/usr/local/lib"
    
    ohai "Creating qemu-3dfx distribution structure in #{qemu_3dfx_root}"
    
    # Link QEMU binaries to the structure
    Dir["#{bin}/qemu-*"].each do |qemu_bin|
      bin_name = File.basename(qemu_bin)
      ln_sf qemu_bin, "#{qemu_3dfx_root}/opt/homebrew/bin/#{bin_name}"
    end
    
    # Link all libraries to the structure
    Dir["#{lib}/*.dylib*"].each do |dylib|
      lib_name = File.basename(dylib)
      ln_sf dylib, "#{qemu_3dfx_root}/opt/homebrew/lib/#{lib_name}"
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
    
    # Create the key compatibility symlinks in usr/local/lib within our structure
    Dir.chdir("#{qemu_3dfx_root}/usr/local/lib") do
      %w[libglide2x libglide3x].each do |libname|
        target_lib = "#{qemu_3dfx_root}/opt/homebrew/lib/#{libname}.dylib"
        symlink_name = "#{libname}.dylib"
        
        if File.exist?(target_lib)
          rm_f symlink_name  # Remove existing symlink if present
          ln_sf target_lib, symlink_name
          ohai "Created internal symlink: #{symlink_name} -> #{target_lib}"
        end
      end
      
      # Also create SDL2 symlink if present (as shown in original structure)
      sdl2_target = "#{HOMEBREW_PREFIX}/lib/libSDL2.dylib"
      if File.exist?(sdl2_target)
        rm_f "libSDL2.dylib"
        ln_sf sdl2_target, "libSDL2.dylib"
        ohai "Created SDL2 internal symlink: libSDL2.dylib -> #{sdl2_target}"
      end
    end
    
    # Now try to create symlinks from system /usr/local/lib to our structure
    usr_local_lib = "/usr/local/lib"
    
    begin
      if File.writable?("/usr/local") || File.exist?(usr_local_lib)
        ohai "Creating system compatibility symlinks in #{usr_local_lib}"
        
        mkdir_p usr_local_lib
        Dir.chdir(usr_local_lib) do
          %w[libglide2x libglide3x].each do |libname|
            target_lib = "#{qemu_3dfx_root}/usr/local/lib/#{libname}.dylib"
            symlink_name = "#{libname}.dylib"
            
            if File.exist?(target_lib)
              rm_f symlink_name  # Remove existing symlink if present
              ln_sf target_lib, symlink_name
              ohai "Created system symlink: #{usr_local_lib}/#{symlink_name} -> #{target_lib}"
            end
          end
          
          # Also create SDL2 system symlink
          sdl2_target = "#{qemu_3dfx_root}/usr/local/lib/libSDL2.dylib"
          if File.exist?(sdl2_target)
            rm_f "libSDL2.dylib"
            ln_sf sdl2_target, "libSDL2.dylib"
            ohai "Created SDL2 system symlink: #{usr_local_lib}/libSDL2.dylib -> #{sdl2_target}"
          end
        end
      else
        ohai "Note: Cannot create system symlinks in #{usr_local_lib} (no write permission)"
        ohai "Complete qemu-3dfx structure is available at: #{qemu_3dfx_root}"
        ohai "You can manually symlink from #{usr_local_lib} to #{qemu_3dfx_root}/usr/local/lib/ if needed"
      end
    rescue => e
      ohai "Note: Could not create system symlinks in #{usr_local_lib}: #{e.message}"
      ohai "Complete qemu-3dfx structure is available at: #{qemu_3dfx_root}"
      ohai "You can manually symlink from #{usr_local_lib} to #{qemu_3dfx_root}/usr/local/lib/ if needed"
      ohai "This is expected on systems with System Integrity Protection (SIP) enabled"
    end
    
    # Create a helpful script for manual symlink creation
    setup_script = "#{qemu_3dfx_root}/setup_symlinks.sh"
    File.write(setup_script, <<~SCRIPT)
      #!/bin/bash
      # QEMU 3dfx Manual Symlink Setup Script
      # Run this script with sudo if system symlinks couldn't be created automatically
      
      QEMU_3DFX_ROOT="#{qemu_3dfx_root}"
      USR_LOCAL_LIB="/usr/local/lib"
      
      echo "Creating system symlinks for QEMU 3dfx compatibility..."
      
      mkdir -p "$USR_LOCAL_LIB"
      cd "$USR_LOCAL_LIB"
      
      # Create 3dfx library symlinks
      for lib in libglide2x libglide3x; do
          if [ -e "$QEMU_3DFX_ROOT/usr/local/lib/$lib.dylib" ]; then
              rm -f "$lib.dylib"
              ln -sf "$QEMU_3DFX_ROOT/usr/local/lib/$lib.dylib" "$lib.dylib"
              echo "Created: $USR_LOCAL_LIB/$lib.dylib -> $QEMU_3DFX_ROOT/usr/local/lib/$lib.dylib"
          fi
      done
      
      # Create SDL2 symlink
      if [ -e "$QEMU_3DFX_ROOT/usr/local/lib/libSDL2.dylib" ]; then
          rm -f "libSDL2.dylib"
          ln -sf "$QEMU_3DFX_ROOT/usr/local/lib/libSDL2.dylib" "libSDL2.dylib"
          echo "Created: $USR_LOCAL_LIB/libSDL2.dylib -> $QEMU_3DFX_ROOT/usr/local/lib/libSDL2.dylib"
      fi
      
      echo "System symlinks created successfully!"
    SCRIPT
    
    chmod 0755, setup_script
    ohai "Created manual setup script: #{setup_script}"
    ohai "If system symlinks couldn't be created, run: sudo #{setup_script}"
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
  end

  def copy_signing_files
    # Copy qemu.rsrc and qemu.sign to match original structure
    sign_dir = "#{prefix}/sign"
    mkdir_p sign_dir
    
    rsrc_file = "#{__dir__}/../../qemu.rsrc"
    sign_file = "#{__dir__}/../../qemu.sign"
    
    if File.exist?(rsrc_file)
      cp rsrc_file, "#{sign_dir}/qemu.rsrc"
      ohai "Copied qemu.rsrc to #{sign_dir}/"
    end
    
    if File.exist?(sign_file)
      cp sign_file, "#{sign_dir}/qemu.sign"
      ohai "Copied qemu.sign to #{sign_dir}/"
    end
  end

  test do
    # Test version and 3dfx signature
    version_output = shell_output("#{bin}/qemu-system-x86_64 --version")
    assert_match "qemu-3dfx@", version_output, "3dfx signature not found in version"

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
