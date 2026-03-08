---
description: "List all active recurring loops and reminders"
---

# List Active Loops

Show all active jobs scheduled in this session.

## Method Selection

1. Call `ToolSearch("select:CronList")` to load the tool
2. **If loaded** → call `CronList` and display results
3. **If unavailable** → Glob `/tmp/claude-loop-*.state`, read each file, show active ones

### Stale Detection (Tier 2)

For each state file, check if `session_pid` matches a running process:
```bash
kill -0 <session_pid> 2>/dev/null
```
If not running, the job is stale — delete the file and skip it.

### Output Format

Show a table with: Job ID, Prompt, Interval, Created time.
