#!/usr/bin/env bash
# Subagent/teammate statusline for Claude Code (subagentStatusLine setting).
# Receives on stdin: base hook fields + `columns` + `tasks[]` (one entry per
# visible agent-panel row: subagents AND teammates).
# Writes one {"id": "...", "content": "..."} JSON line per row to stdout;
# rows whose id is not emitted keep the default rendering.
#
# Task fields (all guarded, some are version-dependent and may be absent):
#   id, name?, type, agentType? (v2.1.293+), status, description, label,
#   startTime, model?, effort?, contextWindowSize?, tokenCount, tokenSamples[], cwd
#
# Env vars:
#   STATUSLINE_SUBAGENT_DESC=false|0   Hide task description (default: shown when it fits)

input=$(cat)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -f "$SCRIPT_DIR/lib-context-bar.sh" ]; then
    # shellcheck source=lib-context-bar.sh
    . "$SCRIPT_DIR/lib-context-bar.sh"
else
    # Minimal fallback if the shared library is missing
    ESC=$(printf '\033'); GREEN="${ESC}[32m"; DARKGREEN="${ESC}[38;5;22m"; YELLOW="${ESC}[33m"; RED="${ESC}[31m"; WHITE="${ESC}[97m"; GRAY="${ESC}[90m"; RESET="${ESC}[0m"
    build_context_bar() { printf '%s%%' "$1"; }
    fmt_tokens() { printf '%sk' "$(($1 / 1000))"; }
    fmt_elapsed() { printf '%dm' "$((($1 % 3600000) / 60000))"; }
fi

COLUMNS_WIDTH=$(echo "$input" | jq -r '.columns // 80')
NOW_MS=$(date +%s)000

# Status icon and color
status_style() {
    case "$1" in
        running)   printf '%s' "▶ ${GREEN}" ;;
        completed) printf '%s' "✓ ${DARKGREEN}" ;;
        failed)    printf '%s' "✗ ${RED}" ;;
        killed)    printf '%s' "✕ ${GRAY}" ;;
        pending)   printf '%s' "◔ ${YELLOW}" ;;
        *)         printf '%s' "· ${WHITE}" ;;
    esac
}

echo "$input" | jq -c '(.tasks // [])[]?' | while IFS= read -r task; do
    ID=$(echo "$task" | jq -r '.id')
    NAME=$(echo "$task" | jq -r '.name // .agentType // (.description // "agent")' | head -c 40)
    STATUS=$(echo "$task" | jq -r '.status // ""')
    MODEL=$(echo "$task" | jq -r '.model // empty' | sed 's/^claude-//')
    TOKEN_COUNT=$(echo "$task" | jq -r '.tokenCount // 0')
    CTX_SIZE_TOK=$(echo "$task" | jq -r '.contextWindowSize // 0')
    START_MS=$(echo "$task" | jq -r '.startTime // 0')
    DESC=$(echo "$task" | jq -r '.label // .description // empty')

    read -r ICON ICON_COLOR <<< "$(status_style "$STATUS")"

    # Per-teammate context bar, same visual language as the main bar
    BAR=""
    if [ "$CTX_SIZE_TOK" -gt 0 ] 2>/dev/null; then
        PCT=$((TOKEN_COUNT * 100 / CTX_SIZE_TOK))
        [ "$PCT" -gt 100 ] && PCT=100
        [ "$PCT" -lt 0 ] && PCT=0
        BAR=$(build_context_bar "$PCT" "$TOKEN_COUNT" "$CTX_SIZE_TOK")
    fi

    TOKENS=$(fmt_tokens "$TOKEN_COUNT")
    ELAPSED=""
    if [ "$START_MS" -gt 0 ] 2>/dev/null; then
        ELAPSED=$(fmt_elapsed $((NOW_MS - START_MS)))
    fi

    # Assemble on plain text first so widths exclude ANSI bytes
    CORE="${ICON} ${NAME}"
    [ -n "$BAR" ] && CORE="${CORE} ${BAR}"
    INFO="${TOKENS}"
    [ -n "$ELAPSED" ] && INFO="${INFO} ${ELAPSED}"
    CORE="${CORE} ${INFO}"

    LINE="${ICON_COLOR}${CORE}${RESET}"
    BAR_PLAIN=0
    [ -n "$BAR" ] && BAR_PLAIN=10   # bar is always 10 visible slots; ${#BAR} would count ANSI bytes
    PLAIN_LEN=$((1 + 1 + ${#NAME} + BAR_PLAIN + 1 + ${#INFO}))

    SHOW_DESC=true
    case "${STATUSLINE_SUBAGENT_DESC}" in
        false|0) SHOW_DESC=false ;;
    esac

    if $SHOW_DESC && [ -n "$DESC" ]; then
        SUFFIX=" · ${DESC}"
        if [ $((PLAIN_LEN + ${#SUFFIX})) -le "$COLUMNS_WIDTH" ]; then
            LINE="${LINE}${GRAY}${SUFFIX}${RESET}"
        elif [ -n "$MODEL" ] && [ $((PLAIN_LEN + 1 + ${#MODEL})) -le "$COLUMNS_WIDTH" ]; then
            LINE="${LINE} ${GRAY}${MODEL}${RESET}"
        fi
    elif [ -n "$MODEL" ] && [ $((PLAIN_LEN + 1 + ${#MODEL})) -le "$COLUMNS_WIDTH" ]; then
        LINE="${LINE} ${GRAY}${MODEL}${RESET}"
    fi

    jq -n -c --arg id "$ID" --arg content "$LINE" '{id: $id, content: $content}'
done

exit 0
