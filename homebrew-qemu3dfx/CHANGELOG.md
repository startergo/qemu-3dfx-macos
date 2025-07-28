# Changelog

All notable changes to this Homebrew tap will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial Homebrew tap creation
- qemu-3dfx formula for QEMU 9.2.2 with 3dfx patches
- virglrenderer-3dfx formula for custom Virgl3D renderer
- glide-3dfx formula for 3dfx Glide wrapper libraries
- Automated testing with GitHub Actions
- Installation and test scripts
- Comprehensive documentation

### Fixed
- Fixed patch application order: sign_commit script now runs after all patches
- Fixed environment variable propagation for experimental patches in GitHub Actions
- SDL clipboard patch now properly applies when experimental patches are enabled

### Features
- 3dfx Voodoo1/2/Banshee device emulation
- Virgl3D OpenGL acceleration support
- macOS-optimized builds (Intel and Apple Silicon)
- SDL2 display backend (no Cocoa dependency)
- Complete dependency management
- Code signing support

### Supported Targets
- i386-softmmu (DOS, Windows 9x, early Linux)
- x86_64-softmmu (modern x86_64 systems)  
- aarch64-softmmu (ARM64 systems)

### Compatibility
- macOS 10.15+ (Catalina or later)
- Intel x86_64 and Apple Silicon (arm64)
- Homebrew 3.0+

## [1.0.0] - TBD

### Added
- First stable release of the tap
- All formulae tested and verified
- Complete documentation
- Installation automation

### Changed
- N/A (initial release)

### Deprecated
- N/A (initial release)

### Removed
- N/A (initial release)

### Fixed
- N/A (initial release)

### Security
- N/A (initial release)
