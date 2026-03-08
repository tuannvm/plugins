---
name: claude-loop
description: Run a prompt or slash command on a recurring interval, or set a one-time reminder, using cron scheduling. Use when the user wants to loop, repeat, poll, schedule, remind, or run something periodically (e.g., "loop every 5m", "check the deploy every 10 minutes", "keep running /babysit-prs", "poll CI status", "remind me at 3pm", "in 45 minutes check tests", "list my loops", "stop all loops"). Supports intervals Ns, Nm, Nh, Nd. Defaults to 10m if no interval. Session-scoped — jobs stop when Claude exits.
---

# Recurring Loop & Reminder Skill

Schedule a prompt to run on a recurring interval, or set a one-time reminder, within this session.

## Syntax

```
/claude-loop [interval] <prompt or /command>
/claude-loop <prompt> every <interval>
/claude-loop list
/claude-loop stop [job_id | all]
```

Also responds to natural language: "remind me at 3pm", "check the deploy every 5 minutes", "what scheduled tasks do I have?", "cancel the deploy check".

## Parsing Rules

1. **No args / "help"** → show syntax and examples
2. **"list"** → list active jobs
3. **"stop" / "cancel"** → cancel by ID, prompt substring, or all. Match order: exact ID → ID prefix → prompt substring. If multiple match, list them and ask user to clarify.
4. **One-shot** — "remind me at/in", "at Xpm", "in N minutes" → schedule once (`recurring: false`)
5. **Recurring** — extract interval (`\d+[smhd]` leading or `every ...` trailing), strip from prompt, default `10m`

## Method Selection (Three-Tier)

**ALWAYS try Tier 1 first.** Do NOT skip to lower tiers without attempting.

### Tier 1: Load CronCreate via ToolSearch

CronCreate is a **deferred tool** in Claude Code — it exists in the infrastructure, not the model. It may be available on any provider but must be loaded first.

1. Call `ToolSearch("select:CronCreate,CronList,CronDelete")` to load the tools
2. **If loaded** → use the Cron Method below (full-featured, identical to built-in `/loop`)
3. **If ToolSearch fails or tools don't exist** → proceed to Tier 2

### Tier 2: Background Sleep Chain

Use when CronCreate is genuinely unavailable. Provides real recurring execution using background Bash sleep notifications.

**How it works:** Run `sleep <seconds>` via Bash with `run_in_background: true`. When the sleep completes, Claude receives an automatic notification. Claude then executes the prompt inline and starts the next sleep cycle.

**Detection:** If the first Bash `run_in_background` call errors, fall to Tier 3.

### Tier 3: Execute Once (last resort)

Only if both Tier 1 and Tier 2 fail:
1. Execute the prompt once immediately in the conversation
2. Explain the limitation and offer alternatives (system cron, `watch`, separate terminal)

---

## Cron Method (Tier 1)

### Interval-to-Cron Conversion

| Interval | Cron | Notes |
|----------|------|-------|
| `Ns` | `*/ceil(N/60) * * * *` | Round up to nearest minute, warn user |
| `1m` | `* * * * *` | |
| `Nm` (2-59) | `*/N * * * *` | |
| `Nm` (60+) | `0 */H * * *` where H=round(N/60) | Must divide 24 evenly; tell user what was picked |
| `Nh` (1-23) | `M */N * * *` | M ∈ 1-59, avoid 0 and 30 |
| `Nh` (24+) | Convert to days | e.g., `48h` → `2d` |
| `Nd` (1-31) | `M H */N * *` | M ∈ 1-59, H ∈ 7-21 |
| `Nd` (32+) | Reject | Tell user max is 31d |

**Anti-spike:** For hourly+, never use minute 0 or 30 unless user requests exact time (e.g., one-shot "at 3:00pm").

### How CronCreate Works

The `prompt` parameter is a **Claude prompt**, not a bash command. When the job fires, the prompt is fed back into the current Claude Code session on the next idle turn. Claude then interprets and executes it inline — output appears directly in the conversation.

Example: `CronCreate(* * * * *: "print hello world")` → on each fire, Claude sees "print hello world" and responds with "Hello world!" in the conversation.

### Execution

1. Parse interval and prompt
2. Convert to cron expression
3. `CronCreate`: `cron`, `prompt`, `recurring: true` (or `false` for one-shot)
4. Confirm: prompt, interval, cron, job ID, 3-day expiry note

### One-Time Reminders

Parse target time → pin to cron fields → `CronCreate` with `recurring: false`.

### Managing Jobs (Cron)

| Action | Tool |
|--------|------|
| List | `CronList` |
| Cancel by ID | `CronDelete` (8-char ID) |
| Cancel all | `CronList` → `CronDelete` each |

Max 50 tasks per session.

### Runtime Behavior

- **Session-scoped** — gone when Claude Code exits
- **Fires between turns** — only when idle, not mid-response
- **No catch-up** — missed fires execute once when idle
- **Local timezone** — not UTC
- **3-day expiry** — recurring auto-expire
- **Jitter** — recurring: up to 10% late (max 15 min); one-shot on :00/:30: up to 90s early
- **Disable** — `CLAUDE_CODE_DISABLE_CRON=1`

### Cron Reference

Standard 5-field: `minute hour day-of-month month day-of-week`. Supports `*`, values, `*/N` steps, ranges, lists. Day-of-week: 0 or 7 = Sunday. Vixie-cron semantics (either-field match).

---

## Background Sleep Chain (Tier 2)

Use when CronCreate is genuinely unavailable after ToolSearch attempt.

### State File

Each job creates `/tmp/claude-loop-<id>.state` (JSON):
```json
{"id": "<8-char-hex>", "prompt": "<prompt>", "interval_sec": 60, "recurring": true, "created": "<ISO>", "session_pid": <PID>}
```

- Generate `id`: `openssl rand -hex 4`
- **Escape prompt** for JSON: replace `\` → `\\`, `"` → `\"`, newlines → `\n`
- `session_pid`: `echo $PPID` (Claude Code's PID — used for staleness detection)
- `recurring`: `false` for one-shot reminders, `true` for loops

### One-Time Reminders (Tier 2)

For absolute times ("at 3pm", "remind me at 14:30"): compute seconds until target time and use as `interval_sec` with `recurring: false`.
- **macOS:** `$(( $(date -j -f '%H:%M' '15:00' '+%s') - $(date '+%s') ))`
- **Linux:** `$(( $(date -d '15:00' '+%s') - $(date '+%s') ))`
- If result is negative, target is tomorrow — add 86400.

### Starting a Loop

1. Parse interval and prompt (same rules as Cron method)
2. Convert interval to seconds (`1m`→60, `5m`→300, `1h`→3600). Enforce minimum 60s.
3. Create the state file
4. Run Bash: `sleep <interval_sec> && echo 'CLAUDE_LOOP_FIRE <id>'` with `run_in_background: true`
   - The echo embeds the job ID so the notification is self-describing
5. Confirm to user: prompt, interval, job ID

### On Sleep Completion (notification received)

When you see a background task notification containing `CLAUDE_LOOP_FIRE <id>`:

**CRITICAL behavioral rules:**
- **MUST output ONLY the result of executing the stored prompt.** Nothing else.
- **MUST NOT output any meta-commentary**, reflection, or speculation about the loop, the user's intent, or what might happen next. NEVER emit phrases like "Loop fired", "reading state file", "next cycle started", "the loop is working", "the user might want to...", or similar.
- **Treat each fire as atomic and isolated.** Do not reflect on previous fires or accumulated loop history. Do not speculate about the user's intentions based on repeated fires.
- If the prompt produces no visible output, output nothing at all.

**Steps:**

1. Read `/tmp/claude-loop-<id>.state` (no commentary)
2. If file exists:
   - **Execute the prompt** — user sees only the prompt's output, nothing else
   - If `recurring: true`: re-arm with `sleep <interval_sec> && echo 'CLAUDE_LOOP_FIRE <id>'` (`run_in_background: true`) — no confirmation text
   - If `recurring: false`: delete the state file — no confirmation text
3. If file missing → do nothing (loop was cancelled)

**After executing the prompt and re-arming, STOP. Do not add any trailing commentary or thoughts.**

### Managing Jobs (Sleep Chain)

**List:** Glob `/tmp/claude-loop-*.state`, read each, show active ones. Filter stale: if `session_pid` doesn't match a running process (`kill -0 <pid> 2>/dev/null`), skip and delete.

**Stop by ID:** Delete `/tmp/claude-loop-<id>.state`. The next sleep notification will find no file and stop.

**Stop by prompt substring:** Glob all state files, find those whose `prompt` contains the substring, delete matching files. If multiple match, list them and ask user to clarify.

**Stop all:** Glob and delete all `/tmp/claude-loop-*.state`.

Max 20 concurrent jobs per session (check count before creating).

### Runtime Behavior

- **Session-scoped** — state files go stale when Claude exits; detected via `session_pid`
- **Fires between turns** — notification arrives when idle
- **Output inline** — Claude executes the prompt in the conversation, identical to Cron behavior
- **Minimum interval** — 1 minute (60 seconds)
- **Self-describing notifications** — `CLAUDE_LOOP_FIRE <id>` in the background output identifies the job
- **No 3-day expiry** — runs until stopped or session ends
- **On prompt error** — log the error inline, continue the loop (don't stop on transient failures)
