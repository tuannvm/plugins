# Architecture

## Ralph Loop Orchestrator

Pagent uses a **Ralph-style loop** to orchestrate multi-stage pipelines.

```
┌─────────────────────────────────────────────────────────────────┐
│                    Pagent Ralph Loop                           │
│                                                                  │
│  while (!pipeline_complete) {                                   │
│    stage = read_current_stage()                                  │
│    prompt = get_prompt_for_stage(stage)                          │
│                                                                  │
│    // Inject prompt via stop hook                                │
│    block_exit()                                                   │
│    inject(prompt)                                                 │
│                                                                  │
│    [Claude executes prompt]                                      │
│                                                                  │
│    if (stage_exit_condition_met()) {                             │
│      advance_to_next_stage()                                    │
│    }                                                             │
│    // else: loop again on same stage                            │
│  }                                                               │
│                                                                  │
│  output("Pipeline complete!")                                    │
└─────────────────────────────────────────────────────────────────┘
```

## Per-Stage Looping

Each stage loops until its exit condition is met:

| Stage | Exit Condition | Loops Until |
|-------|--------------|-------------|
| Architect | `architecture.md` exists with 50+ lines | File is complete |
| QA | `test-plan.md` exists with 30+ lines | File is complete |
| Security | `security-assessment.md` exists with 20+ lines | File is complete |
| Implementer | `src/` directory with 3+ files | Code is complete |
| Verifier | `<promise>DONE</promise>` in output | Verification done |

## State Management

Pipeline state is stored in `.claude/pagent-pipeline.json`:

```json
{
  "stage": "architect",
  "started_at": "2025-12-31T12:00:00Z",
  "prd_file": "my-prd.md",
  "prd_path": "/full/path/to/my-prd.md",
  "iterations": {
    "architect": 3,
    "qa": 1
  },
  "stages": [...]
}
```

- `stage`: Current active stage
- `iterations`: Tracks how many loops each stage has taken
- `prd_path`: Full path to PRD for prompt substitution

## Stop Hook Flow

1. **On exit attempt**, stop hook runs
2. **Read current stage** from state
3. **Increment iteration counter** for this stage
4. **Check exit condition**:
   - If met → advance to next stage, inject next prompt
   - If not met → stay on current stage, inject same prompt (loop)
5. **Block exit** with `{"decision": "block"}` and new prompt

## Stage Transitions

```
Stage: architect (iteration 1)
  Exit condition NOT met
    ↓
  Block exit, inject SAME prompt (iteration 2)
    ↓
Stage: architect (iteration 2)
  Exit condition MET!
    ↓
  Advance to qa, inject NEW prompt
    ↓
Stage: qa (iteration 1)
  Exit condition MET!
    ↓
  Advance to security...
```

## Files

| File | Purpose |
|------|---------|
| `.claude/pagent-pipeline.json` | Pipeline state |
| `.claude/prompts/*.txt` | Prompt templates (PRD_PATH substituted) |
| `hooks/pipeline-orchestrator.sh` | Ralph loop stop hook |
| `scripts/setup-pipeline.sh` | Initialize pipeline |

## Human-Like Behavior

This mimics how a human developer works:

1. **Pick up a task** (stage)
2. **Work on it** (execute prompt)
3. **Not done yet?** Keep working (loop)
4. **Done?** Move to next task (advance stage)
5. **Repeat** until everything is complete

The Ralph loop enables this autonomous, iterative behavior.
