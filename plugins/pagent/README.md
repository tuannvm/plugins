# Pagent

Transform PRDs into working software through AI agents.

## Quick Start

```bash
/pagent-run your-prd.md
```

That's it. The Ralph loop orchestrates 5 stages automatically.

## What You Get

```
your-project/
├── your-prd.md              # Your input
├── architecture.md          # System design
├── test-plan.md             # Test strategy
├── security-assessment.md   # Security review
├── verification-report.md   # Verification results
└── src/                     # Production code
    ├── main.go
    ├── go.mod
    └── ...
```

## Commands

| Command | What it does |
|---------|-------------|
| `/pagent-run <prd>` | Start pipeline |
| `/pagent-status` | Show current stage |
| `/pagent-cancel` | Stop pipeline |

## Try the Example

```bash
cd examples
/pagent-run sample-prd.md
```

You'll get a complete Task Management API in Go.

## How It Works

Pagent uses a **Ralph-style loop** that mimics human development:

```
while (!complete) {
  current_stage = get_stage()
  prompt = get_prompt(current_stage)

  // Work on stage
  execute(prompt)

  // Check if done
  if (stage_complete()) {
    next_stage()
  } else {
    // Retry same stage (Ralph loop)
    continue
  }
}
```

### The 5 Stages

| Stage | Output | Iterates until... |
|-------|--------|-------------------|
| Architect | `architecture.md` | File exists with 50+ lines |
| QA | `test-plan.md` | File exists with 30+ lines |
| Security | `security-assessment.md` | File exists with 20+ lines |
| Implementer | `src/` | Directory with 3+ files |
| Verifier | `verification-report.md` | `<promise>DONE</promise>` output |

Each stage loops until its exit condition is met. Then it advances to the next stage.

## Human-Like Development

Just like a human developer:
- Iterate on a task until it's done
- Move to the next task
- Repeat until everything is complete

No manual intervention needed.

## Documentation

- [Tutorial](docs/tutorial.md) - Step-by-step guide
- [Architecture](docs/architecture.md) - Technical details
- [Examples](examples/) - PRD templates
