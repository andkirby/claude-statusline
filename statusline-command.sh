#!/usr/bin/env bash
# Statusline for Claude Code
# Bar: [PP%████NNNk] — 10 slots: percentage (left), visual bar (middle), context size (right)
# Env vars:
#   STATUSLINE_COST=true|1   Show cost block (default: hidden)
# Shows a 🤖 badge with .agent.name when the session runs as an agent/teammate.

input=$(cat)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib-context-bar.sh" ]; then
    # shellcheck source=lib-context-bar.sh
    . "$SCRIPT_DIR/lib-context-bar.sh"
else
    # Minimal fallback if the shared library is missing
    ESC=$(printf '\033'); CYAN="${ESC}[36m"; GREEN="${ESC}[32m"; YELLOW="${ESC}[33m"; ORANGE="${ESC}[38;5;208m"; RED="${ESC}[31m"; WHITE="${ESC}[97m"; MAGENTA="${ESC}[35m"; RESET="${ESC}[0m"
    build_context_bar() { printf '%s%%' "$1"; }
    fmt_tokens() { printf '%sk' "$(($1 / 1000))"; }
    fmt_elapsed() { printf '%dm' "$((($1 % 3600000) / 60000))"; }
fi

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
USED_TOKENS=$(echo "$input" | jq -r '.context_window.used_tokens // 0')
TOTAL_TOKENS=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
AGENT=$(echo "$input" | jq -r '.agent.name // empty')

BAR=$(build_context_bar "$PCT" "$USED_TOKENS" "$TOTAL_TOKENS")

HOURS=$((DURATION_MS / 3600000))
MINS=$(((DURATION_MS % 3600000) / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))

BRANCH=""
git rev-parse --git-dir > /dev/null 2>&1 && BRANCH=" | 🌿 $(git branch --show-current 2>/dev/null)"

# Agent/teammate badge: shown when Claude Code reports .agent.name
AGENT_BLOCK=""
[ -n "$AGENT" ] && AGENT_BLOCK=" 🤖 ${MAGENTA}${AGENT}${RESET}"

echo -ne "\033[1;38;5;30m${MODEL}${RESET}${AGENT_BLOCK} 📁 ${DIR##*/}$BRANCH | "

# Cost block: shown only when STATUSLINE_COST=true|1
COST_BLOCK=""
case "${STATUSLINE_COST}" in
    true|1) COST_BLOCK=" | 💰 ${YELLOW}$(printf '$%.2f' "$COST")${RESET}" ;;
esac

if [ "$HOURS" -gt 0 ]; then
    echo -e "${BAR}${COST_BLOCK} | ⏱️ ${HOURS}h ${MINS}m"
elif [ "$MINS" -gt 10 ]; then
    echo -e "${BAR}${COST_BLOCK} | ⏱️ ${MINS}m"
else
    echo -e "${BAR}${COST_BLOCK} | ⏱️ ${MINS}m ${SECS}s"
fi
