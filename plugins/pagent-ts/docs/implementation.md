# Implementation Guide: Pagent Claude Code Plugin

This document details the v2 plugin architecture for pagent.

## Overview

The v2 architecture is a **Claude Code Plugin** that provides:

1. **Commands** - `/pagent-run`, `/pagent-status`, `/pagent-cancel`
2. **Stop Hook** - `pipeline-orchestrator.sh` for automatic stage transitions
3. **Setup Script** - `setup-pipeline.sh` for pipeline initialization

```
~250 lines bash  +  ~100 lines markdown (commands)  =  Complete plugin
```

## Plugin Structure

```
pagent/
├── .claude-plugin/
│   └── plugin.json             # Plugin metadata
├── hooks/
│   ├── hooks.json              # Hook registration
│   └── pipeline-orchestrator.sh # Stop hook implementation
├── commands/                   # Slash commands
│   ├── pagent-run.md
│   ├── pagent-status.md
│   └── pagent-cancel.md
└── scripts/
    └── setup-pipeline.sh       # Pipeline initialization
```

## Component 1: Plugin Metadata

### File: `.claude-plugin/plugin.json`

**Purpose:** Plugin identity and metadata.

```json
{
  "name": "pagent",
  "description": "Product Requirement Document (PRD) to working software through 5 specialized AI agents.",
  "version": "2.0.0",
  "author": {
    "name": "tuannvm",
    "email": "pagent-maintainers"
  },
  "capabilities": [
    "pipeline_orchestration",
    "multi_agent_coordination",
    "prd_transformation"
  ]
}
```

## Component 2: Hook Registration

### File: `hooks/hooks.json`

**Purpose:** Register the Stop hook with Claude Code.

```json
{
  "description": "Pagent Stop hook for multi-stage pipeline orchestration",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pipeline-orchestrator.sh"
          }
        ]
      }
    ]
  }
}
```

**Key Point:** Uses `${CLAUDE_PLUGIN_ROOT}` variable so the hook works regardless of where the plugin is installed.

## Component 3: Stop Hook

### File: `hooks/pipeline-orchestrator.sh`

**Purpose:** Intercept Claude exit attempts, check stage completion, and transition to next stage.

**Key Functions:**

1. **`check_exit_condition()`** - Validates if current stage is complete
   - `file_exists` - Check if file exists with minimum lines
   - `directory_exists` - Check if directory exists with minimum files
   - `promise_in_output` - Check if completion promise in transcript
   - `all_files_exist` - Check multiple files
   - `custom` - Run custom validation script

2. **Main flow:**
   ```bash
   # Read pipeline state from .claude/pagent-pipeline.json
   # Get current stage and exit condition
   # If exit condition met:
   #   - Advance to next stage
   #   - Update state file
   #   - Block exit, inject next stage's prompt
   # If last stage complete:
   #   - Allow exit (pipeline done)
   # Otherwise:
   #   - Allow agent to continue working
   ```

**Exit JSON Format:**
```bash
# Block exit, inject new prompt
jq -n \
  --arg prompt "You are QA. Read architecture.md..." \
  --arg msg "Stage: qa" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'
```

## Component 4: Commands

### /pagent-run

**File:** `commands/pagent-run.md`

**Purpose:** Start a pagent pipeline.

**Usage:**
```
/pagent-run prd.md
/pagent-run prd.md --workflow prd-to-code
/pagent-run prd.md --max-stages 3
```

**Implementation:** Calls `scripts/setup-pipeline.sh` to generate pipeline state.

### /pagent-status

**File:** `commands/pagent-status.md`

**Purpose:** Show current pipeline status.

**Usage:**
```
/pagent-status
```

**Output:**
```
🤖 Pagent Pipeline Status

Current Stage: implementer (4/5)
Started: 12:00 UTC (15 minutes ago)

Stages:
  ✅ architect       → architecture.md (142 lines)
  ✅ qa              → test-plan.md (87 lines)
  ✅ security        → security-assessment.md (64 lines)
  🔄 implementer     → Working on src/...
  ⏳ verifier        → Waiting
```

### /pagent-cancel

**File:** `commands/pagent-cancel.md`

**Purpose:** Cancel an active pipeline.

**Usage:**
```
/pagent-cancel
```

## Component 5: Setup Script

### File: `scripts/setup-pipeline.sh`

**Purpose:** Initialize pipeline state when `/pagent-run` is invoked.

**Arguments:**
1. PRD file path
2. Workflow type (default: `prd-to-code`)
3. Maximum stages (default: 0 = unlimited)

**Flow:**
1. Validate PRD file exists and has content
2. Create `.claude/` directory
3. Generate `.claude/pagent-pipeline.json` with all stages
4. Output summary and initial prompt

**Pipeline State Generated:**

```json
{
  "stage": "architect",
  "max_stages": 0,
  "workflow_type": "prd-to-code",
  "started_at": "2025-12-29T12:00:00Z",
  "prd_file": "prd.md",
  "stages": [
    {
      "name": "architect",
      "prompt": "You are the architect...",
      "exit_when": {"file_exists": "architecture.md", "min_lines": 50}
    },
    {
      "name": "qa",
      "prompt": "You are the QA engineer...",
      "exit_when": {"file_exists": "test-plan.md", "min_lines": 30}
    },
    {
      "name": "security",
      "prompt": "You are the security analyst...",
      "exit_when": {"file_exists": "security-assessment.md", "min_lines": 20}
    },
    {
      "name": "implementer",
      "prompt": "You are the implementer...",
      "exit_when": {"directory_exists": "src", "min_files": 3}
    },
    {
      "name": "verifier",
      "prompt": "You are the verifier...",
      "exit_when": {"promise_in_output": "DONE"}
    }
  ]
}
```

**Purpose:** Declarative workflow specification.

**Schema:**
```json
{
  "name": "prd-to-code",
  "description": "Transform PRD into working software through 5 specialized agents",
  "stages": [
    {
      "name": "architect",
      "prompt": "You are the architect. Read prd.md and create architecture.md...",
      "exit_when": {"file_exists": "architecture.md", "min_lines": 50}
    },
    {
      "name": "qa",
      "prompt": "You are the QA engineer. Read architecture.md and create test-plan.md...",
      "exit_when": {"file_exists": "test-plan.md", "min_lines": 30}
    },
    {
      "name": "security",
      "prompt": "You are the security analyst. Read architecture.md and create security-assessment.md...",
      "exit_when": {"file_exists": "security-assessment.md", "min_lines": 20}
    },
    {
      "name": "implementer",
      "prompt": "You are the implementer. Read all specs and implement code...",
      "exit_when": {"directory_exists": "src", "min_files": 3}
    },
    {
      "name": "verifier",
      "prompt": "You are the verifier. Review all work and add tests...",
      "exit_when": {"promise_in_output": "DONE"}
    }
  ]
}
```

**Note:** The pipeline.json is generated by `setup-pipeline.sh`, not stored as a static file.

## Installation

### Install as Claude Code Plugin

```bash
# Clone the repository
git clone https://github.com/tuannvm/pagent.git ~/.claude/plugins/pagent

# Or install from local directory
claude plugin install /path/to/pagent
```

### Verify Installation

```bash
# In Claude Code, run:
/help pagent-run

# Should show the command help
```

## Usage

### Starting a Pipeline

```bash
# In Claude Code, navigate to your project directory
cd /path/to/project

# Run pagent with your PRD
/pagent-run prd.md

# The pipeline will run autonomously
# Check status anytime
/pagent-status
```

### What Happens

1. **Setup**: `setup-pipeline.sh` generates `.claude/pagent-pipeline.json`
2. **Architect Stage**: Creates `architecture.md`
3. **Hook Detects Completion**: `architecture.md` exists with 50+ lines
4. **Auto-Transition**: Hook injects QA prompt
5. **QA Stage**: Creates `test-plan.md`
6. ...continues through all 5 stages...
7. **Complete**: Verifier outputs `<promise>DONE</promise>`

### Canceling

```bash
/pagent-cancel
```

## Directory Structure After Run

```
project/
├── prd.md                          # Your input
├── architecture.md                 # Stage 1 output
├── test-plan.md                    # Stage 2 output
├── security-assessment.md          # Stage 3 output
├── src/                            # Stage 4 output
│   ├── main.go
│   ├── auth.go
│   └── api.go
├── verification-report.md          # Stage 5 output
├── README.md                       # Created by implementer
└── .claude/
    └── pagent-pipeline.json        # Pipeline state (completed)
```

## Exit Conditions

The hook supports several exit condition types:

| Type | Example | Description |
|------|---------|-------------|
| `file_exists` | `{"file_exists": "architecture.md", "min_lines": 50}` | File exists with minimum lines |
| `directory_exists` | `{"directory_exists": "src", "min_files": 3}` | Directory exists with minimum files |
| `promise_in_output` | `{"promise_in_output": "DONE"}` | Promise tag appears in transcript |
| `all_files_exist` | `{"all_files_exist": ["a.md", "b.md"]}` | All files exist |
| `custom` | `{"custom": ".claude/validate.sh"}` | Run custom script |

## Testing

### Manual Testing

```bash
# Create test PRD
cat > test-prd.md <<'EOF'
# Test PRD

Build a simple REST API for todo items.
- CRUD operations
- Input validation
- Tests
EOF

# Run pipeline
/pagent-run test-prd.md

# Wait for completion (5-15 minutes)
/pagent-status

# Review outputs
cat architecture.md
cat test-plan.md
ls -la src/
```

### Hook Testing

```bash
# Test exit condition function directly
source hooks/pipeline-orchestrator.sh

# Test file_exists
check_exit_condition '{"file_exists":"test.md","min_lines":10}' /tmp /tmp/transcript.jsonl

# Test directory_exists
check_exit_condition '{"directory_exists":"src","min_files":3}' /tmp /tmp/transcript.jsonl
```

## Troubleshooting

### Hook Not Firing

**Symptom:** Agent exits immediately, next stage doesn't start.

**Debug:**
```bash
# Check hook is executable
ls -la ~/.claude/plugins/pagent/hooks/pipeline-orchestrator.sh

# Check hook registration
cat ~/.claude/plugins/pagent/hooks/hooks.json

# Check pipeline state
cat .claude/pagent-pipeline.json | jq
```

### Pipeline State Not Updating

**Symptom:** Stage doesn't advance, agent stuck.

**Debug:**
```bash
# Check state file
cat .claude/pagent-pipeline.json | jq

# Verify exit condition met
ls -la architecture.md
wc -l architecture.md

# Check hook logs (stderr appears in Claude output)
```

### Plugin Not Found

**Symptom:** `/pagent-run` command not found.

**Debug:**
```bash
# Check plugin directory
ls -la ~/.claude/plugins/

# Verify plugin structure
ls -la ~/.claude/plugins/pagent/

# Reinstall
claude plugin install /path/to/pagent
```

## References

- [ADR-003: Self-Orchestrating Pipelines](decisions/003-self-orchestrating-pipelines.md)
- [Claude Code Hooks Documentation](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Ralph Wiggum Plugin](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ralph-wiggum)
