# Tutorial

## Prerequisites

- [Claude Code](https://claude.ai/claude-code) installed and authenticated
  ```bash
  claude --version
  ```

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/tuannvm/pagent.git
   cd pagent
   ```

2. **Install as a local plugin:**
   ```bash
   # Add the local marketplace
   claude plugin marketplace add $(pwd)

   # Install the plugin
   claude plugin install pagent@pagent-local
   ```

3. **Verify installation:**
   ```bash
   claude plugin list | grep pagent
   ```

## Quick Start

### 1. Prepare Your PRD

Create a PRD file with:

```markdown
# Product: My Project

## Problem Statement
What problem are we solving?

## Requirements
- Functional requirement 1
- Functional requirement 2

## Constraints
- Technical constraints
- Budget/timeline constraints

## Success Criteria
- Measurable success criteria
```

See [`examples/sample-prd.md`](../examples/sample-prd.md) for a complete template.

### 2. Start a Pipeline

In Claude Code, run:

```
/pagent-run ./your-prd.md
```

The pipeline will:
1. Parse your PRD
2. Create an `outputs/` directory
3. Start the **architect** agent

### 3. Monitor Progress

Check status at any time:

```
/pagent-status
```

This shows:
- Current stage (architect, qa, security, implementer, verifier)
- Progress within the stage
- Estimated time remaining

### 4. Cancel if Needed

```
/pagent-cancel
```

## Pipeline Stages

| Stage | Agent | Output | Duration |
|-------|-------|--------|----------|
| 1 | architect | `architecture.md` | ~5 min |
| 2 | qa | `test-plan.md` | ~3 min |
| 2 | security | `security-assessment.md` | ~3 min |
| 3 | implementer | `code/` directory | ~10 min |
| 4 | verifier | `verification-report.md` | ~5 min |

Stages 2 (qa + security) run in parallel.

## Output Structure

```
outputs/
├── architecture.md           # System design
├── test-plan.md              # Test strategy
├── security-assessment.md    # Security review
├── code/                     # Generated codebase
│   ├── src/
│   ├── tests/
│   ├── Dockerfile
│   └── README.md
└── verification-report.md    # Test results
```

## How the Pipeline Works

Pagent uses **self-orchestrating hooks**:

1. `/pagent-run` initializes the pipeline state in `.claude/pagent-pipeline.json`
2. After each agent completes, a **stop hook** automatically:
   - Reads the current state
   - Determines the next stage
   - Updates the prompt for the next agent
3. The pipeline continues until all stages complete

This happens within a single Claude Code session - no external orchestration needed.

## Example Workflow

```bash
# 1. Start the pipeline
/pagent-run ./my-product-prd.md

# Output: Starting architect stage...
# [Claude works on architecture]

# 2. Check progress
/pagent-status

# Output: Current stage: architect (in progress)
#         Next: qa, security (parallel)

# 3. After architect completes, hook automatically launches qa + security
# [Claude works on qa and security in parallel]

# 4. After qa + security complete, hook launches implementer
# [Claude writes code]

# 5. Finally, verifier runs tests
# [Claude verifies the implementation]

# Pipeline complete!
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `/pagent-run` not found | Plugin not installed - run `claude plugin install pagent@pagent-local` |
| Pipeline stuck | Use `/pagent-status` to check current stage |
| Need to restart | `/pagent-cancel` then `/pagent-run` again |
| Outputs missing | Check `outputs/` directory exists |

## Advanced Usage

### Custom Output Directory

The pipeline always outputs to `./outputs/`. To use a different location, symlink it:

```bash
ln -s /path/to/custom/outputs ./outputs
```

### Running Specific Stages

The pipeline always runs all 5 stages in order. To run a single stage:

1. Start the full pipeline
2. Cancel after the desired stage completes
3. Use the output files directly

### Session Persistence

Pipeline state is stored in `.claude/pagent-pipeline.json`. If you close Claude Code mid-pipeline:

1. Reopen Claude Code
2. Check `/pagent-status` to see where you left off
3. Manually continue from that stage (automatic resume is planned)

## Architecture

See [architecture.md](architecture.md) for technical details on:
- Plugin structure
- Hook orchestration
- State management
- Agent prompts

## Next Steps

- Review [`examples/sample-prd.md`](../examples/sample-prd.md) for PRD templates
- Read [architecture.md](architecture.md) for internals
- Check [roadmap.md](roadmap.md) for planned features
