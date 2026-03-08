---
description: "Run a prompt on a recurring interval or set a one-time reminder. Works on any model provider."
argument-hint: "[interval] <prompt or /command>"
---

# Recurring Loop & Reminder

Schedule a prompt to run on a recurring interval, or set a one-time reminder, within this session.

## Input

Parse `$ARGUMENTS` into `[interval] <prompt…>`:

1. **No args / "help"** → show usage and examples, then stop
2. **"list"** → list active jobs (see list command logic below)
3. **"stop" / "cancel"** → cancel jobs (see stop command logic below)
4. **Leading token** matches `^\d+[smhd]$` (e.g. `5m`, `2h`) → that's the interval; rest is prompt
5. **Trailing "every" clause** ends with `every <N><unit>` → extract interval, strip from prompt. Only match when followed by a time expression — `check every PR` has no interval.
6. **One-shot** — "remind me at/in", "at Xpm", "in N minutes" → schedule once (`recurring: false`)
7. **Default** — interval is `10m`, entire input is the prompt

If resulting prompt is empty, show usage `/claude-loop:loop [interval] <prompt>` and stop.

## Method Selection (Three-Tier)

**ALWAYS try Tier 1 first.** Do NOT skip to lower tiers without attempting.

### Tier 1: Load CronCreate via ToolSearch

CronCreate is a **deferred tool** in Claude Code — it exists in the infrastructure, not the model. It may be available on any provider but must be loaded first.

1. Call `ToolSearch("select:CronCreate,CronList,CronDelete")` to load the tools
2. **If loaded** → use the Cron Method below
3. **If ToolSearch fails or tools don't exist** → proceed to Tier 2

### Tier 2: Background Sleep Chain

Use when CronCreate is genuinely unavailable.

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

**Anti-spike:** For hourly+, never use minute 0 or 30 unless user requests exact time.

### How CronCreate Works

The `prompt` parameter is a **Claude prompt**, not a bash command. When the job fires, the prompt is fed back into the current Claude Code session on the next idle turn. Claude then interprets and executes it inline — output appears directly in the conversation.

### Execution

1. Parse interval and prompt
2. Convert to cron expression
3. `CronCreate`: `cron`, `prompt`, `recurring: true` (or `false` for one-shot)
4. Confirm: prompt, interval, cron, job ID, 3-day expiry note

### One-Time Reminders (Cron)

Parse target time → pin to cron fields → `CronCreate` with `recurring: false`.

### Managing Jobs (Cron)

- **List:** `CronList`
- **Cancel by ID:** `CronDelete` (8-char ID)
- **Cancel all:** `CronList` → `CronDelete` each

Max 50 tasks per session.

### Runtime Behavior

- **Session-scoped** — gone when Claude Code exits
- **Fires between turns** — only when idle, not mid-response
- **No catch-up** — missed fires execute once when idle
- **Local timezone** — not UTC
- **3-day expiry** — recurring auto-expire
- **Jitter** — recurring: up to 10% late (max 15 min); one-shot on :00/:30: up to 90s early

### Cron Reference

Standard 5-field: `minute hour day-of-month month day-of-week`. Supports `*`, values, `*/N` steps, ranges, lists. Day-of-week: 0 or 7 = Sunday.

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
- **Treat each fire as atomic and isolated.** Do not reflect on previous fires or accumulated loop history.
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

- **List:** Glob `/tmp/claude-loop-*.state`, read each, show active ones. Filter stale: if `session_pid` doesn't match a running process (`kill -0 <pid> 2>/dev/null`), skip and delete.
- **Stop by ID:** Delete `/tmp/claude-loop-<id>.state`. The next sleep notification will find no file and stop.
- **Stop by prompt substring:** Glob all state files, match prompt substring, delete. If multiple match, list and ask user to clarify.
- **Stop all:** Glob and delete all `/tmp/claude-loop-*.state`.

Max 20 concurrent jobs per session (check count before creating).

### Runtime Behavior

- **Session-scoped** — state files go stale when Claude exits; detected via `session_pid`
- **Fires between turns** — notification arrives when idle
- **Output inline** — Claude executes the prompt in the conversation, identical to Cron behavior
- **Minimum interval** — 1 minute (60 seconds)
- **Self-describing notifications** — `CLAUDE_LOOP_FIRE <id>` in background output identifies the job
- **No 3-day expiry** — runs until stopped or session ends
- **On prompt error** — log the error inline, continue the loop (don't stop on transient failures)
