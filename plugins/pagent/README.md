# Pagent

Transform Product Requirement Documents (PRDs) into working software through 5 specialized AI agents.

## Commands

| Command | Description |
|---------|-------------|
| `/pagent-run <prd-file>` | Start pipeline with a PRD file |
| `/pagent-status` | Show current stage and progress |
| `/pagent-cancel` | Cancel active pipeline |

## Pipeline Stages

| Stage | Agent | Output | Description |
|-------|-------|--------|-------------|
| 1 | architect | `architecture.md` | System design, API contracts, data models |
| 2 | qa | `test-plan.md` | Test strategy, test cases, acceptance criteria |
| 2 | security | `security-assessment.md` | Threat model, security recommendations |
| 3 | implementer | `code/` | Complete, production-ready codebase |
| 4 | verifier | `verification-report.md` | Tests run, validation results |

## Quick Start

```bash
# Start a pipeline with your PRD
/pagent-run ./your-prd.md

# Check progress
/pagent-status

# Cancel if needed
/pagent-cancel
```

## PRD Format

Your PRD should include:

- **Problem statement** - What are we solving?
- **Requirements** - Functional and non-functional requirements
- **Constraints** - Technical, business, or timing constraints
- **Success criteria** - How do we know it's done?

See [examples/](./examples/) for PRD templates.

## How It Works

Pagent uses a **self-orchestrating pipeline**:

1. `/pagent-run` initializes the pipeline state
2. After each agent completes, a **stop hook** automatically:
   - Reads the current state
   - Determines the next stage
   - Updates the prompt for the next agent
3. The pipeline continues until all stages complete

This happens within a single Claude Code session - no external orchestration needed.

## Outputs

```
outputs/
├── architecture.md           # System design
├── test-plan.md              # Test strategy
├── security-assessment.md    # Security review
├── code/                     # Generated codebase
│   ├── src/
│   ├── tests/
│   └── README.md
└── verification-report.md    # Test results
```

## Documentation

| Doc | Content |
|-----|---------|
| [Tutorial](./docs/tutorial.md) | Step-by-step usage guide |
| [Architecture](./docs/architecture.md) | Technical design and internals |
| [Roadmap](./docs/roadmap.md) | Future plans |
| [Examples](./examples/) | PRD templates |
