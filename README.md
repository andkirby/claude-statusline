# Claude Code Statusline

A custom statusline for Claude Code CLI that displays a visual context usage bar, model name, directory, git branch, session duration, and optional cost.

## Alternative for `Pi` π (the colored context bar only)

https://github.com/andkirby/pi-context-bar

## Example Output

```
Claude 3.5 Sonnet 📁 my-project | 🌿 main | [35%░░░░░░░░205k] | ⏱️ 12m 34s
```

With `STATUSLINE_COST=true`:

```
Claude 3.5 Sonnet 📁 my-project | 🌿 main | [35%░░░░░░░░205k] | 💰 $0.42 | ⏱️ 12m 34s
```

<img width="483" height="619" alt="image" src="https://github.com/user-attachments/assets/fa72e521-5ddf-4f60-8070-2a6c95ccc1a1" />

## Features

- **Model name** — Current model display name
- **Directory** — Current directory basename with folder icon
- **Git branch** — Current branch (only shown inside a git repo)
- **Context bar** — Visual 10-slot progress bar with percentage and context size
- **Cost** (optional) — Session cost in USD (enable via `STATUSLINE_COST=true`)
- **Duration** — Session time (hours, minutes, seconds)

## Context Bar

The bar `[PP%░░░░░░░░NNNk]` is a 10-slot layout:

| Section | Alignment | Example |
| --- | --- | --- |
| Percentage | Left | `35%` |
| Visual bar | Middle (fills remaining) | `░░░░░░` |
| Context size | Right | `205k` |

### Color Thresholds

The bar uses a 256-color palette that shifts from green to red as context fills:

| Usage | Color |
| --- | --- |
| ≤30% | Dark green |
| 31-40% | Green |
| 41-50% | Light green |
| 51-60% | Orange |
| 61-70% | Dark orange/red |
| >70% | Bright red |

## Installation

### Prerequisites

- [jq](https://jqlang.github.io/jq/) — JSON processor

```bash
# macOS
brew install jq

# Linux
sudo apt install jq  # Debian/Ubuntu
sudo yum install jq  # RHEL/CentOS
```

### From Repository (Recommended)

Clone and run the installer:

```bash
git clone https://github.com/andkirby/claude-statusline.git ~/.claude/statusline
~/.claude/statusline/install.sh
```

The installer downloads `statusline-command.sh` into `~/.claude/statusline/` and updates `~/.claude/settings.json` automatically.

### One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/andkirby/claude-statusline/main/install.sh | bash
```

### Manual Install

1. Download the script:
```bash
curl -fsSL https://raw.githubusercontent.com/andkirby/claude-statusline/main/statusline-command.sh -o ~/.claude/statusline/statusline-command.sh
```

2. Make it executable:
```bash
chmod +x ~/.claude/statusline/statusline-command.sh
```

3. Add to `~/.claude/settings.json`:
```json
{
  "statusLine": {
    "type": "command",
    "command": "$HOME/.claude/statusline/statusline-command.sh"
  }
}
```

## Environment Variables

| Variable | Values | Default | Description |
| --- | --- | --- | --- |
| `STATUSLINE_COST` | `true` or `1` | Hidden | Show session cost block |

## Testing

Test the script manually:

```bash
echo '{"model":{"display_name":"Claude 3.5 Sonnet"},"workspace":{"current_dir":"/Users/user/project"},"context_window":{"used_percentage":35,"used_tokens":71750,"context_window_size":205000},"cost":{"total_cost_usd":0.42,"total_duration_ms":754000}}' | ~/.claude/statusline-command.sh
```
