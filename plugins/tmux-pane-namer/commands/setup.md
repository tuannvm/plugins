---
description: "Set up LLM-powered tmux pane auto-renaming with cron scheduling"
allowed-tools: ["Bash", "Read", "Write", "Edit"]
---

Set up the tmux-pane-namer by performing these steps:

1. **Install the rename script:**
   - Create the directory if needed: `mkdir -p "$HOME/.config/tmux"`
   - Copy the script from `${CLAUDE_PLUGIN_ROOT}/scripts/rename-panes.sh` to `$HOME/.config/tmux/rename-panes.sh`
   - Make it executable: `chmod +x "$HOME/.config/tmux/rename-panes.sh"`

2. **Configure tmux pane borders:**
   - Auto-detect tmux config location: check `$HOME/.config/tmux/tmux.conf` first, then `$HOME/.tmux.conf`. If neither exists, create `$HOME/.config/tmux/tmux.conf`.
   - Check if `pane-border-status` is already configured in the tmux config
   - If not, append these lines:
     ```
     # tmux-pane-namer: show pane titles in borders
     set -g pane-border-status top
     set -g pane-border-format ' #{pane_title} '
     ```
   - If `pane-border-status` exists but `pane-border-format` doesn't, only add the format line
   - Reload tmux config if tmux is running: `tmux source-file <config-path> 2>/dev/null || true`

3. **Set up cron job (idempotent):**
   - First remove any existing `rename-panes.sh` cron entry, then add the new one:
     ```bash
     (crontab -l 2>/dev/null | grep -v 'rename-panes.sh'; echo "*/5 * * * * $HOME/.config/tmux/rename-panes.sh >/dev/null 2>&1") | crontab -
     ```

4. **Test the script:**
   - Run `$HOME/.config/tmux/rename-panes.sh` once to verify it works
   - Show the resulting pane titles: `tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} | #{pane_title}' | head -20`

Print a summary of what was installed and configured.
