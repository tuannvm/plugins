# Claude Plugins

**Claude Code plugin marketplace containing plugins for AI-powered development workflows.**

This marketplace currently contains the **pagent** plugin - a tool that transforms Product Requirements Documents (PRDs) into working software through 5 specialized AI agents.

## Quick Start

### Installation

```bash
# Clone this repository
git clone https://github.com/tuannvm/claude-plugins.git
cd claude-plugins

# Add as a local marketplace
claude plugin marketplace add $(pwd)

# Install the pagent plugin
claude plugin install pagent@claude-plugins
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

## Marketplace Structure

```
claude-plugins/
├── .claude-plugin/
│   └── marketplace.json      # Marketplace definition
├── plugins/
│   └── pagent/               # Pagent plugin
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── commands/
│       ├── hooks/
│       ├── scripts/
│       ├── docs/             # Plugin documentation
│       ├── examples/         # PRD templates
│       └── README.md
└── README.md
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
