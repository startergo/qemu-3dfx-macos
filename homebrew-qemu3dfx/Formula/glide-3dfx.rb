class Glide3dfx < Formula
  desc "3dfx Glide wrapper libraries for QEMU 3dfx support"
  homepage "https://github.com/startergo/qemu-3dfx-macos"
  url "https://github.com/startergo/qemu-3dfx-macos.git",
      revision: "master"
  version "2.60-3dfx"
  license "GPL-2.0-or-later"

  depends_on "cmake" => :build
  depends_on "make" => :build

  def install
    # Build 3dfx wrapper libraries
    wrappers_dir = "wrappers"
    
    if Dir.exist?(wrappers_dir)
      Dir.chdir(wrappers_dir) do
        # Look for 3dfx wrapper directories
        Dir["*/"].each do |wrapper_dir|
          next unless wrapper_dir.include?("3dfx") || wrapper_dir.include?("glide")

          Dir.chdir(wrapper_dir) do
            if File.exist?("Makefile")
              system "make", "clean"
              if system("make")
                # Copy built libraries
                Dir["libglide*.dylib"].each do |lib|
                  lib.install lib
                end
              end
            elsif Dir.exist?("src") && File.exist?("src/configure")
              # Handle autotools-based builds
              Dir.chdir("src") do
                system "./configure", "--prefix=#{prefix}"
                system "make"
                system "make", "install"
              end
            end
          end
        end
      end

      # Create standard symlinks in lib directory
      Dir.chdir(lib) do
        %w[libglide2x libglide3x].each do |libname|
          if File.exist?("#{libname}.0.dylib")
            ln_sf "#{libname}.0.dylib", "#{libname}.dylib"
          end
        end
      end

      # Create compatibility symlinks in /usr/local/lib if permissions allow
      begin
        mkdir_p "/usr/local/lib"
        ln_sf "#{lib}/libglide2x.dylib", "/usr/local/lib/libglide2x.dylib"
        ln_sf "#{lib}/libglide3x.dylib", "/usr/local/lib/libglide3x.dylib"
      rescue Errno::EACCES
        opoo "Could not create compatibility symlinks in /usr/local/lib (permission denied)"
        puts "You may need to manually create these symlinks:"
        puts "  sudo ln -sf #{lib}/libglide2x.dylib /usr/local/lib/libglide2x.dylib"
        puts "  sudo ln -sf #{lib}/libglide3x.dylib /usr/local/lib/libglide3x.dylib"
      end
    else
      opoo "No wrapper sources found - installing placeholder"
      touch lib/"README-no-wrappers"
    end

    # Create version info
    (prefix/"VERSION").write(version)
  end

  def caveats
    <<~EOS
      3dfx Glide wrapper libraries have been installed.
      
      If you need compatibility symlinks in /usr/local/lib, run:
        sudo ln -sf #{lib}/libglide2x.dylib /usr/local/lib/libglide2x.dylib
        sudo ln -sf #{lib}/libglide3x.dylib /usr/local/lib/libglide3x.dylib
      
      These libraries provide Glide API emulation for legacy 3dfx games
      when used with QEMU 3dfx Voodoo device emulation.
    EOS
  end

  test do
    # Check that at least one glide library was built or installed
    glide_libs = Dir["#{lib}/libglide*.dylib"]
    assert !glide_libs.empty?, "No Glide libraries found"
    
    # Test that symlinks work
    %w[libglide2x.dylib libglide3x.dylib].each do |lib_name|
      lib_path = lib/lib_name
      if File.exist?(lib_path)
        assert_predicate lib_path, :readable?
      end
    end
  end
end
