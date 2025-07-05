# GitHub Actions Workflows for QEMU 3dfx

This directory contains comprehensive GitHub ### 4. **Test Binary Distribution** (`test-binary-distribution.yml`) ✅ ACTIVE
**Triggers**: Manual dispatch with tarball URL  
**Purpose**: Comprehensive testing of binary distributions

**Features**:
- ✅ Download and verify external tarballs
- ✅ Checksum verification
- ✅ 3dfx device functionality testing
- ✅ Commit ID compatibility verification
- ✅ Signing process simulation
- ✅ Detailed test reporting

### 5. **Legacy Workflows** 🚫 DISABLEDlows for building, testing, packaging, and distributing QEMU with 3dfx Glide and Mesa GL pass-through support across multiple platforms.

## 🔧 Workflow Overview

### 1. **Build and Package (macOS)** (`build-and-package.yml`) ✅ ACTIVE
**Triggers**: Push to master/develop, tags, manual dispatch  
**Purpose**: Complete macOS build and packaging pipeline

**Features**:
- ✅ Multi-architecture builds (ARM64, x86_64)
- ✅ Architecture-optimized builds (Intel builds x86 only, ARM64 builds all)
- ✅ Full QEMU 9.2.2 compilation with 3dfx patches
- ✅ Automatic tarball creation with zstd compression
- ✅ SHA256 checksum generation
- ✅ Commit-based versioning for VM addon compatibility
- ✅ Artifact upload for testing and distribution

**Outputs**:
- `qemu-9.2.2-3dfx-{commit}-darwin-{arch}.tar.zst`
- `qemu-9.2.2-3dfx-{commit}-darwin-{arch}.tar.zst.sha256`
- Staging directories for testing

### 2. **Build for Windows** (`build-windows.yml`) ✅ ACTIVE
**Triggers**: Push to master, pull requests, manual dispatch  
**Purpose**: Complete Windows build pipeline with MSYS2/MinGW

**Features**:
- ✅ Multi-toolchain builds (MINGW64, UCRT64)
- ✅ Matrix build strategy for parallel compilation
- ✅ QEMU 10.0.2 compilation with 3dfx and mesa patches
- ✅ Optional experimental patches (SDL Clipboard)
- ✅ Guest wrapper compilation (3dfx and Mesa)
- ✅ Legacy wrapper disk creation
- ✅ Comprehensive build validation and testing

**Configurations**:
- **windows-build**: Main QEMU compilation for MINGW64 and UCRT64
- **wrappers-mingw32**: Legacy wrapper building with Watcom/DJGPP support

**Inputs** (Manual dispatch):
- `apply_experimental`: Apply experimental patches like SDL Clipboard (boolean)

**Outputs**:
- `qemu-3dfx-windows-{mingw64|ucrt64}-10.0.2-{run_number}`
- `qemu-3dfx-wrappers-{mingw64|ucrt64}-{run_number}`
- `qemu-3dfx-legacy-wrappers-{run_number}`

### 3. **Test and Validate Distribution** (`sign-and-distribute.yml`) ✅ ACTIVE
**Triggers**: Completion of build workflow, manual dispatch  
**Purpose**: Distribution testing and signing preparation (NOT actual signing)

**Features**:
- ✅ Distribution integrity testing (checksum, extraction)
- ✅ Binary functionality validation
- ✅ Signing script validation (syntax, dependencies)
- ✅ Installation process simulation
- ✅ Installation guide generation
- ✅ Architecture-specific testing

**Outputs**:
- Distribution test reports
- Installation guides with usage examples
- Distribution summaries with file listings

**Note**: This workflow does NOT sign binaries. Actual signing is done by end users after installation using the included signing script.

### 4. **Test Binary Distribution** (`test-binary-distribution.yml`) ✅ ACTIVE
**Triggers**: Completion of build workflow, manual dispatch  
**Purpose**: Distribution testing and signing preparation (NOT actual signing)

**Features**:
- ✅ Distribution integrity testing (checksum, extraction)
- ✅ Binary functionality validation
- ✅ Signing script validation (syntax, dependencies)
- ✅ Installation process simulation
- ✅ Installation guide generation
- ✅ Architecture-specific testing

**Outputs**:
- Distribution test reports
- Installation guides with usage examples
- Distribution summaries with file listings

**Note**: This workflow does NOT sign binaries. Actual signing is done by end users after installation using the included signing script.

### 3. **Test Binary Distribution** (`test-binary-distribution.yml`) ✅ ACTIVE
**Triggers**: Manual dispatch with tarball URL  
**Purpose**: Comprehensive testing of binary distributions

**Features**:
- ✅ Download and verify external tarballs
- ✅ Checksum verification
- ✅ 3dfx device functionality testing
- ✅ Commit ID compatibility verification
- ✅ Signing process simulation
- ✅ Detailed test reporting

### 4. **Legacy Workflows** 🚫 DISABLED
The following workflows have been disabled as their functionality is now provided by the active workflows above:

- **`ci.yml`** - Replaced by `build-and-package.yml`
- **`release.yml`** - Replaced by `build-and-package.yml` + `sign-and-distribute.yml`  
- **`release-test.yml`** - Replaced by `build-and-package.yml`
- **`test-build.yml`** - Replaced by `build-and-package.yml`
- **`pr-test.yml`** - PR testing now handled by `build-and-package.yml`

These can be manually enabled via workflow dispatch if needed for debugging.

## 🚀 Usage Guide

### For Developers

#### Running a Complete Build
```bash
# macOS Build - Trigger via GitHub UI or API
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/startergo/qemu-3dfx-macos/actions/workflows/build-and-package.yml/dispatches \
  -d '{"ref":"master","inputs":{"create_release":"false","target_arch":"arm64"}}'

# Windows Build - Trigger via GitHub UI or API
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/startergo/qemu-3dfx-macos/actions/workflows/build-windows.yml/dispatches \
  -d '{"ref":"master","inputs":{"apply_experimental":"false"}}'
```

#### Building with Experimental Features (Windows)
1. Go to Actions → "Build QEMU-3dfx for Windows"
2. Click "Run workflow"
3. Check "Apply experimental patches (SDL Clipboard)"
4. Run the workflow - this will apply the SDL Clipboard patch in addition to the main 3dfx/mesa patches

#### Testing Distribution Workflow
1. Go to Actions → "Test and Validate Distribution"
2. Click "Run workflow"
3. Select architecture: `arm64`, `x86_64`, or `all`
4. The workflow will test the latest successful build artifacts

#### Testing a Binary Distribution
1. Go to Actions → "Test Binary Distribution"
2. Click "Run workflow"
3. Enter the tarball URL (e.g., from a release)
4. Configure test options:
   - `test_installation`: Full installation simulation
   - `test_commit_match`: Verify VM addon compatibility

#### Creating a Release
1. Tag your commit: `git tag v1.0.0 && git push origin v1.0.0`
2. The build workflow will automatically create a GitHub release
3. Or manually trigger with `create_release: true`

### For Users

#### Download and Install

**macOS**:
1. Go to the [Releases page](../../releases)
2. Download the appropriate tarball for your architecture:
   - Apple Silicon: `*-darwin-arm64.tar.zst`
   - Intel: `*-darwin-x86_64.tar.zst`
3. Verify checksum: `shasum -a 256 -c *.sha256`
4. Install: `sudo tar --zstd -xf *.tar.zst -C /`
5. **Sign binaries** (REQUIRED): `cd $(brew --prefix)/sign && bash ./qemu.sign`

**Windows**:
1. Go to the [Actions page](../../actions) → "Build QEMU-3dfx for Windows"
2. Download the appropriate artifact from a successful run:
   - Standard: `qemu-3dfx-windows-mingw64-10.0.2-{run_number}`
   - Universal CRT: `qemu-3dfx-windows-ucrt64-10.0.2-{run_number}`
   - Guest wrappers: `qemu-3dfx-wrappers-{mingw64|ucrt64}-{run_number}`
   - Legacy wrappers: `qemu-3dfx-legacy-wrappers-{run_number}`
3. Extract the archive to your desired location
4. The binaries are ready to use (no additional signing required on Windows)

**Important**: For macOS, Step 5 is where the actual code signing happens. The binaries are unsigned in the distribution and must be signed by each user in their own environment.

## 🔍 Workflow Details

### Environment Variables
- `HOMEBREW_NO_AUTO_UPDATE`: Prevents Homebrew updates during builds
- `HOMEBREW_NO_INSTALL_CLEANUP`: Speeds up dependency installation
- `COMMIT_SHORT`: 7-character commit hash for versioning
- `BUILD_IDENTIFIER`: Used for code signing (e.g., `qemu-3dfx-macos@abc1234`)

### Platform Support

#### macOS
- **ARM64**: Apple Silicon Macs (M1, M2, M3) - Builds all targets (i386, x86_64, aarch64)
- **x86_64**: Intel Macs - Builds x86 targets only (i386, x86_64) for efficiency
- **Cross-compilation**: ARM64 runners can build for all architectures
- **Code Signing**: Required post-installation by end users

#### Windows
- **MINGW64**: Standard MinGW 64-bit builds with wide compatibility
- **UCRT64**: Universal C Runtime builds for Windows 10+ environments
- **MINGW32**: Legacy 32-bit wrapper building with Watcom/DJGPP support
- **Guest Wrappers**: DOS/Windows 9x/XP compatible graphics wrappers
- **Experimental Features**: Optional SDL Clipboard support and future enhancements

### Build Process

#### macOS Build Process
1. **Checkout**: Full git history for commit tracking
2. **Dependencies**: Install Homebrew packages and build tools
3. **Source**: Download QEMU 9.2.2 source
4. **Patch**: Apply 3dfx/mesa overlays and patches
5. **Build**: Compile with architecture-optimized target lists
6. **Package**: Create directory structure and tarball with unsigned binaries
7. **Prepare Signing**: Include signing script with current commit ID
8. **Upload**: Store artifacts for testing and distribution

**Note**: macOS binaries are distributed unsigned and must be signed by end users.

#### Windows Build Process
1. **Checkout**: Repository with all patches and experimental features
2. **MSYS2 Setup**: Install MinGW toolchains and dependencies
3. **Source**: Download QEMU 10.0.2 source
4. **Patch Application**: Apply 3dfx/mesa patches + optional experimental patches
5. **QEMU Build**: Compile for i386-softmmu and x86_64-softmmu targets
6. **Guest Wrappers**: Build DOS/Windows graphics wrappers
7. **ISO Creation**: Package wrappers into bootable disk images
8. **Upload**: Store ready-to-use binaries and wrapper disks

**Note**: Windows binaries are ready to use without additional signing.

### Testing Strategy
- **Build Tests**: Architecture-optimized compilation validation
- **Distribution Tests**: Binary package validation and functionality
- **Installation Tests**: End-to-end user experience simulation
- **Signing Tests**: Signing script validation (syntax, dependencies)
- **Compatibility Tests**: VM addon version matching

**Note**: Testing validates the signing process but does not perform actual signing.

## 🔧 Configuration

### Workflow Inputs

#### Build and Package (macOS)
- `create_release`: Create GitHub release (boolean)
- `target_arch`: Architecture to build (arm64/x86_64/universal)

#### Build for Windows  
- `apply_experimental`: Apply experimental patches like SDL Clipboard (boolean)

#### Test and Validate Distribution
- `artifact_name`: Specific artifact to process (string)
- `architecture`: Target architecture (arm64/x86_64/all)

#### Test Binary Distribution
- `tarball_url`: URL to test tarball (string)
- `test_installation`: Full installation test (boolean)
- `test_commit_match`: VM addon compatibility test (boolean)

### Secrets Required
- `GITHUB_TOKEN`: Automatically provided by GitHub
- No additional secrets needed for basic functionality

### Dependencies

#### macOS Requirements
- **macOS runners**: Required for native builds and signing
- **Homebrew**: Package management and dependency installation
- **Xcode tools**: Code signing and development tools
- **XQuartz**: X11 support for graphics acceleration

#### Windows Requirements
- **Windows 2019 runners**: Stable MSYS2 environment
- **MSYS2**: MinGW development environment
- **MinGW toolchains**: MINGW64, UCRT64, MINGW32 compilers
- **Development tools**: Watcom, DJGPP for legacy wrapper building
- **Build tools**: Git, Make, Ninja, patch utilities

## 📊 Monitoring and Debugging

### Artifact Retention
- **Build artifacts**: 30 days
- **Test artifacts**: 7 days
- **Installation guides**: 90 days

### Log Analysis
Each workflow step includes detailed logging:
- ✅ Success indicators
- ⚠️ Warning messages
- ❌ Error conditions
- ℹ️ Informational status

### Common Issues
1. **Missing test-ci.sh**: Legacy workflows disabled - use build-and-package.yml instead
2. **Binary naming (-unsigned suffix)**: Modern QEMU creates unsigned binaries, workflows handle this automatically  
3. **Architecture mismatches**: Verify runner compatibility and target architecture
4. **Dependency errors**: Review Homebrew package availability
5. **Build timeouts**: Optimized builds should complete within 2 hours
6. **Signing failures**: Users must sign binaries after installation in their own environment

## 🛠 Maintenance

### Updating QEMU Version
1. Update patch file references in workflows (macOS: 9.2.2, Windows: 10.0.2)
2. Modify download URLs in build scripts
3. Update experimental patch compatibility (Windows)
4. Test compatibility with new QEMU features
5. Update version strings in documentation

### Adding Experimental Features (Windows)
1. Add new patches to `qemu-exp/` directory
2. Update experimental patch application logic in `build-windows.yml`
3. Document new features in `qemu-exp/README.md`
4. Test patch compatibility across QEMU versions

### Adding New Architectures
1. Update build matrix in `build-and-package.yml`
2. Add architecture-specific configurations
3. Update artifact naming conventions
4. Test cross-compilation scenarios

### Security Updates
1. Regularly update action versions (`@v4`, etc.)
2. Monitor for security advisories
3. Update dependency versions in brew installs
4. Review code signing certificate requirements

## 🤝 Contributing

1. **Fork** the repository
2. **Branch** from `develop`
3. **Test** changes with workflow dispatch
4. **Document** any workflow modifications
5. **Submit** pull request with detailed description

### Workflow Testing
- Use `workflow_dispatch` for manual testing
- Test on both ARM64 and x86_64 if possible
- Verify artifact outputs and naming
- Check integration with existing workflows

---

**Platform Support**: These workflows support both macOS and Windows environments:
- **macOS**: Native builds with Homebrew, code signing requirements, architecture optimization
- **Windows**: MSYS2/MinGW builds with guest wrapper support and experimental features
- **Linux**: Not currently supported but could be adapted from the Windows MSYS2 approach

For questions about cross-platform compatibility or adding Linux support, please see the project documentation or open an issue.
