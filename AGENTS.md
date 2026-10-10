# Statusline

Custom statusline for Claude Code CLI — displays model, agent/teammate badge, directory, git branch, context usage bar, session duration, and optional cost. Also renders per-teammate rows in the agent panel via the `subagentStatusLine` setting.

## Stack

- **Language:** Bash (POSIX-compatible)
- **Dependency:** `jq` (JSON parsing)
- **Runtime:** Claude Code statusline hook (reads JSON from stdin)

## Files

| File | Purpose |
|---|---|
| `statusline-command.sh` | Main statusline script (piped JSON input → ANSI output) |
| `subagent-statusline.sh` | Per-teammate statusline rows for the agent panel (`subagentStatusLine` setting) |
| `lib-context-bar.sh` | Shared library: context bar renderer, token/elapsed formatting, ANSI palette |
| `install.sh` | Installer (downloads all scripts, patches `~/.claude/settings.json`; `--force` re-downloads) |
| `test-statusline.sh` | Color-segment, cost-toggle, agent-badge & subagent-row tests |
| `debug-statusline.sh` | Debug helper |

## Testing

```bash
# Run all color-segment, cost-toggle, agent-badge and subagent tests
./test-statusline.sh

# Manual smoke test (main statusline)
echo '{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/tmp/x"},"cost":{"total_cost_usd":0.5,"total_duration_ms":90000},"context_window":{"used_percentage":50,"used_tokens":100000,"context_window_size":200000}}' | ./statusline-command.sh

# Manual smoke test (subagent/teammate rows)
echo '{"columns":120,"tasks":[{"id":"t1","name":"researcher","status":"running","tokenCount":46000,"contextWindowSize":200000,"startTime":'"$(($(date +%s)*1000-60000))"'}]}' | ./subagent-statusline.sh
```

## Key Design

- Context bar uses 10 slots: `[PP%████NNNk]` — left = percentage, middle = visual fill, right = context window size
- Color tiers: ≤30% green → 40% light green → 50% orange → 60% pink → 70%+ red
- Cost block hidden by default; set `STATUSLINE_COST=true` or `1` to enable
- Git branch shown when inside a git repo
- `🤖` badge resolves teammate identity in three tiers: (1) inside a teammate's tmux pane, `$TMUX_PANE` is matched against `members[].tmuxPaneId` (+ cwd guard) in `~/.claude/teams/*/config.json`, newest-modified config winning on pane-id collisions; (2) `.agent.name` from the JSON payload (agent *type* — full-instance agent sessions only); (3) lead bar shows the union of active teammates (`isActive`, `agentType != team-lead`) across ALL team configs filtered to members whose `cwd` matches the session directory. Team dir ids are minted per spawn wave and are NOT derivable from the payload `session_id`, so no id-based lookup exists — scanning is the only reliable source (verified against live capture 2026-10-10). The in-app agent-panel selection is never exposed to the statusline (measured: no payload change on switch), so it cannot be reflected in the main bar.
- ANSI colors are built as real escape bytes (via `printf '\033'`) and the bar's fill uses a literal braille char (U+2800) — no `\u` escapes, for macOS bash 3.2 compatibility
- stdin is slurped with the builtin `read -r -d ''` idiom and the script dir is derived via parameter expansion — no `cat`/`dirname` subprocesses

## Subagent/Teammate Statusline

`subagentStatusLine` (separate Claude Code setting) runs `subagent-statusline.sh` once per refresh tick with all visible agent-panel rows on stdin: `columns` + `tasks[]` (id, name?, agentType?, status, description, label, startTime, model?, contextWindowSize?, tokenCount, …). The script writes back one `{"id", "content"}` JSON line per row; omitted ids keep the default rendering. Each row shows: status icon (▶ running, ✓ completed, ✗ failed, ✕ killed, ◔ pending), name, the same context bar computed from `tokenCount`/`contextWindowSize`, token count, elapsed time, and the description when the row width allows (`columns` guard). `agentType` requires Claude Code v2.1.293+, so `name` is the primary label. Set `STATUSLINE_SUBAGENT_DESC=false` to hide descriptions.

## Conventions

- No external dependencies beyond `jq`
- All ANSI color codes use 256-color or SGR; avoid 24-bit true color
- Keep the script portable across macOS and Linux
