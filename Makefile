# Makefile to install Homebrew and required packages on macOS
# Requirements for wavplayer.sh:
# - ffmpeg: decoding and seeking for many formats
# - sox (provides `play`): audio playback
# Note: `afinfo` comes with macOS and is used for duration; no install needed.

# Where to install the script (override with: make BIN_DIR=/some/path install)
BIN_DIR ?= $(HOME)/.local/bin

install-brew:
	@echo "Checking for Homebrew... (Follow prompts if installation is needed)"
	@which brew > /dev/null || NONINTERACTIVE=1 /bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

install-packages: install-brew
	@brew install ffmpeg sox

# Install the wavplayer.sh script into user's local bin and make it executable
install-script:
	@mkdir -p "$(BIN_DIR)"
	@cp -f wavplayer.sh "$(BIN_DIR)/wavplayer.sh"
	@chmod +x "$(BIN_DIR)/wavplayer.sh"
	@echo "Installed script to $(BIN_DIR)/wavplayer.sh"

# Convenience alias (deps + script)
install: install-packages install-script

all: install-packages install-script

.PHONY: install-brew install-packages install-script install all