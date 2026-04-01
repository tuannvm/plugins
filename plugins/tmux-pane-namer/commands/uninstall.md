---
description: "Remove tmux pane auto-renaming (script, cron, config)"
allowed-tools: ["Bash", "Read", "Edit"]
---

Remove all tmux-pane-namer components:

1. **Remove the cron job:**
   - Remove the line containing `rename-panes.sh` from the user's crontab:
     ```bash
     crontab -l 2>/dev/null | grep -v 'rename-panes.sh' | crontab -
     ```

2. **Remove the script:**
   - Delete `$HOME/.config/tmux/rename-panes.sh`

3. **Remove tmux config additions:**
   - Read `~/.tmux.conf` and remove the `pane-border-status` and `pane-border-format` lines that were added by this plugin (look for the `# tmux-pane-namer` comment block)

4. **Clean up cache:**
   - Remove `$HOME/.cache/tmux-pane-namer/` directory

Report what was removed.
