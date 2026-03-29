#!/bin/bash

set -e

REPO_URL="https://raw.githubusercontent.com/andkirby/agent-cli-statusline/main/statusline-command.sh"
SCRIPT_PATH="$HOME/.claude/statusline/statusline-command.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "Installing Claude Code Statusline..."

# Create directory
mkdir -p "$(dirname "$SCRIPT_PATH")"

# Download the script
echo "Downloading statusline script..."
curl -fsSL "$REPO_URL" -o "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"

# Update settings.json
TMP=$(mktemp)

if [ -f "$SETTINGS_FILE" ]; then
  echo "Updating settings.json..."
  jq '.statusLine = {"type": "command", "command": "~/.claude/statusline/statusline-command.sh"}' "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
else
  echo "Creating settings.json..."
  echo '{"statusLine": {"type": "command", "command": "~/.claude/statusline/statusline-command.sh"}}' > "$SETTINGS_FILE"
fi

echo ""
echo "Statusline installed successfully!"
echo "Restart Claude Code to see it."
