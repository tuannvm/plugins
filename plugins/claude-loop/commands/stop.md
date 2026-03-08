---
description: "Stop active loops by ID, prompt substring, or all"
argument-hint: "[job_id | prompt_substring | all]"
---

# Stop Loops

Cancel active jobs. Parse `$ARGUMENTS`:

- **No args** → list active jobs and ask which to stop
- **"all"** → stop all active jobs
- **Otherwise** → match by: exact ID → ID prefix → prompt substring. If multiple match, list them and ask user to clarify.

## Method Selection

1. Call `ToolSearch("select:CronList,CronDelete")` to load the tools
2. **If loaded** → use `CronList` to find jobs, `CronDelete` to cancel
3. **If unavailable** → Glob `/tmp/claude-loop-*.state`, match against argument, delete matching files

Confirm what was stopped: job ID, prompt, interval.
