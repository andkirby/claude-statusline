#!/usr/bin/env bash
# Shared statusline library — sourced by statusline-command.sh and subagent-statusline.sh
# Provides the context bar renderer and token formatting.
# ANSI colors use REAL escape bytes (built via printf) so they survive
# `printf`/`jq` without needing `echo -e` interpretation.

ESC=$(printf '\033')
CYAN="${ESC}[36m"; GREEN="${ESC}[32m"; DARKGREEN="${ESC}[38;5;22m"; YELLOW="${ESC}[33m"; ORANGE="${ESC}[38;5;208m"; RED="${ESC}[31m"; WHITE="${ESC}[97m"; MAGENTA="${ESC}[35m"; GRAY="${ESC}[90m"; RESET="${ESC}[0m"

# Empty braille char (U+2800) as a literal UTF-8 byte sequence — avoids \u
# escapes that older bash (3.2 on macOS) cannot interpret.
EMPTY_SYMBOL="⠀"

# fmt_tokens N — format a token count as human-readable (e.g. 205k, 1.2M)
fmt_tokens() {
    local n="$1"
    local k=$((n / 1000))
    if [ "$k" -ge 1000 ]; then
        local m=$((k / 1000))
        local rem=$((k % 1000))
        if [ "$rem" -eq 0 ]; then
            printf '%sM' "$m"
        else
            printf '%s.%sM' "$m" "$((rem / 100))"
        fi
    else
        printf '%sk' "$k"
    fi
}

# fmt_elapsed MS — format a duration in milliseconds compactly (45s, 12m, 1h05m)
fmt_elapsed() {
    local ms="$1"
    local hours=$((ms / 3600000))
    local mins=$(((ms % 3600000) / 60000))
    local secs=$(((ms % 60000) / 1000))
    if [ "$hours" -gt 0 ]; then
        printf '%dh%02dm' "$hours" "$mins"
    elif [ "$mins" -gt 0 ]; then
        printf '%dm' "$mins"
    else
        printf '%ds' "$secs"
    fi
}

# build_context_bar PCT USED_TOKENS TOTAL_TOKENS — render the [PP%████NNNk] bar
# 10 slots: percentage (left), visual fill (middle), context size (right).
# Color tiers: <=30% green -> 40% light green -> 50% orange -> 60% pink -> 70%+ red
build_context_bar() {
    local PCT="$1" TOTAL_TOKENS="$3"

    if [ "$PCT" -gt 70 ]; then
        BAR_COLOR="${ESC}[38;5;196m"; BAR_DARK="${ESC}[38;5;124m"; BAR_BG_LIGHT="${ESC}[48;5;196m"; BAR_BG_DARK="${ESC}[48;5;124m"
    elif [ "$PCT" -gt 60 ]; then
        BAR_COLOR="${ESC}[38;5;160m"; BAR_DARK="${ESC}[38;5;88m"; BAR_BG_LIGHT="${ESC}[48;5;160m"; BAR_BG_DARK="${ESC}[48;5;88m"
    elif [ "$PCT" -gt 50 ]; then
        BAR_COLOR="${ESC}[38;5;208m"; BAR_DARK="${ESC}[38;5;94m"; BAR_BG_LIGHT="${ESC}[48;5;208m"; BAR_BG_DARK="${ESC}[48;5;94m"
    elif [ "$PCT" -gt 40 ]; then
        BAR_COLOR="${ESC}[38;5;112m"; BAR_DARK="${ESC}[38;5;28m"; BAR_BG_LIGHT="${ESC}[48;5;112m"; BAR_BG_DARK="${ESC}[48;5;28m"
    elif [ "$PCT" -gt 30 ]; then
        BAR_COLOR="${ESC}[38;5;40m"; BAR_DARK="${ESC}[38;5;22m"; BAR_BG_LIGHT="${ESC}[48;5;40m"; BAR_BG_DARK="${ESC}[48;5;22m"
    else
        BAR_COLOR="${ESC}[38;5;28m"; BAR_DARK="${ESC}[38;5;22m"; BAR_BG_LIGHT="${ESC}[48;5;28m"; BAR_BG_DARK="${ESC}[48;5;22m"
    fi

    local CTX_SIZE
    CTX_SIZE=$(fmt_tokens "$TOTAL_TOKENS")

    local PCT_FULL="${PCT}%"
    local PCT_LEN=${#PCT_FULL}                    # e.g. 3 for "23%"
    local CTX_LEN=${#CTX_SIZE}                    # e.g. 4 for "205k"
    local TOTAL_SLOTS=10
    local BAR_START=$PCT_LEN                      # slot where bar begins
    local BAR_END=$((TOTAL_SLOTS - CTX_LEN))      # slot where bar ends (exclusive)
    local FILLED_SLOTS=$((PCT / 10))

    local BAR="" char i
    # Slot 0..PCT_LEN-1: Left-aligned percentage text
    for ((i = 0; i < PCT_LEN; i++)); do
        char="${PCT_FULL:i:1}"
        if [ "$i" -lt "$FILLED_SLOTS" ]; then
            BAR="${BAR}${WHITE}${BAR_BG_LIGHT}${char}${RESET}"
        else
            BAR="${BAR}${WHITE}${BAR_BG_DARK}${char}${RESET}"
        fi
    done

    # Slot PCT_LEN..BAR_END-1: Visual bar
    for ((i = BAR_START; i < BAR_END; i++)); do
        if [ "$i" -lt "$FILLED_SLOTS" ]; then
            BAR="${BAR}${BAR_COLOR}${BAR_BG_LIGHT}${EMPTY_SYMBOL}${RESET}"
        else
            BAR="${BAR}${BAR_DARK}${BAR_BG_DARK}${EMPTY_SYMBOL}${RESET}"
        fi
    done

    # Slot BAR_END..9: Right-aligned context size
    for ((i = BAR_END; i < TOTAL_SLOTS; i++)); do
        char="${CTX_SIZE:i - BAR_END:1}"
        if [ "$i" -lt "$FILLED_SLOTS" ]; then
            BAR="${BAR}${WHITE}${BAR_BG_LIGHT}${char}${RESET}"
        else
            BAR="${BAR}${WHITE}${BAR_BG_DARK}${char}${RESET}"
        fi
    done

    printf '%s' "$BAR"
}
