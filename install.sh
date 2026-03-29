#!/bin/bash

set -e

REPO_URL="https://raw.githubusercontent.com/andkirby/claude-statusline/main/statusline-command.sh"
SCRIPT_PATH="$HOME/.claude/statusline/statusline-command.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "Installing Claude Code Statusline..."

# Create directory
mkdir -p "$(dirname "$SCRIPT_PATH")"

# Download or use local script
if [ -f "$SCRIPT_PATH" ]; then
  echo "Using local statusline script..."
else
  echo "Downloading statusline script..."
  curl -fsSL "$REPO_URL" -o "$SCRIPT_PATH"
fi
chmod +x "$SCRIPT_PATH"

# Update settings.json
TMP=$(mktemp)

STATUSLINE_CMD='$HOME/.claude/statusline/statusline-command.sh'

if [ -f "$SETTINGS_FILE" ]; then
  echo "Updating settings.json..."
  jq --arg cmd "$STATUSLINE_CMD" '.statusLine = {"type": "command", "command": $cmd}' "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
else
  echo "Creating settings.json..."
  echo "{\"statusLine\": {\"type\": \"command\", \"command\": \"$STATUSLINE_CMD\"}}" > "$SETTINGS_FILE"
fi

echo ""
echo "Statusline installed successfully!"
echo "Restart Claude Code to see it."
