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

echo ""
echo "=== Agent/Teammate Badge (.agent.name) ==="
BASE_JSON='{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/Users/user/project"},"cost":{"total_cost_usd":0.5,"total_duration_ms":90000},"context_window":{"used_percentage":50,"used_tokens":100000,"context_window_size":200000}}'

echo "[no agent field (hidden)]"
echo "→ $(echo "$BASE_JSON" | "$STATUSLINE_SCRIPT")"

echo "[with agent.name=team-researcher (shown)]"
echo "→ $(echo "${BASE_JSON%\}*}, \"agent\": {\"name\": \"team-researcher\"}}" | "$STATUSLINE_SCRIPT")"
echo "=== End ==="

echo ""
echo "=== Subagent Statusline (tasks[] rows) ==="
SUBAGENT_SCRIPT="$HOME/.claude/statusline/subagent-statusline.sh"

sub_test() {
    local desc="$1"
    local json="$2"
    echo "[$desc]"
    local out
    out=$(echo "$json" | "$SUBAGENT_SCRIPT")
    if [ -z "$out" ]; then
        echo "→ (empty output)"
    else
        # Validate each line is well-formed {"id","content"} JSON, then show decoded content
        echo "$out" | jq -e 'has("id") and has("content")' > /dev/null 2>&1 \
            && echo "→ $(echo "$out" | jq -r '.id + ": " + .content' | sed $'s/\033\\[[0-9;]*m//g')" \
            || echo "→ INVALID JSON: $out"
    fi
}

NOW_MS=$(($(date +%s) * 1000))
TASKS_JSON='"columns":120,"tasks":[{"id":"t1","name":"researcher","type":"local_agent","status":"running","description":"Explore the codebase for schema info","label":"reading statusline docs","startTime":'"$((NOW_MS - 75000))"',"model":"claude-opus-4-6","contextWindowSize":200000,"tokenCount":46000,"tokenSamples":[1000,5000,20000],"cwd":"/tmp"}]'

sub_test "running teammate, wide columns (desc shown)" "{$TASKS_JSON}"
sub_test "running teammate, narrow columns (desc dropped)" "$(echo "$TASKS_JSON" | sed 's/"columns":120/"columns":40/' | sed 's/^/{/' | sed 's/$/}/')"
sub_test "no columns field (default 80)" "{${TASKS_JSON/\"columns\":120,/}}"

sub_test "completed teammate" "{\"columns\":120,\"tasks\":[{\"id\":\"t2\",\"name\":\"worker\",\"type\":\"local_agent\",\"status\":\"completed\",\"description\":\"Implement the parser\",\"startTime\":$((NOW_MS - 7200000)),\"contextWindowSize\":200000,\"tokenCount\":150000}]}"
sub_test "failed teammate" "{\"columns\":120,\"tasks\":[{\"id\":\"t3\",\"name\":\"reviewer\",\"type\":\"local_agent\",\"status\":\"failed\",\"description\":\"Review diff\",\"startTime\":$((NOW_MS - 30000)),\"tokenCount\":8000}]}"
sub_test "killed teammate" "{\"columns\":120,\"tasks\":[{\"id\":\"t4\",\"name\":\"tester\",\"type\":\"local_agent\",\"status\":\"killed\",\"description\":\"Run tests\",\"startTime\":$((NOW_MS - 600000)),\"tokenCount\":42000}]}"
sub_test "no name, agentType only (pre-v2.1.293 payload)" '{"columns":120,"tasks":[{"id":"t5","type":"local_agent","agentType":"Explore","status":"running","description":"Find symbols","tokenCount":12000,"contextWindowSize":200000}]}'
sub_test "no contextWindowSize (no bar)" '{"columns":120,"tasks":[{"id":"t6","name":"scout","type":"local_agent","status":"running","description":"Scanning","tokenCount":9000}]}'
sub_test "empty tasks array" '{"columns":120,"tasks":[]}'
sub_test "no tasks field" '{"columns":120,"session_id":"abc"}'

echo "=== End ==="

echo ""
echo "=== Teammate Identity Resolution (team config) ==="
FAKE_HOME=$(mktemp -d)
TEAM_DIR="$FAKE_HOME/.claude/teams/session-deadbeef"
mkdir -p "$TEAM_DIR"
cat > "$TEAM_DIR/config.json" <<'EOF'
{
  "name": "session-deadbeef",
  "leadSessionId": "deadbeef-0000-0000-0000-000000000000",
  "members": [
    {"agentId": "team-lead@session-deadbeef", "name": "team-lead", "agentType": "team-lead", "tmuxPaneId": "leader", "cwd": "/Users/user/project", "isActive": true, "backendType": "in-process"},
    {"agentId": "opus-verifier@session-deadbeef", "name": "opus-verifier", "agentType": "claude", "tmuxPaneId": "%0", "cwd": "/Users/user/project", "isActive": true, "backendType": "tmux"}
  ]
}
EOF

TEAM_JSON='{"model":{"display_name":"Opus"},"workspace":{"current_dir":"/Users/user/project"},"session_id":"deadbeef-1234","cost":{"total_duration_ms":60000},"context_window":{"used_percentage":10,"used_tokens":20000,"context_window_size":200000}}'

echo "[teammate pane: TMUX_PANE=%0 resolves to opus-verifier]"
echo "→ $(echo "$TEAM_JSON" | TMUX_PANE='%0' HOME="$FAKE_HOME" bash "$STATUSLINE_SCRIPT")"

echo "[unknown pane id: lead bar falls back to active roster]"
echo "→ $(echo "$TEAM_JSON" | TMUX_PANE='%9' HOME="$FAKE_HOME" bash "$STATUSLINE_SCRIPT")"

echo "[no tmux: lead bar shows active roster]"
echo "→ $(echo "$TEAM_JSON" | HOME="$FAKE_HOME" bash "$STATUSLINE_SCRIPT")"

jq '.members[1].isActive = false' "$TEAM_DIR/config.json" > "$TEAM_DIR/config.json.new" && mv "$TEAM_DIR/config.json.new" "$TEAM_DIR/config.json"
echo "[roster all inactive → no badge]"
echo "→ $(echo "$TEAM_JSON" | HOME="$FAKE_HOME" bash "$STATUSLINE_SCRIPT")"

rm -rf "$FAKE_HOME"
echo "=== End ==="
