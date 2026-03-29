#!/usr/bin/env bash
# Statusline for Claude Code
# Bar: [PP%████NNNk] — 10 slots: percentage (left), visual bar (middle), context size (right)
# Env vars:
#   STATUSLINE_COST=true|1   Show cost block (default: hidden)

input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
USED_TOKENS=$(echo "$input" | jq -r '.context_window.used_tokens // 0')
TOTAL_TOKENS=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

CYAN='\033[36m'; GREEN='\033[32m'; DARKGREEN='\033[38;5;22m'; YELLOW='\033[33m'; ORANGE='\033[38;5;208m'; RED='\033[31m'; WHITE='\033[97m'; RESET='\033[0m'

# Pick bar color based on context usage
if [ "$PCT" -gt 70 ]; then
    BAR_COLOR='\033[38;5;196m'; BAR_DARK='\033[38;5;124m'; BAR_BG_LIGHT='\033[48;5;196m'; BAR_BG_DARK='\033[48;5;124m'
elif [ "$PCT" -gt 60 ]; then
    BAR_COLOR='\033[38;5;160m'; BAR_DARK='\033[38;5;88m'; BAR_BG_LIGHT='\033[48;5;160m'; BAR_BG_DARK='\033[48;5;88m'
elif [ "$PCT" -gt 50 ]; then
    BAR_COLOR='\033[38;5;208m'; BAR_DARK='\033[38;5;94m'; BAR_BG_LIGHT='\033[48;5;208m'; BAR_BG_DARK='\033[48;5;94m'
elif [ "$PCT" -gt 40 ]; then
    BAR_COLOR='\033[38;5;112m'; BAR_DARK='\033[38;5;28m'; BAR_BG_LIGHT='\033[48;5;112m'; BAR_BG_DARK='\033[48;5;28m'
elif [ "$PCT" -gt 30 ]; then
    BAR_COLOR='\033[38;5;40m'; BAR_DARK='\033[38;5;22m'; BAR_BG_LIGHT='\033[48;5;40m'; BAR_BG_DARK='\033[48;5;22m'
else
    BAR_COLOR='\033[38;5;28m'; BAR_DARK='\033[38;5;22m'; BAR_BG_LIGHT='\033[48;5;28m'; BAR_BG_DARK='\033[48;5;22m'
fi

# Format context size as human-readable (e.g., 205k, 1.2M)
CTX_SIZE_K=$((TOTAL_TOKENS / 1000))
if [ "$CTX_SIZE_K" -ge 1000 ]; then
    CTX_SIZE_M=$((CTX_SIZE_K / 1000))
    CTX_SIZE_REM=$((CTX_SIZE_K % 1000))
    if [ "$CTX_SIZE_REM" -eq 0 ]; then
        CTX_SIZE="${CTX_SIZE_M}M"
    else
        CTX_SIZE="${CTX_SIZE_M}.$((CTX_SIZE_REM / 100))M"
    fi
else
    CTX_SIZE="${CTX_SIZE_K}k"
fi

# 10 slots total: [PP%████NNNk]
#   left:   percentage (left-aligned, e.g. "23%")
#   middle: visual bar (fills remaining space)
#   right:  context size (right-aligned, e.g. "205k")
TOTAL_SLOTS=10
PCT_FULL="${PCT}%"
PCT_LEN=${#PCT_FULL}                    # e.g. 3 for "23%"
CTX_LEN=${#CTX_SIZE}                    # e.g. 4 for "205k"
BAR_START=$PCT_LEN                      # slot where bar begins
BAR_END=$((TOTAL_SLOTS - CTX_LEN))      # slot where bar ends (exclusive)
BAR_SLOTS=$((BAR_END - BAR_START))      # dynamic based on label sizes
FILLED_SLOTS=$((PCT / 10))

# Build the full bar: PCT + visual bar + context size
BAR=""
EMPTY_SYMBOL="\u2800"

# Slot 0..PCT_LEN-1: Left-aligned percentage text
for i in $(seq 0 $((PCT_LEN - 1))); do
    char="${PCT_FULL:$i:1}"
    if [ "$i" -lt "$FILLED_SLOTS" ]; then
        BAR="${BAR}${WHITE}${BAR_BG_LIGHT}${char}${RESET}"
    else
        BAR="${BAR}${WHITE}${BAR_BG_DARK}${char}${RESET}"
    fi
done

# Slot PCT_LEN..BAR_END-1: Visual bar
for i in $(seq $BAR_START $((BAR_END - 1))); do
    if [ "$i" -lt "$FILLED_SLOTS" ]; then
        BAR="${BAR}${BAR_COLOR}${BAR_BG_LIGHT}${EMPTY_SYMBOL}${RESET}"
    else
        BAR="${BAR}${BAR_DARK}${BAR_BG_DARK}${EMPTY_SYMBOL}${RESET}"
    fi
done

# Slot BAR_END..9: Right-aligned context size
for i in $(seq $BAR_END $((TOTAL_SLOTS - 1))); do
    char_idx=$((i - BAR_END))
    char="${CTX_SIZE:$char_idx:1}"
    if [ "$i" -lt "$FILLED_SLOTS" ]; then
        BAR="${BAR}${WHITE}${BAR_BG_LIGHT}${char}${RESET}"
    else
        BAR="${BAR}${WHITE}${BAR_BG_DARK}${char}${RESET}"
    fi
done

HOURS=$((DURATION_MS / 3600000))
MINS=$(((DURATION_MS % 3600000) / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))

BRANCH=""
git rev-parse --git-dir > /dev/null 2>&1 && BRANCH=" | 🌿 $(git branch --show-current 2>/dev/null)"

echo -ne "\033[1;38;5;30m${MODEL}${RESET} 📁 ${DIR##*/}$BRANCH | "

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
