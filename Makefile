.PHONY: all build install run test clean help xcode

APP_NAME := Launchpad
BUILD_DIR := build/$(APP_NAME).app
INSTALL_DIR := $(HOME)/Applications/$(APP_NAME).app

all: help

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the app binary
	@echo "🔨 Building $(APP_NAME)..."
	./build-app.sh

install: ## Build and install to ~/Applications
	@bash ./install.sh

run: ## Open the installed app
	@open "$(INSTALL_DIR)" 2>/dev/null || open "/Applications/$(APP_NAME).app" 2>/dev/null || open "$(BUILD_DIR)"

xcode: ## Open Package.swift in Xcode
	@open Package.swift

test: ## Run all tests
	@echo "🧪 Running tests..."
	@swift test

test-filter: ## Run specific test (use TEST=TestName)
	@swift test --filter $(TEST)

clean: ## Remove build artifacts
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf build/
	@rm -rf .build/
	@echo "✅ Cleaned"

reinstall: ## Rebuild and replace the installed app safely
	@echo "🔄 Reinstalling $(APP_NAME)..."
	@$(MAKE) install
