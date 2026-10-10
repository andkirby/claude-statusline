#!/usr/bin/env bash
# Statusline for Claude Code
# Bar: [PP%████NNNk] — 10 slots: percentage (left), visual bar (middle), context size (right)
# Env vars:
#   STATUSLINE_COST=true|1   Show cost block (default: hidden)
# Shows a 🤖 badge with .agent.name when the session runs as an agent/teammate.

# Slurp stdin with a builtin (no cat subprocess); read returns non-zero at EOF
input=''
IFS= read -r -d '' input || true

_src="${BASH_SOURCE[0]:-$0}"
case "$_src" in
    */*) SCRIPT_DIR="$(cd "${_src%/*}" && pwd)" ;;
    *)   SCRIPT_DIR="$PWD" ;;
esac
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
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')

BAR=$(build_context_bar "$PCT" "$USED_TOKENS" "$TOTAL_TOKENS")

HOURS=$((DURATION_MS / 3600000))
MINS=$(((DURATION_MS % 3600000) / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))

BRANCH=""
git rev-parse --git-dir > /dev/null 2>&1 && BRANCH=" | 🌿 $(git branch --show-current 2>/dev/null)"

# Agent/teammate badge, resolved in three tiers:
#   1. Inside a teammate's tmux pane: $TMUX_PANE matches members[].tmuxPaneId
#      in ~/.claude/teams/*/config.json -> the teammate's real name (the
#      payload's .agent.name only carries the generic agent TYPE there).
#   2. .agent.name from the payload (agent sessions without a matching pane).
#   3. Lead bar: active teammates from the team roster keyed by this
#      session's id (team dir = session-<first 8 chars of session_id>).
AGENT_BLOCK=""
TEAMMATE_NAME=""
if [ -n "$TMUX_PANE" ]; then
    # Multiple team configs can carry the same tmuxPaneId (pane ids are
    # reused across sessions); prefer the most recently modified config,
    # since live teams get rewritten on member activity.
    BEST=""
    while IFS= read -r MATCH; do
        [ -z "$MATCH" ] && continue
        NAME=$(jq -r --arg pane "$TMUX_PANE" --arg dir "$DIR" \
            '.members[]? | select(.tmuxPaneId == $pane and .cwd == $dir) | .name' "$MATCH" | head -1)
        [ -z "$NAME" ] && continue
        if [ -z "$BEST" ] || [ "$MATCH" -nt "$BEST" ]; then
            BEST="$MATCH"
            TEAMMATE_NAME="$NAME"
        fi
    done <<< "$(grep -lF -- "$TMUX_PANE" "$HOME"/.claude/teams/*/config.json 2>/dev/null)"
fi

if [ -n "$TEAMMATE_NAME" ]; then
    AGENT_BLOCK=" 🤖 ${MAGENTA}${TEAMMATE_NAME}${RESET}"
elif [ -n "$AGENT" ]; then
    AGENT_BLOCK=" 🤖 ${MAGENTA}${AGENT}${RESET}"
else
    TEAM_DIR="$HOME/.claude/teams/session-${SESSION_ID:0:8}"
    if [ -f "$TEAM_DIR/config.json" ]; then
        ACTIVE_TEAMMATES=$(jq -r '[.members[]? | select(.isActive == true and .agentType != "team-lead") | .name] | join(", ")' "$TEAM_DIR/config.json" 2>/dev/null)
        [ -n "$ACTIVE_TEAMMATES" ] && AGENT_BLOCK=" 🤖 ${MAGENTA}${ACTIVE_TEAMMATES}${RESET}"
    fi
fi

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
