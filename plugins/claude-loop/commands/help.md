---
description: "Show claude-loop usage and examples"
---

# claude-loop Help

Show the user the following:

## Usage

```
/claude-loop:loop [interval] <prompt or /command>
/claude-loop:loop <prompt> every <interval>
/claude-loop:list
/claude-loop:stop [job_id | all]
```

## Examples

| Command | Effect |
|---------|--------|
| `/claude-loop:loop 5m check the deploy` | Check deploy every 5 minutes |
| `/claude-loop:loop 1m print hello world` | Print "hello world" every minute |
| `/claude-loop:loop check CI status every 10m` | Check CI every 10 minutes |
| `/claude-loop:loop remind me at 3pm to review PRs` | One-time reminder at 3pm |
| `/claude-loop:loop 30s /babysit-prs` | Run /babysit-prs every minute (30s rounds up) |
| `/claude-loop:list` | Show active loops |
| `/claude-loop:stop all` | Cancel all loops |
| `/claude-loop:stop a1b2c3d4` | Cancel specific loop by ID |

## Intervals

`Ns` (seconds, rounds up to 1m minimum), `Nm` (minutes), `Nh` (hours), `Nd` (days). Default: `10m`.

## How It Works

Works on **any model provider** via three-tier fallback:

1. **Tier 1:** Loads CronCreate via ToolSearch — may be available on any provider
2. **Tier 2:** Background sleep chain — real recurring via `Bash run_in_background` notifications
3. **Tier 3:** Execute once — if neither tier works

Jobs are session-scoped and stop when Claude Code exits.
