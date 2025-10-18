class Qemu3dfx < Formula
  desc "QEMU with 3dfx Voodoo and Virgl3D OpenGL acceleration support"
  homepage "https://github.com/startergo/qemu-3dfx-macos"
  url "https://download.qemu.org/qemu-10.1.0.tar.xz"
  version "10.1.0-3dfx"
  sha256 "e0517349b50ca73ebec2fa85b06050d5c463ca65c738833bd8fc1f15f180be51"
  license "GPL-2.0-or-later"
  revision 1

  head "https://github.com/startergo/qemu-3dfx-macos.git", branch: "homebrew-qemu-3dfx"

  # Build dependencies
  depends_on "cmake" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "python@3.14" => :build
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
    url "https://github.com/startergo/qemu-xtra/archive/e1e9399f7551fc9d1f8f40d66ff89f94579ce2d1.tar.gz"
    # Note: Pinned to commit e1e9399f7551fc9d1f8f40d66ff89f94579ce2d1 for reproducibility and security
    sha256 "85cf72ae9516c1d105fb2016bc55b56723ee9525a87bb0e994f88131d7e403c7"
  end

  def install
    # Set repository root - handle both local development and Homebrew tap scenarios
    unless ENV["QEMU_3DFX_REPO_ROOT"]
      # Try the local development path first (../../ from homebrew-qemu3dfx/Formula/)
      local_path = File.expand_path("../..", __dir__)
      key_files = ["00-qemu110x-mesa-glide.patch", "qemu-0", "virgil3d"]
      
      if key_files.all? { |file| File.exist?(File.join(local_path, file)) }
        ENV["QEMU_3DFX_REPO_ROOT"] = local_path
        ohai "Using local development repository: #{local_path}"
      else
        # When running from a Homebrew tap, suggest the most likely local path
        suggested_path = "/Users/macbookpro/Downloads/qemu-3dfx"
        if Dir.exist?(suggested_path) && key_files.all? { |file| File.exist?(File.join(suggested_path, file)) }
          ENV["QEMU_3DFX_REPO_ROOT"] = suggested_path
          ohai "Auto-detected repository at common location: #{suggested_path}"
        else
          odie "Repository root not found. Please set QEMU_3DFX_REPO_ROOT environment variable to your qemu-3dfx repository path.\nExample: export QEMU_3DFX_REPO_ROOT=/Users/macbookpro/Downloads/qemu-3dfx"
        end
      end
    else
      ohai "Using QEMU_3DFX_REPO_ROOT from environment: #{ENV["QEMU_3DFX_REPO_ROOT"]}"
    end
    
    # Check for commit override - try multiple methods since Homebrew sanitizes environment
    commit_override = nil
    commit_source = nil
    temp_commit_file = "/tmp/qemu_3dfx_commit_override"
    
    # Method 1: Environment variable (if Homebrew passes it through)
    if ENV["QEMU_3DFX_COMMIT"]
      commit_override = ENV["QEMU_3DFX_COMMIT"]
      commit_source = "ENV variable"
    end
    
    # Method 1b: Try multiple ways to read from parent shell environment
    if commit_override.nil?
      # Try reading from parent process environment via ps
      parent_env_commit = nil
      begin
        # Get parent shell PID and try to read its environment
        ppid = Process.ppid
        env_output = `ps eww #{ppid} 2>/dev/null | grep -o 'QEMU_3DFX_COMMIT=[^[:space:]]*' | cut -d= -f2`.strip
        parent_env_commit = env_output unless env_output.empty?
      rescue
        # Ignore errors and try next method
      end
      
      # Try reading via bash -c to access parent environment
      if parent_env_commit.nil? || parent_env_commit.empty?
        bash_commit = `bash -c 'echo $QEMU_3DFX_COMMIT' 2>/dev/null`.strip
        parent_env_commit = bash_commit unless bash_commit.empty?
      end
      
      # Try reading via zsh -c to access parent environment  
      if parent_env_commit.nil? || parent_env_commit.empty?
        zsh_commit = `zsh -c 'echo $QEMU_3DFX_COMMIT' 2>/dev/null`.strip
        parent_env_commit = zsh_commit unless zsh_commit.empty?
      end
      
      if parent_env_commit && !parent_env_commit.empty?
        # Automatically create the temp file from the environment variable
        File.write(temp_commit_file, parent_env_commit)
        commit_override = parent_env_commit
        commit_source = "shell ENV auto-created temp file"
        ohai "Auto-created temp file from shell QEMU_3DFX_COMMIT: #{parent_env_commit}"
      end
    end
    
    # Method 2: Check for a temporary file (user can create this before running brew)
    if commit_override.nil? && File.exist?(temp_commit_file)
      commit_override = File.read(temp_commit_file).strip
      commit_source = "temp file #{temp_commit_file}"
    end
    
    # Method 3: Check build arguments (Homebrew sometimes passes these)
    ARGV.each do |arg|
      if arg.start_with?("--commit=")
        commit_override = arg.split("=", 2)[1]
        commit_source = "build argument"
        break
      end
    end
    
    # Apply the override if found
    if commit_override && !commit_override.empty?
      ohai "QEMU_3DFX_COMMIT override detected: #{commit_override} (from #{commit_source})"
      ENV["QEMU_3DFX_COMMIT"] = commit_override
      # Store the commit ID persistently for post_install
      (buildpath/"QEMU_3DFX_COMMIT_ID").write(commit_override)
    else
      ohai "No QEMU_3DFX_COMMIT override - will use default branch commit"
      ohai "To override commit: export QEMU_3DFX_COMMIT=your_commit_hash && brew install ..."
      ohai "Or manually: echo 'your_commit_hash' > #{temp_commit_file} && brew install ..."
    end
    
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
      # Use Python 3.14 since that's what meson finds by default
      python_bin = Formula["python@3.14"].opt_bin/"python3.14"
      
      # Install PyYAML and distlib if needed
      unless quiet_system python_bin, "-c", "import yaml"
        ohai "Installing PyYAML in Python 3.14..."
        system python_bin, "-m", "pip", "install", "--break-system-packages", "PyYAML"
      end
      
      unless quiet_system python_bin, "-c", "import distlib"
        ohai "Installing distlib in Python 3.14..."
        system python_bin, "-m", "pip", "install", "--break-system-packages", "distlib"
      end
      
      ohai "PyYAML available for virglrenderer build"
      
      # Set Python environment for meson to use the correct Python with PyYAML
      ENV["PYTHON"] = python_bin
      ENV.prepend_path "PATH", Formula["python@3.14"].opt_bin
      
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
        # Python 3.14 with PyYAML is already set up and first in PATH
        
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
    
    # Copy the stored commit ID to prefix for post_install access
    if File.exist?("#{buildpath}/QEMU_3DFX_COMMIT_ID")
      cp "#{buildpath}/QEMU_3DFX_COMMIT_ID", "#{prefix}/QEMU_3DFX_COMMIT_ID"
      ohai "Copied commit ID file to prefix for post_install access"
    end
  end

  def post_install
    # Set repository root relative to Formula location (in case it's not set)
    ENV["QEMU_3DFX_REPO_ROOT"] ||= File.expand_path("../..", __dir__)
    
    # Sign the binaries with matching commit ID after installation
    repo_dir = ENV["QEMU_3DFX_REPO_ROOT"]
    return unless repo_dir
    
    # CRITICAL: Use the same commit hash that was set during build process
    # Priority: QEMU_3DFX_COMMIT (manual override) > stored from build > git repository
    if ENV["QEMU_3DFX_COMMIT"]
      commit_id = ENV["QEMU_3DFX_COMMIT"]
      commit_source = "QEMU_3DFX_COMMIT env var"
    else
      # Try to read the commit ID that was stored during the build process
      stored_commit_file = "#{prefix}/QEMU_3DFX_COMMIT_ID"
      if File.exist?(stored_commit_file)
        commit_id = File.read(stored_commit_file).strip
        commit_source = "stored from build process"
        ohai "Retrieved stored commit ID: #{commit_id}"
      else
        # Fallback to git repository detection
        begin
          commit_id = `cd "#{repo_dir}" && git rev-parse --short remotes/origin/homebrew-qemu-3dfx 2>/dev/null`.strip
          if commit_id.empty? || $?.exitstatus != 0
            # Fallback to local branch if remote doesn't work
            commit_id = `cd "#{repo_dir}" && git rev-parse --short homebrew-qemu-3dfx 2>/dev/null`.strip
          end
          if commit_id.empty? || $?.exitstatus != 0
            # Final fallback to HEAD
            commit_id = `cd "#{repo_dir}" && git rev-parse --short HEAD 2>/dev/null`.strip
          end
          commit_source = "git repository"
        rescue => e
          ohai "Warning: Could not determine git commit: #{e.message}"
          commit_id = "unknown"
          commit_source = "fallback"
        end
      end
    end
    
    ohai "Post-install: Signing binaries with commit ID #{commit_id}"
    ohai "Commit source: #{commit_source}"
    
    # Ensure the same commit ID is available for qemu.sign script
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
    
    # Find repository root using helper method - pass the current working directory as a hint
    repo_root = if ENV["QEMU_3DFX_REPO_ROOT"]
      # Manual override has highest priority
      ohai "Using manual repository override: #{ENV["QEMU_3DFX_REPO_ROOT"]}"
      ENV["QEMU_3DFX_REPO_ROOT"]
    else
      find_repo_root(__dir__)
    end
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

    # Step 2: Apply KJ's Mesa/Glide patches (patch -p0 -i ../00-qemu110x-mesa-glide.patch)
    patch_file = "#{repo_root}/00-qemu110x-mesa-glide.patch"
    ohai "Step 2: Looking for QEMU 10.1.0 patch file at: #{patch_file}"
    
    if File.exist?(patch_file)
      ohai "Step 2: Applying QEMU 10.1.0 3dfx Mesa/Glide patch with -p0 (upstream sequence)"
      # Use -p0 to match upstream build sequence exactly: patch -p0 -i ../00-qemu110x-mesa-glide.patch
      system "patch", "-p0", "-i", patch_file
    else
      ohai "QEMU 10.1.0 3dfx patch file not found at: #{patch_file}"
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
      ohai "✅ Experimental patches enabled - applying SDL clipboard patch for QEMU 10.1.0"
      
      # Apply the cleaned SDL clipboard patch (testing against QEMU 10.1.0)
      sdl_clipboard_patch = "#{repo_root}/patches/qemu-10.0.0-sdl-clipboard-post-3dfx-corrected-final.patch"
      if File.exist?(sdl_clipboard_patch)
        ohai "Applying SDL clipboard patch to QEMU 10.1.0: #{File.basename(sdl_clipboard_patch)}"
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

    # Step 3: Sign commit (bash ../sign_commit) - AFTER all patches are applied
    sign_script = "#{repo_root}/sign_commit"
    ohai "DEBUG: Looking for sign_commit script at: #{sign_script}"
    ohai "DEBUG: repo_root is: #{repo_root}"
    ohai "DEBUG: File exists? #{File.exist?(sign_script)}"
    if File.exist?(sign_script)
      ohai "Step 3: Running sign_commit script AFTER all patches (upstream sequence: bash ../sign_commit)"
      # The sign_commit script embeds git commit info from the qemu-3dfx repository
      # and ensures proper signature matching between QEMU and 3dfx drivers
      
      # Use existing commit ID from environment if set, otherwise get from git
      # Priority: QEMU_3DFX_COMMIT (manual override) > origin/homebrew-qemu-3dfx branch
      if ENV["QEMU_3DFX_COMMIT"]
        commit_id = ENV["QEMU_3DFX_COMMIT"]
        ohai "Using commit ID from QEMU_3DFX_COMMIT: #{commit_id}"
      else
        # Use robust git command execution with proper error handling
        begin
          commit_id = `cd "#{repo_root}" && git rev-parse --short remotes/origin/homebrew-qemu-3dfx 2>/dev/null`.strip
          if commit_id.empty? || $?.exitstatus != 0
            # Fallback to local branch if remote doesn't work
            commit_id = `cd "#{repo_root}" && git rev-parse --short homebrew-qemu-3dfx 2>/dev/null`.strip
          end
          if commit_id.empty? || $?.exitstatus != 0
            # Final fallback to HEAD
            commit_id = `cd "#{repo_root}" && git rev-parse --short HEAD 2>/dev/null`.strip
          end
          ohai "Using commit ID from git repository: #{commit_id}"
        rescue => e
          ohai "Warning: Could not determine git commit: #{e.message}"
          commit_id = "unknown"
        end
      end
      
      # CRITICAL: Set QEMU_3DFX_COMMIT to ensure both sign_commit and post_install qemu.sign use the same hash
      ENV["QEMU_3DFX_COMMIT"] = commit_id
      
      # Store it persistently for post_install phase
      begin
        (buildpath/"QEMU_3DFX_COMMIT_ID").write(commit_id)
        ohai "Stored commit ID #{commit_id} for post_install phase"
      rescue => e
        ohai "Warning: Could not store commit ID: #{e.message}"
      end
      
      # Run sign_commit matching upstream: bash ../sign_commit
      # The script expects: sign_commit -git=path -commit=hash HEAD
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
    # Create a clean build environment for OpenGLide using the declared resource
    glide_build_dir = buildpath/"openglide_build"
    glide_build_dir.mkpath

    # Stage the OpenGLide resource instead of cloning from git
    resource("openglide").stage do
      # Extract to the build directory
      cp_r ".", glide_build_dir
    end

    cd glide_build_dir/"openglide" do
        # Make bootstrap script executable
        chmod 0o755, "bootstrap"
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
        xquartz_lib_dir = "/opt/X11/lib"
        xquartz_gl_lib = "#{xquartz_lib_dir}/libGL.dylib"
        
        if Dir.exist?(xquartz_gl_include)
          Dir.glob("#{xquartz_gl_include}/*.h").each do |header|
            header_name = File.basename(header)
            (gl_include_dir/header_name).make_symlink(header)
          end
        else
          odie "XQuartz GL headers not found at #{xquartz_gl_include}. Please install XQuartz with: brew install --cask xquartz"
        end
        
        # Symlink KHR headers (required by GL headers)
        if Dir.exist?(xquartz_khr_include)
          Dir.glob("#{xquartz_khr_include}/*.h").each do |header|
            header_name = File.basename(header)
            (khr_include_dir/header_name).make_symlink(header)
          end
        else
          odie "XQuartz KHR headers not found at #{xquartz_khr_include}. Please install XQuartz with: brew install --cask xquartz"
        end
        
        # Verify XQuartz library exists before using it
        unless File.exist?(xquartz_gl_lib)
          odie "XQuartz OpenGL library not found at #{xquartz_gl_lib}. Please install XQuartz with: brew install --cask xquartz"
        end
        
        system "./configure", "--disable-sdl", 
               "--prefix=#{prefix}",
               "CPPFLAGS=-I#{buildpath}/openglide_build/include",
               "CFLAGS=-I#{buildpath}/openglide_build/include", 
               "CXXFLAGS=-I#{buildpath}/openglide_build/include",
               # NOTE: -force_load is required for OpenGLide to access XQuartz's complete OpenGL symbol table
               # XQuartz is installed as a cask (not formula) so normal dynamic linking may miss symbols
               # This ensures all OpenGL functions are available for 3dfx Glide API emulation
               "LDFLAGS=-L#{xquartz_lib_dir} -Wl,-rpath,#{xquartz_lib_dir} -Wl,-force_load,#{xquartz_gl_lib}",
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

    glide_build_dir
  end

  def copy_3dfx_wrapper_sources
    # Use the repository root that was set at the beginning of install
    repo_root = ENV["QEMU_3DFX_REPO_ROOT"]
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
    
    # Use the repository root that was set at the beginning of install
    repo_root = ENV["QEMU_3DFX_REPO_ROOT"]
    if repo_root
      rsrc_file = "#{repo_root}/qemu.rsrc"
      sign_file = "#{repo_root}/qemu.sign"
      sign_binary_script = "#{repo_root}/sign_binary.sh"
      sign_commit_script = "#{repo_root}/sign_commit"
      
      if File.exist?(rsrc_file)
        cp rsrc_file, "#{sign_dir}/qemu.rsrc"
        ohai "Copied qemu.rsrc to #{sign_dir}/"
      end
      
      if File.exist?(sign_file)
        cp sign_file, "#{sign_dir}/qemu.sign"
        ohai "Copied qemu.sign to #{sign_dir}/"
      end
      
      if File.exist?(sign_binary_script)
        cp sign_binary_script, "#{sign_dir}/sign_binary.sh"
        chmod 0755, "#{sign_dir}/sign_binary.sh"
        ohai "Copied sign_binary.sh to #{sign_dir}/"
      end
      
      if File.exist?(sign_commit_script)
        cp sign_commit_script, "#{sign_dir}/sign_commit"
        chmod 0755, "#{sign_dir}/sign_commit"
        ohai "Copied sign_commit to #{sign_dir}/"
      end
    else
      ohai "Warning: Could not locate repository root - signing files not copied"
    end
  end

  def find_repo_root(start_dir)
    # Look for key files that indicate we're in the qemu-3dfx repository root
    key_files = ["00-qemu110x-mesa-glide.patch", "qemu-0", "virgil3d"]
    
    # Build list of locations to check in priority order
    locations_to_check = []
    
    # 1. Environment variables (highest priority)
    locations_to_check << ENV["GITHUB_WORKSPACE"] if ENV["GITHUB_WORKSPACE"]
    locations_to_check << File.join(ENV["RUNNER_WORKSPACE"], "qemu-3dfx-macos") if ENV["RUNNER_WORKSPACE"]
    locations_to_check << ENV["QEMU_3DFX_REPO_ROOT"] if ENV["QEMU_3DFX_REPO_ROOT"]
    
    # 2. Walk up from start_dir
    current_dir = File.expand_path(start_dir)
    15.times do
      locations_to_check << current_dir
      parent_dir = File.dirname(current_dir)
      break if parent_dir == current_dir  # Reached filesystem root
      current_dir = parent_dir
    end
    
    # Check each location
    locations_to_check.uniq.each do |location|
      next unless location && Dir.exist?(location)
      
      if key_files.all? { |file| File.exist?(File.join(location, file)) }
        ohai "Repository root found: #{location}"
        return location
      end
    end
    
    ohai "Warning: Repository root not found. Searched from #{start_dir}"
    ohai "Looking for files: #{key_files.join(', ')}"
    ohai "Checked #{locations_to_check.length} locations"
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
