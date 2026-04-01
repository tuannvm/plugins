---
description: "Set up LLM-powered tmux pane auto-renaming with cron scheduling"
allowed-tools: ["Bash", "Read", "Write", "Edit"]
---

Set up the tmux-pane-namer by performing these steps:

1. **Install the rename script:**
   - Copy the script from `${CLAUDE_PLUGIN_ROOT}/scripts/rename-panes.sh` to `$HOME/.config/tmux/rename-panes.sh`
   - Create the directory if it doesn't exist: `mkdir -p "$HOME/.config/tmux"`
   - Make it executable: `chmod +x "$HOME/.config/tmux/rename-panes.sh"`

2. **Configure tmux pane borders:**
   - Check if `~/.tmux.conf` already has `pane-border-status` configured
   - If not, append these lines:
     ```
     # tmux-pane-namer: show pane titles in borders
     set -g pane-border-status top
     set -g pane-border-format " #{pane_index}: #{pane_title} "
     ```
   - Reload tmux config if tmux is running: `tmux source-file ~/.tmux.conf 2>/dev/null || true`

3. **Set up cron job:**
   - Check if a cron entry for `rename-panes.sh` already exists
   - If not, add: `*/2 * * * * $HOME/.config/tmux/rename-panes.sh >/dev/null 2>&1`
   - Use `(crontab -l 2>/dev/null; echo "*/2 * * * * $HOME/.config/tmux/rename-panes.sh >/dev/null 2>&1") | crontab -`

4. **Test the script:**
   - Run `$HOME/.config/tmux/rename-panes.sh` once to verify it works
   - Report the result

Print a summary of what was installed and configured.
