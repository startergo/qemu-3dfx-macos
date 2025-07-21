#!/bin/bash

# Test script for Homebrew QEMU 3dfx tap
# Validates that formulae are syntactically correct and dependencies resolve

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAP_DIR="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test formula syntax
test_formula_syntax() {
    local formula="$1"
    log_info "Testing syntax for $formula..."
    
    if brew audit --formula "$TAP_DIR/Formula/$formula" 2>/dev/null; then
        log_success "$formula syntax is valid"
        return 0
    else
        log_error "$formula syntax has issues"
        return 1
    fi
}

# Test formula dependencies
test_formula_deps() {
    local formula="$1"
    log_info "Testing dependencies for $formula..."
    
    # Use brew deps to check dependency resolution
    if brew deps --formula "$TAP_DIR/Formula/$formula" >/dev/null 2>&1; then
        log_success "$formula dependencies resolve correctly"
        return 0
    else
        log_warning "$formula may have dependency issues"
        return 1
    fi
}

# Test formula installation (dry run)
test_formula_install() {
    local formula="$1"
    log_info "Testing installation for $formula (dry run)..."
    
    # This doesn't actually install, just checks if it would work
    if brew install --dry-run "$TAP_DIR/Formula/$formula" >/dev/null 2>&1; then
        log_success "$formula would install successfully"
        return 0
    else
        log_warning "$formula installation may have issues"
        return 1
    fi
}

# Main test function
run_tests() {
    log_info "Starting Homebrew tap tests..."
    
    local formulae=("qemu-3dfx.rb" "virglrenderer-3dfx.rb" "glide-3dfx.rb")
    local total_tests=0
    local passed_tests=0
    
    for formula in "${formulae[@]}"; do
        log_info "Testing formula: $formula"
        
        # Test syntax
        if test_formula_syntax "$formula"; then
            ((passed_tests++))
        fi
        ((total_tests++))
        
        # Test dependencies
        if test_formula_deps "$formula"; then
            ((passed_tests++))
        fi
        ((total_tests++))
        
        # Test installation dry run
        if test_formula_install "$formula"; then
            ((passed_tests++))
        fi
        ((total_tests++))
        
        echo
    done
    
    # Summary
    log_info "Test Summary: $passed_tests/$total_tests tests passed"
    
    if [ $passed_tests -eq $total_tests ]; then
        log_success "All tests passed!"
        return 0
    else
        log_warning "Some tests failed or had warnings"
        return 1
    fi
}

# Validate tap structure
validate_tap_structure() {
    log_info "Validating tap structure..."
    
    # Check required directories
    if [ ! -d "$TAP_DIR/Formula" ]; then
        log_error "Formula directory missing"
        return 1
    fi
    
    # Check for formulae
    local formulae_count=$(find "$TAP_DIR/Formula" -name "*.rb" | wc -l)
    if [ $formulae_count -eq 0 ]; then
        log_error "No formulae found in Formula directory"
        return 1
    fi
    
    log_success "Found $formulae_count formulae in tap"
    
    # Check for README
    if [ -f "$TAP_DIR/README.md" ]; then
        log_success "README.md found"
    else
        log_warning "README.md missing"
    fi
    
    return 0
}

# Check Homebrew environment
check_homebrew() {
    log_info "Checking Homebrew environment..."
    
    if ! command -v brew &> /dev/null; then
        log_error "Homebrew not found"
        return 1
    fi
    
    local brew_version=$(brew --version | head -1)
    log_success "Homebrew found: $brew_version"
    
    return 0
}

# Show usage
show_usage() {
    cat << EOF
QEMU 3dfx Homebrew Tap Test Script

USAGE:
    $0 [OPTION]

OPTIONS:
    test        Run all tests (default)
    validate    Validate tap structure only
    syntax      Test formula syntax only
    deps        Test formula dependencies only
    help        Show this help

DESCRIPTION:
    This script validates the Homebrew tap formulae for QEMU 3dfx.
    It checks syntax, dependencies, and installation feasibility.

EOF
}

# Main script logic
case "${1:-test}" in
    test)
        check_homebrew && validate_tap_structure && run_tests
        ;;
    validate)
        validate_tap_structure
        ;;
    syntax)
        for formula in qemu-3dfx.rb virglrenderer-3dfx.rb glide-3dfx.rb; do
            test_formula_syntax "$formula"
        done
        ;;
    deps)
        for formula in qemu-3dfx.rb virglrenderer-3dfx.rb glide-3dfx.rb; do
            test_formula_deps "$formula"
        done
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        log_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac
