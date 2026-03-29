# Statusline

Custom statusline for Claude Code CLI — displays model, directory, git branch, context usage bar, session duration, and optional cost.

## Stack

- **Language:** Bash (POSIX-compatible)
- **Dependency:** `jq` (JSON parsing)
- **Runtime:** Claude Code statusline hook (reads JSON from stdin)

## Files

| File | Purpose |
|---|---|
| `statusline-command.sh` | Main statusline script (piped JSON input → ANSI output) |
| `install.sh` | One-line installer (downloads script, patches `~/.claude/settings.json`) |
| `test-statusline.sh` | Color-segment & toggle tests |
| `debug-statusline.sh` | Debug helper |

## Testing

```bash
# Run all color-segment and cost-toggle tests
./test-statusline.sh

# Manual smoke test
echo '{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/tmp/x"},"cost":{"total_cost_usd":0.5,"total_duration_ms":90000},"context_window":{"used_percentage":50,"used_tokens":100000,"context_window_size":200000}}' | ./statusline-command.sh
```

## Key Design

- Context bar uses 10 slots: `[PP%████NNNk]` — left = percentage, middle = visual fill, right = context window size
- Color tiers: ≤30% green → 40% light green → 50% orange → 60% pink → 70%+ red
- Cost block hidden by default; set `STATUSLINE_COST=true` or `1` to enable
- Git branch shown when inside a git repo

## Conventions

- No external dependencies beyond `jq`
- All ANSI color codes use 256-color or SGR; avoid 24-bit true color
- Keep the script portable across macOS and Linux
