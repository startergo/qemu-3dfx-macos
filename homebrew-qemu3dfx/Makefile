.PHONY: test install clean lint audit help

# Default target
all: test

# Test all formulae
test:
	@echo "Running tap tests..."
	./test-tap.sh test

# Test formula syntax only
syntax:
	@echo "Testing formula syntax..."
	./test-tap.sh syntax

# Test formula dependencies
deps:
	@echo "Testing formula dependencies..."
	./test-tap.sh deps

# Validate tap structure
validate:
	@echo "Validating tap structure..."
	./test-tap.sh validate

# Install the tap locally for testing
install:
	@echo "Installing tap locally..."
	brew tap startergo/qemu3dfx .

# Uninstall the tap
uninstall:
	@echo "Uninstalling tap..."
	brew untap startergo/qemu3dfx

# Clean up test artifacts
clean:
	@echo "Cleaning up..."
	rm -rf test-output/
	rm -rf build-test/
	rm -f *.log

# Lint Ruby files
lint:
	@echo "Linting Ruby files..."
	@for formula in Formula/*.rb; do \
		echo "Linting $$formula..."; \
		ruby -c "$$formula" || echo "Syntax error in $$formula"; \
	done

# Audit formulae
audit:
	@echo "Auditing formulae..."
	@for formula in Formula/*.rb; do \
		echo "Auditing $$formula..."; \
		brew audit --formula "$$formula" || echo "Audit issues in $$formula"; \
	done

# Install individual components
install-virgl:
	brew install ./Formula/virglrenderer-3dfx.rb

install-glide:
	brew install ./Formula/glide-3dfx.rb

install-qemu:
	brew install ./Formula/qemu-3dfx.rb

# Test individual components
test-virgl:
	brew test virglrenderer-3dfx

test-glide:
	brew test glide-3dfx

test-qemu:
	brew test qemu-3dfx

# Show help
help:
	@echo "Available targets:"
	@echo "  test        - Run all tests"
	@echo "  syntax      - Test formula syntax"
	@echo "  deps        - Test formula dependencies"
	@echo "  validate    - Validate tap structure"
	@echo "  install     - Install tap locally"
	@echo "  uninstall   - Uninstall tap"
	@echo "  clean       - Clean up test artifacts"
	@echo "  lint        - Lint Ruby files"
	@echo "  audit       - Audit formulae"
	@echo "  install-*   - Install individual components"
	@echo "  test-*      - Test individual components"
	@echo "  help        - Show this help"
