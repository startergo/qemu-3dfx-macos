# GitHub Actions Workflows for QEMU 3dfx

This directory contains comprehensive GitHub Actions workflows for building, testing, packaging, and distributing QEMU with 3dfx Glide and Mesa GL pass-through support.

## 🔧 Workflow Overview

### 1. **Build and Package** (`build-and-package.yml`)
**Triggers**: Push to main/develop, tags, manual dispatch
**Purpose**: Complete build and packaging pipeline

**Features**:
- ✅ Multi-architecture builds (ARM64, x86_64)
- ✅ Full QEMU 9.2.2 compilation with 3dfx patches
- ✅ Automatic tarball creation with zstd compression
- ✅ SHA256 checksum generation
- ✅ Commit-based versioning for VM addon compatibility
- ✅ Artifact upload for testing and distribution

**Outputs**:
- `qemu-9.2.2-3dfx-{commit}-darwin-{arch}.tar.zst`
- `qemu-9.2.2-3dfx-{commit}-darwin-{arch}.tar.zst.sha256`
- Staging directories for testing

### 2. **Sign and Distribute** (`sign-and-distribute.yml`)
**Triggers**: Completion of build workflow, manual dispatch
**Purpose**: Sign binaries and prepare for distribution

**Features**:
- ✅ Automated code signing with macOS tools
- ✅ Installation testing in isolated environment
- ✅ Comprehensive distribution validation
- ✅ Installation guide generation
- ✅ Architecture-specific testing

**Outputs**:
- Signed and verified distributions
- Installation guides with usage examples
- Distribution summaries with file listings

### 3. **Test Binary Distribution** (`test-binary-distribution.yml`)
**Triggers**: Manual dispatch with tarball URL
**Purpose**: Comprehensive testing of binary distributions

**Features**:
- ✅ Download and verify external tarballs
- ✅ Checksum verification
- ✅ 3dfx device functionality testing
- ✅ Commit ID compatibility verification
- ✅ Signing process simulation
- ✅ Detailed test reporting

### 4. **CI Pipeline** (`ci.yml`)
**Triggers**: Pull requests, pushes
**Purpose**: Continuous integration testing

**Features**:
- ✅ Step-by-step build verification
- ✅ Environment validation
- ✅ Code quality checks
- ✅ Integration with existing workflows

### 5. **Test Build Environment** (`test-build.yml`)
**Triggers**: Push, PR, manual dispatch
**Purpose**: Quick environment and dependency testing

**Features**:
- ✅ Fast environment validation
- ✅ Dependency installation testing
- ✅ Build tool verification
- ✅ Optional full build testing

## 🚀 Usage Guide

### For Developers

#### Running a Complete Build
```bash
# Trigger via GitHub UI or API
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/startergo/qemu-3dfx-macos/actions/workflows/build-and-package.yml/dispatches \
  -d '{"ref":"main","inputs":{"create_release":"false","target_arch":"arm64"}}'
```

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
1. Go to the [Releases page](../../releases)
2. Download the appropriate tarball for your architecture:
   - Apple Silicon: `*-darwin-arm64.tar.zst`
   - Intel: `*-darwin-x86_64.tar.zst`
3. Verify checksum: `shasum -a 256 -c *.sha256`
4. Install: `sudo tar --zstd -xf *.tar.zst -C /`
5. Sign: `cd $(brew --prefix)/sign && bash ./qemu.sign`

## 🔍 Workflow Details

### Environment Variables
- `HOMEBREW_NO_AUTO_UPDATE`: Prevents Homebrew updates during builds
- `HOMEBREW_NO_INSTALL_CLEANUP`: Speeds up dependency installation
- `COMMIT_SHORT`: 7-character commit hash for versioning
- `BUILD_IDENTIFIER`: Used for code signing (e.g., `qemu-3dfx-macos@abc1234`)

### Architecture Support
- **ARM64**: Apple Silicon Macs (M1, M2, M3)
- **x86_64**: Intel Macs
- **Universal**: Combined binary (future enhancement)

### Build Process
1. **Checkout**: Full git history for commit tracking
2. **Dependencies**: Install Homebrew packages and build tools
3. **Source**: Download QEMU 9.2.2 source
4. **Patch**: Apply 3dfx/mesa overlays and patches
5. **Build**: Compile with architecture-specific optimizations
6. **Package**: Create directory structure and tarball
7. **Sign**: Update signing script with current commit
8. **Upload**: Store artifacts for testing and distribution

### Testing Strategy
- **Unit Tests**: Individual component verification
- **Integration Tests**: Complete build pipeline testing
- **Distribution Tests**: Binary package validation
- **Installation Tests**: End-to-end user experience
- **Compatibility Tests**: VM addon version matching

## 🔧 Configuration

### Workflow Inputs

#### Build and Package
- `create_release`: Create GitHub release (boolean)
- `target_arch`: Architecture to build (arm64/x86_64/universal)

#### Sign and Distribute
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
- **macOS runners**: Required for native builds and signing
- **Homebrew**: Package management and dependency installation
- **Xcode tools**: Code signing and development tools
- **XQuartz**: X11 support for graphics acceleration

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
1. **Signing failures**: Check Xcode tools installation
2. **Architecture mismatches**: Verify runner compatibility
3. **Dependency errors**: Review Homebrew package availability
4. **Build timeouts**: Consider workflow timeout adjustments

## 🛠 Maintenance

### Updating QEMU Version
1. Update patch file references in workflows
2. Modify download URLs in build scripts
3. Test compatibility with new QEMU features
4. Update version strings in documentation

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

**Note**: These workflows are specifically designed for macOS environments due to the nature of 3dfx/Mesa graphics acceleration and code signing requirements. Linux and Windows builds would require significant modifications.
