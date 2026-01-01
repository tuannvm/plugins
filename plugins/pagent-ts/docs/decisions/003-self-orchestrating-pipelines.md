# ADR-003: Self-Orchestrating Pipelines via Claude Code API

**Date:** December 2025
**Status:** Accepted
**Supersedes:** ADR-001 (partially - AgentAPI still used but differently), ADR-002 (architecture - v2 supersedes v1)

## Context

Pagent v1 uses a Go orchestrator to spawn 5 separate Claude Code processes:

```
Go orchestrator → spawn architect → exit → spawn qa → exit → spawn implementer
```

**Problems identified:**
1. **5 separate processes** = 5× session overhead, 5 separate transcripts
2. **HTTP polling** = inefficient communication, wasted cycles
3. **Go orchestration logic** = complexity that could be declarative
4. **No validation gates** = agents can pass invalid outputs downstream
5. **Resume state** = complex content hashing spread across Go and JSON

Meanwhile, the **Ralph Wiggum technique** (from `claude-plugins-official`) demonstrated that Stop hooks can:
- Block agent exit
- Inject a new prompt into the same session
- Create self-referential feedback loops

This revealed that **Claude Code + hooks = general-purpose workflow engine**.

## Decision

Transition from "Go orchestrator + spawned processes" to **"single Claude Code session + self-orchestrating hooks"**.

## Architecture Comparison

### Before (v1)

```
┌─────────────────────────────────────────────────────────┐
│                    Go Orchestrator                       │
│  - Topological sort                                     │
│  - Dependency level calculation                         │
│  - HTTP polling loop                                    │
│  - Process lifecycle management                         │
└────────────────────┬────────────────────────────────────┘
                     │ termexec.StartProcess()
        ┌────────────┼────────────┬────────────┐
        ▼            ▼            ▼            ▼
   architect       qa      security     implementer
   (port 3284)  (port 3285)  (port 3286)  (port 3287)
        │            │            │            │
        └────────────┴────────────┴────────────┘
                     │
              Shared filesystem
```

### After (v2)

```
┌─────────────────────────────────────────────────────────┐
│                  claude-code-api                        │
│  ~150 lines of Go                                      │
│  - HTTP: POST /task                                    │
│  - Spawns Claude Code via AgentAPI                     │
│  - Streams output back                                 │
└────────────────────┬────────────────────────────────────┘
                     │ AgentAPI
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Claude Code (single session)               │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Stop Hook: Pipeline Orchestrator                │  │
│  │  - Read current stage from state file            │  │
│  │  - Check if stage complete                       │  │
│  │  - Block exit, inject next stage prompt          │  │
│  │  - Update state, advance to next stage           │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│     architect ──▶ qa ──▶ security ──▶ implementer       │
│     (same session, new prompt at each handoff)          │
└─────────────────────────────────────────────────────────┘
```

## Rationale

| Factor | v1 (Go Orchestrator) | v2 (Self-Orchestrating) |
|--------|---------------------|-------------------------|
| **Processes** | 5 separate Claude Code instances | 1 instance |
| **Orchestration** | Go code (~500 lines) | Bash hook (~80 lines) |
| **State** | Resume JSON + runtime state | Single pipeline.json |
| **Communication** | HTTP polling | Hook blocks exit |
| **Debugging** | 5 transcripts to sync | 1 transcript |
| **API overhead** | 5× session initialization | 1× |
| **Extensibility** | Edit Go, recompile | Edit bash, no rebuild |
| **Validation** | Post-hoc checks | Hook can block on invalid |

### Key Insight

**Claude Code + Hooks = General-purpose AI workflow engine.**

The Stop hook is a general-purpose control flow mechanism:

```json
// Hook output
{
  "decision": "block",  // Prevent exit
  "reason": "New prompt to inject",
  "systemMessage": "Optional context"
}
```

This enables:
1. **Stage transitions**: "qa" → "implementer" by injecting new prompt
2. **Validation gates**: Block if output invalid, request revision
3. **Self-orchestration**: Pipeline state drives flow, no external orchestrator needed
4. **External API**: Expose Claude Code as programmable service

### The Leanest Architecture

**The fundamental insight:** If hooks can orchestrate the entire pipeline, then pagent is just:

1. A thin API wrapper around Claude Code (~150 lines Go)
2. A pipeline definition (JSON + prompts)
3. Hook logic for orchestration (~80 lines bash)

**This makes "Claude Code as API" the core abstraction, not "pagent as orchestrator".**

Any tool can then use this API:
- `curl` for quick tasks
- Python scripts for automation
- Makefiles for CI/CD
- Web UIs for interactive use

**Pagent becomes an example workflow, not the core product.**

## Implementation

### API Design

The core API is a single endpoint that accepts any workflow definition:

```
POST /task
{
  "type": "prd-to-code",      // workflow type
  "input": "...",              // PRD content
  "config": {...}              // optional overrides
}
```

Response: Server-Sent Events stream
```
data: {"stage":"architect","status":"started"}
data: {"stage":"architect","output":"Creating architecture.md..."}
data: {"stage":"architect","status":"complete"}
data: {"stage":"qa","status":"started"}
...
data: {"stage":"verifier","status":"complete"}
```

### How It Works

1. API server receives request
2. Writes `prd.md` and generates `.claude/pipeline.json`
3. Spawns single Claude Code session via AgentAPI
4. Sends initial prompt for first stage
5. Stop hook orchestrates stage transitions
6. API server streams events back to client

### Pipeline State File

`.claude/pipeline.json`:
```json
{
  "stage": "architect",
  "stages": [
    {
      "name": "architect",
      "prompt": "Read prd.md and create architecture.md",
      "exit_when": "architecture.md exists and has >100 lines"
    },
    {
      "name": "qa",
      "prompt": "Read architecture.md and create test-plan.md",
      "exit_when": "test-plan.md exists"
    },
    {
      "name": "implementer",
      "prompt": "Implement code/ based on architecture.md and test-plan.md",
      "exit_when": "src/main.go exists and make test passes"
    }
  ]
}
```

### Stop Hook Logic

`.claude/hooks/pipeline-orchestrator.sh`:
```bash
#!/bin/bash
PIPELINE_STATE=".claude/pipeline.json"
STAGE=$(jq -r '.stage' "$PIPELINE_STATE")
STAGE_CONFIG=$(jq -r ".stages[] | select(.name==\"$STAGE\")" "$PIPELINE_STATE")

# Check exit condition
if check_exit_condition "$(jq -r '.exit_when' <<< "$STAGE_CONFIG")"; then
  # Stage complete - advance
  CURRENT_IDX=$(jq -r ".stages | to_entries | map(select(.value.name==\"$STAGE\"))[0].key" "$PIPELINE_STATE")
  NEXT_IDX=$((CURRENT_IDX + 1))
  NEXT=$(jq -r ".stages[$NEXT_IDX].name" "$PIPELINE_STATE")

  if [[ "$NEXT" == "null" ]]; then
    # Pipeline complete - allow exit
    exit 0
  fi

  # Update state
  jq ".stage = \"$NEXT\"" "$PIPELINE_STATE" > .tmp && mv .tmp "$PIPELINE_STATE"

  # Inject next prompt
  NEXT_PROMPT=$(jq -r ".stages[$NEXT_IDX].prompt" "$PIPELINE_STATE")
  jq -n --arg prompt "$NEXT_PROMPT" '{"decision":"block","reason":$prompt}'
  exit 0
fi

# Stage not complete - let agent continue
exit 0
```

### API Server

`cmd/server/main.go` (~150 lines):
```go
func main() {
    http.HandleFunc("/task", func(w http.ResponseWriter, r *http.Request) {
        var req struct {
            PRD       string                 `json:"prd"`
            Pipeline  string                 `json:"pipeline"`
            Config    map[string]interface{} `json:"config"`
        }
        json.NewDecoder(r.Body).Decode(&req)

        // 1. Write PRD to prd.md
        // 2. Generate .claude/pipeline.json
        // 3. Start Claude Code via AgentAPI
        // 4. Stream outputs to client
    })
    http.ListenAndServe(":8080", nil)
}
```

## Consequences

### Positive

1. **Dramatic simplification**: ~3000 lines of Go → ~200 lines Go + ~100 lines bash
2. **Better UX**: Single transcript to review, not 5
3. **Lower API cost**: 1 session overhead instead of 5
4. **Declarative pipelines**: JSON instead of Go code
5. **Easier debugging**: State file is plain JSON, hook is bash
6. **Reusable pattern**: Same approach works for ANY multi-stage workflow
7. **Generic API**: "Claude Code as API" is reusable beyond pagent
8. **Language agnostic**: Any tool can use the HTTP API

### Negative

1. **Single point of failure**: One crash = entire pipeline fails
2. **Sequential by default**: Parallel execution requires more complex hook logic
3. **Learning curve**: Users need to understand hooks

### Trade-offs Accepted

- **No Go orchestration logic**: Hooks are simpler but less powerful than Go
- **Sequential stages**: Parallel execution possible but requires multi-session hook
- **Bash dependency**: Hook logic is bash, not Go (but could be any executable)

## Migration Path

### Phase 1: Proof of Concept (Week 1)
- [ ] Implement 2-stage pipeline (architect → qa)
- [ ] Validate Stop hook handoff mechanism
- [ ] Test with real PRDs
- [ ] Document patterns and gotchas

**Deliverable:** Working 2-stage pipeline with self-orchestration

### Phase 2: Full Pipeline (Week 2)
- [ ] Migrate all 5 agents to hook-based orchestration
- [ ] Add validation gates (architecture schema, test plan checklist)
- [ ] Implement revision mechanism (if validation fails, go back N stages)
- [ ] Add comprehensive error handling

**Deliverable:** Full 5-stage pipeline with validation

### Phase 3: API Server (Week 3)
- [ ] Build `claude-code-api` server (~150 lines Go)
- [ ] Implement SSE streaming for real-time updates
- [ ] Add workflow type registration (extensible pipeline system)
- [ ] Document REST interface with OpenAPI spec

**Deliverable:** HTTP API that can run any hook-based workflow

### Phase 4: Examples & Documentation (Week 4)
- [ ] Add usage examples (curl, Python, Go, JavaScript)
- [ ] Create workflow authoring guide
- [ ] Document hook patterns (stage transition, validation, parallel execution)
- [ ] Write migration guide from v1

**Deliverable:** Production-ready documentation and examples

### Phase 5: Deprecation (Future)
- [ ] Mark Go orchestrator as deprecated in v2.x
- [ ] Provide automated migration tool
- [ ] Remove Go orchestrator in v3.0

## Alternatives Considered

### Keep Go Orchestrator (v1)
- **Rejected**: Too complex for the value provided
- **Rationale**: Hooks provide cleaner orchestration mechanism with same determinism

### Rewrite with Task Tool (Path B from plan.md)
- **Rejected**: LLM-based orchestration is non-deterministic
- **Rationale**: Declarative pipeline.json is more predictable, testable, and debuggable

### Hybrid: Go + Hooks
- **Rejected**: Adds complexity without benefit
- **Rationale**: Either Go orchestrates OR hooks do, not both. Having two orchestration mechanisms creates confusion.

### No API, Just CLI
- **Rejected**: Limits usefulness to command-line only
- **Rationale**: API enables integration with any tool (CI/CD, web UIs, scripts). The API wrapper is only ~150 lines anyway.

## References

- Ralph Wiggum plugin: https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ralph-wiggum
- Claude Code hooks: https://docs.anthropic.com/en/docs/claude-code/hooks
- AgentAPI: https://github.com/coder/agentapi
