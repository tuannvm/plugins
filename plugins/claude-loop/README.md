# claude-loop

Recurring loop & reminder plugin for Claude Code. Works on **any model provider** — not just Anthropic.

## Commands

| Command | Description |
|---------|-------------|
| `/claude-loop:loop [interval] <prompt>` | Schedule a recurring prompt |
| `/claude-loop:list` | List active loops |
| `/claude-loop:stop [id \| all]` | Stop loops |
| `/claude-loop:help` | Show usage and examples |

## Features

- Schedule recurring prompts: `/claude-loop:loop 5m check the deploy`
- One-time reminders: `/claude-loop:loop remind me at 3pm to review PRs`
- Natural language: "check the deploy every 5 minutes"
- Intervals: `Ns`, `Nm`, `Nh`, `Nd` (default `10m`, minimum `1m`)

## Three-Tier Execution

1. **Tier 1: CronCreate** — Loads deferred Cron tools via ToolSearch. Full-featured, identical to built-in `/loop`.
2. **Tier 2: Background Sleep Chain** — When Cron tools are unavailable, uses `Bash run_in_background` sleep notifications for real recurring execution. Output appears inline in the conversation.
3. **Tier 3: Execute Once** — Last resort fallback if neither Tier 1 nor Tier 2 work.

## Why This Exists

The built-in `/loop` command relies on `CronCreate`, which is a deferred tool that may not be discovered automatically on custom model providers. This plugin explicitly loads Cron tools via `ToolSearch` first, and provides a working fallback (Tier 2) for providers where Cron tools are genuinely unavailable.

## Installation

```bash
/plugin marketplace add tuannvm/plugins
/plugin install claude-loop@plugins
```
