# tmux-pane-namer

LLM-powered automatic tmux pane renaming. Uses Claude CLI to intelligently name your tmux panes based on running processes, working directories, and child process trees.

## Features

- **Smart naming** — Uses Claude (haiku) to generate concise, emoji-prefixed pane labels based on context
- **State caching** — Tracks pane state via content hashing; skips redundant LLM calls when nothing changes
- **Cron scheduling** — Automatically renames panes on a schedule (default: every 5 minutes)
- **Claude Code aware** — Skips panes running Claude Code to avoid overwriting their status titles
- **Cross-platform** — Works on macOS and Linux with portable PATH, process discovery, and hashing
- **Safe concurrency** — Uses atomic `mkdir`-based locking to prevent overlapping runs
- **Graceful failure** — Silently exits if tmux or Claude CLI is unavailable

## Prerequisites

- [tmux](https://github.com/tmux/tmux) 3.0+ (with `pane-border-status` support)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude -p` must work non-interactively)

## What Gets Installed

| Component | Location |
|---|---|
| Rename script | `~/.config/tmux/rename-panes.sh` |
| State cache | `${XDG_CACHE_HOME:-~/.cache}/tmux-pane-namer/` |
| Cron job | `*/5 * * * *` entry in user crontab |
| tmux config | `pane-border-status` and `pane-border-format` added to your tmux.conf |

## Commands

| Command | Description |
|---|---|
| `/tmux-pane-namer:setup` | Install the script, configure tmux, and set up the cron job |
| `/tmux-pane-namer:run` | Manually trigger a pane rename |
| `/tmux-pane-namer:uninstall` | Remove the script, cron job, cache, and tmux config additions |

## How It Works

1. Collects metadata for all tmux panes (current command, working directory, child processes)
2. Skips panes owned by Claude Code (detected by title or version-string command)
3. Hashes the collected state and compares against the last cached hash
4. If state changed, sends pane info to `claude -p --model haiku` with a naming prompt
5. Applies the returned labels via `tmux select-pane -T` and caches the result
6. On cache hit, re-applies cached labels instantly without calling the LLM

## Configuration

### Cron interval

The default cron interval is every 5 minutes. To change it, edit your crontab (`crontab -e`) and adjust the schedule expression.

### Pane border format

The setup command adds a default `pane-border-format` to your tmux config. You can customize it:

```tmux
# Default (plain)
set -g pane-border-format ' #{pane_title} '

# Themed (active pane highlighted)
set -g pane-border-format '#[fg=colour240] #{?#{==:#{pane_active},1},#[fg=colour42],#[fg=colour241]}#{pane_title} #[fg=colour240]'
```

### tmux.conf location

The setup command auto-detects your tmux config at `~/.config/tmux/tmux.conf` or `~/.tmux.conf`.

## Troubleshooting

**Script runs but panes aren't renamed:**
- Verify Claude CLI works: `echo "test" | claude -p --model haiku "echo back"`
- Check the lock isn't stale: `rm -rf /tmp/tmux-rename-panes.lock`
- Clear the cache: `rm -rf ~/.cache/tmux-pane-namer/`

**Cron job doesn't run:**
- Cron has minimal PATH. The script prepends common binary locations, but verify: `crontab -l`
- Check cron logs: `grep cron /var/log/syslog` (Linux) or `log show --predicate 'process == "cron"' --last 10m` (macOS)

**Pane borders not showing:**
- Verify tmux config: `tmux show -g pane-border-status` should return `top`
- Reload config: `tmux source-file ~/.config/tmux/tmux.conf` or `tmux source-file ~/.tmux.conf`
