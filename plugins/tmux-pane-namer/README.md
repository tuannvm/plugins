# tmux-pane-namer

LLM-powered automatic tmux pane renaming. Uses Claude CLI (haiku) to intelligently name your tmux panes based on running processes, working directories, and child process trees.

## Features

- **Smart naming** — Uses an LLM to generate concise, emoji-prefixed pane labels based on context (running commands, working directory, child processes).
- **State caching** — Tracks pane state with a content hash; skips redundant LLM calls when nothing has changed.
- **Cron scheduling** — Automatically renames panes on a schedule (default: every 2 minutes).
- **Claude Code aware** — Skips panes running Claude Code to avoid interference.
- **Cross-platform** — Works on macOS and Linux, handles PATH differences for cron execution.
- **Safe concurrency** — Uses a lock directory to prevent overlapping runs.

## Prerequisites

- [tmux](https://github.com/tmux/tmux) (with `pane-border-status` support)
- [Claude CLI](https://docs.anthropic.com/en/docs/claude-cli) (`claude` command available in PATH)

## What Gets Installed

| Component | Location |
|---|---|
| Rename script | `~/.config/tmux/rename-panes.sh` |
| State cache | `~/.cache/tmux-pane-namer/` |
| Cron job | `*/2 * * * *` entry in user crontab |
| tmux config | `pane-border-status` and `pane-border-format` lines in `~/.tmux.conf` |

## Commands

| Command | Description |
|---|---|
| `/setup` | Install the script, configure tmux, and set up the cron job |
| `/run` | Manually trigger a pane rename |
| `/uninstall` | Remove the script, cron job, and tmux config additions |

## How It Works

1. Collects metadata for all tmux panes (current command, working directory, child processes).
2. Skips panes owned by Claude Code.
3. Hashes the collected state and compares against the cached hash.
4. If state changed, sends pane info to Claude (haiku) with a naming prompt.
5. Applies the returned labels via `tmux select-pane -T` and caches the result.
