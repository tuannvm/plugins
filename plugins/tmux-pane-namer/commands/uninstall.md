---
description: "Remove tmux pane auto-renaming (script, cron, config)"
allowed-tools: ["Bash", "Read", "Edit"]
---

Remove all tmux-pane-namer components:

1. **Remove the cron job:**
   ```bash
   crontab -l 2>/dev/null | grep -v 'rename-panes.sh' | crontab -
   ```

2. **Remove the script:**
   - Delete `$HOME/.config/tmux/rename-panes.sh`

3. **Remove tmux config additions:**
   - Auto-detect tmux config location: check `$HOME/.config/tmux/tmux.conf` first, then `$HOME/.tmux.conf`
   - Remove the `# tmux-pane-namer` comment and the `pane-border-status` / `pane-border-format` lines that were added by this plugin
   - Only remove lines that include the `# tmux-pane-namer` marker comment. If the user has their own `pane-border-status` without the marker, leave it alone.

4. **Clean up cache:**
   - Remove `$HOME/.cache/tmux-pane-namer/` directory

5. **Clean up lock (if present):**
   - Remove `/tmp/tmux-rename-panes.lock` if it exists

6. **Reload tmux config:**
   - `tmux source-file <config-path> 2>/dev/null || true`

Report what was removed.
