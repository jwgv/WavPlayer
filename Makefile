# Makefile to install Homebrew and required packages on macOS
# Requirements for wavplayer.sh:
# - ffmpeg: decoding and seeking for many formats
# - sox (provides `play`): audio playback
# Note: `afinfo` comes with macOS and is used for duration; no install needed.

# Makefile - works on macOS Bash 3.2.57 (10.15 and older) AND modern systems
.ONESHELL:
SHELL = /bin/bash

BIN_DIR ?= $(HOME)/.local/bin

install-brew:
	@echo "Checking for Homebrew..."
	if command -v brew >/dev/null 2>&1 || \
	   [ -x "/opt/homebrew/bin/brew" ] || \
	   [ -x "/usr/local/bin/brew" ]; then \
		echo "Homebrew is already installed."; \
	else \
		echo "Homebrew not found. Installing..."; \
		echo "You may be prompted for your password."; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || exit $$?; \
		if ! command -v brew >/dev/null 2>&1; then \
			if [ -x "/opt/homebrew/bin/brew" ]; then \
				echo "Homebrew installed to /opt/homebrew (Apple Silicon)."; \
				echo "Run: eval \"\$$(/opt/homebrew/bin/brew shellenv)\" to add it to PATH now."; \
			elif [ -x "/usr/local/bin/brew" ]; then \
				echo "Homebrew installed to /usr/local (Intel)."; \
				echo "Run: eval \"\$$(/usr/local/bin/brew shellenv)\" to add it to PATH now."; \
			fi \
		fi \
	fi

install-packages: install-brew
	@BREW=""; \
	for candidate in "/opt/homebrew/bin/brew" "/usr/local/bin/brew"; do \
	    [ -x "$$candidate" ] && BREW="$$candidate" && break; \
	done; \
	if [ -z "$$BREW" ] && command -v brew >/dev/null 2>&1; then \
	    BREW="$$(command -v brew)"; \
	fi; \
	if [ -z "$$BREW" ]; then \
	    echo "Error: Homebrew not found even after installation."; \
	    echo "Add it to your PATH manually and re-run."; \
	    exit 1; \
	fi; \
	echo "Using Homebrew at: $$BREW"; \
	"$$BREW" update >/dev/null 2>&1 || true; \
	"$$BREW" install ffmpeg sox

install-script:
	@mkdir -p "$(BIN_DIR)"
	@cp -f wavplayer.sh "$(BIN_DIR)/wavplayer.sh"
	@chmod +x "$(BIN_DIR)/wavplayer.sh"
	@echo "Installed wavplayer.sh to $(BIN_DIR)/"
	@if echo ":$$PATH:" | grep -q ":$(BIN_DIR):"; then \
	    echo "$(BIN_DIR) is already on your PATH."; \
	else \
	    echo "Add $(BIN_DIR) to your PATH with:"; \
	    echo '    export PATH="$(BIN_DIR):$$PATH"'; \
	    echo "Put that line in ~/.zprofile or ~/.bash_profile and restart terminal."; \
	fi

install: install-packages install-script
	@echo "Installation complete!"

all: install

.PHONY: install-brew install-packages install-script install all