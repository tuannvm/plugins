---
description: "Cancel active Ralph Wiggum loop"
allowed-tools: ["Bash", "Read"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralph

Check if a Ralph loop is active:

```bash
if [[ -f .claude/ralph-loop.local.md ]]; then
  grep '^iteration:' .claude/ralph-loop.local.md | sed 's/iteration: *//'
else
  echo "No active Ralph loop found."
fi
```

If an iteration number was shown (not "No active..."), cancel the loop:

```bash
rm .claude/ralph-loop.local.md
```

Report: "Cancelled Ralph loop (was at iteration N)" where N is the iteration number from the first command.

If no active loop was found, say so.
