#!/bin/bash

set -e

BASE_URL="https://raw.githubusercontent.com/andkirby/claude-statusline/main"
INSTALL_DIR="$HOME/.claude/statusline"
SETTINGS_FILE="$HOME/.claude/settings.json"
FORCE=0
[ "$1" = "--force" ] && FORCE=1

# statusline-command.sh and subagent-statusline.sh need the shared library
FILES="statusline-command.sh subagent-statusline.sh lib-context-bar.sh"

echo "Installing Claude Code Statusline..."

mkdir -p "$INSTALL_DIR"

# Download missing scripts (or all with --force); keep existing local copies otherwise
for FILE in $FILES; do
  TARGET="$INSTALL_DIR/$FILE"
  if [ -f "$TARGET" ] && [ "$FORCE" -eq 0 ]; then
    echo "Using local $FILE (use --force to re-download)..."
  else
    echo "Downloading $FILE..."
    curl -fsSL "$BASE_URL/$FILE" -o "$TARGET"
  fi
  chmod +x "$TARGET"
done

# Register both statuslines in settings.json
TMP=$(mktemp)

STATUSLINE_CMD='$HOME/.claude/statusline/statusline-command.sh'
SUBAGENT_CMD='$HOME/.claude/statusline/subagent-statusline.sh'

if [ -f "$SETTINGS_FILE" ]; then
  echo "Updating settings.json..."
  jq --arg cmd "$STATUSLINE_CMD" --arg sub "$SUBAGENT_CMD" \
    '.statusLine = {"type": "command", "command": $cmd} | .subagentStatusLine = {"type": "command", "command": $sub}' \
    "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
else
  echo "Creating settings.json..."
  printf '{"statusLine": {"type": "command", "command": "%s"}, "subagentStatusLine": {"type": "command", "command": "%s"}}\n' \
    "$STATUSLINE_CMD" "$SUBAGENT_CMD" > "$SETTINGS_FILE"
fi

echo ""
echo "Statusline installed successfully!"
echo "Restart Claude Code to see it."
echo "Teammates/subagents get their own statusline rows in the agent panel."
