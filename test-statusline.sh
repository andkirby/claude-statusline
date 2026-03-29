#!/usr/bin/env bash

# Test different color segments of statusline
STATUSLINE_SCRIPT="$HOME/.claude/statusline/statusline-command.sh"

test_color() {
    local pct="$1"
    local desc="$2"
    local duration_ms="${3:-15000}"
    local total_tokens="${4:-200000}"

    local used_tokens=$((total_tokens * pct / 100))

    local json=$(cat <<EOF
{
  "model": {"display_name": "Opus 4.6"},
  "workspace": {"current_dir": "/Users/user/project"},
  "cost": {"total_cost_usd": 0.22, "total_duration_ms": $duration_ms},
  "context_window": {"used_percentage": $pct, "used_tokens": $used_tokens, "context_window_size": $total_tokens}
}
EOF
)

    echo "[$pct% - $desc]"
    echo "→ $(echo "$json" | "$STATUSLINE_SCRIPT")"
}

echo "=== Statusline Color Segments ==="

# 0-30: green (28)
test_color "7" "0-30%: Green" "45000" "200000"
test_color "28" "0-30%: Green" "150000" "200000"

# >30: color 40
test_color "35" ">30%: Color 40" "510000" "200000"

# >40: color 112
test_color "45" ">40%: Color 112" "900000" "200000"

# >50: color 130
test_color "55" ">50%: Color 130" "3599000" "200000"

# >60: color 160
test_color "65" ">60%: Color 160" "3900000" "200000"

# >70: color 196 (red)
test_color "80" ">70%: Color 196 (Red)" "9296000" "200000"
test_color "100" ">70%: Color 196 (Red)" "18900000" "200000"

# Different context window sizes
test_color "50" "M-range: 1M context" "600000" "1000000"
test_color "50" "M-range: 1.2M context" "600000" "1200000"
test_color "50" "M-range: 2M context" "1000000" "2000000"

echo "=== End ==="

echo ""
echo "=== Cost Block Toggle (STATUSLINE_COST) ==="
JSON='{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/Users/user/project"},"cost":{"total_cost_usd":3.50,"total_duration_ms":3600000},"context_window":{"used_percentage":50,"used_tokens":100000,"total_tokens":200000}}'

echo "[unset (hidden)]"
echo "→ $(echo "$JSON" | "$STATUSLINE_SCRIPT")"

STATUSLINE_COST=false echo "[STATUSLINE_COST=false (hidden)]"
echo "→ $(STATUSLINE_COST=false bash -c "echo '$JSON' | '$STATUSLINE_SCRIPT'")"

STATUSLINE_COST=true echo "[STATUSLINE_COST=true (shown)]"
echo "→ $(STATUSLINE_COST=true bash -c "echo '$JSON' | '$STATUSLINE_SCRIPT'")"

STATUSLINE_COST=1 echo "[STATUSLINE_COST=1 (shown)]"
echo "→ $(STATUSLINE_COST=1 bash -c "echo '$JSON' | '$STATUSLINE_SCRIPT'")"

STATUSLINE_COST=0 echo "[STATUSLINE_COST=0 (hidden)]"
echo "→ $(STATUSLINE_COST=0 bash -c "echo '$JSON' | '$STATUSLINE_SCRIPT'")"

echo "=== End ==="
