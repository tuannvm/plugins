# Claude Plugins

**Claude Code plugin marketplace containing plugins for AI-powered development workflows.**

This marketplace contains plugins that transform Product Requirements Documents (PRDs) into working software through 5 specialized AI agents.

## Quick Start

### Installation

```bash
# Add marketplace
claude plugin marketplace add tuannvm/plugins

# Install pagent (Bash/Node implementation)
claude plugin install pagent@plugins

# Install pagent-ts (TypeScript implementation)
claude plugin install pagent-ts@plugins
```

### Usage

Once installed, run from any Claude Code session:

```bash
# Start a pipeline with your PRD
/pagent-run ./your-prd.md

# Check progress
/pagent-status

# Cancel if needed
/pagent-cancel
```

## Plugins

### [pagent](./plugins/pagent/)

Transform PRDs into architecture, test plans, security assessments, production-ready code, and verification reports through 5 specialized AI agents:

| Stage | Agent | Output |
|-------|-------|--------|
| 1 | architect | `architecture.md` |
| 2 | qa | `test-plan.md` |
| 2 | security | `security-assessment.md` |
| 3 | implementer | `code/` |
| 4 | verifier | `verification-report.md` |

**Documentation:** [Tutorial](./plugins/pagent/docs/tutorial.md) | [Architecture](./plugins/pagent/docs/architecture.md) | [Roadmap](./plugins/pagent/docs/roadmap.md)

### [pagent-ts](./plugins/pagent-ts/)

TypeScript implementation of the pagent pipeline with full type safety. Transforms PRDs into architecture, test plans, security assessments, production-ready code, and verification reports through 5 specialized AI agents.

**Documentation:** See [pagent-ts README](./plugins/pagent-ts/README.md)

## Marketplace Structure

```
plugins/
├── .claude-plugin/
│   └── marketplace.json      # Marketplace definition
├── plugins/
│   ├── pagent/               # Pagent plugin (Bash/Node)
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── commands/
│   │   ├── hooks/
│   │   ├── scripts/
│   │   ├── docs/             # Plugin documentation
│   │   ├── examples/         # PRD templates
│   │   └── README.md
│   └── pagent-ts/            # Pagent plugin (TypeScript)
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── src/
│       └── README.md
└── README.md
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
