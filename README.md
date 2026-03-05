# Claude Plugins

**Claude Code plugin marketplace containing plugins for AI-powered development workflows.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This marketplace contains plugins that transform Product Requirements Documents (PRDs) into working software through 5 specialized AI agents.

## Quick Start

### Installation

```bash
# Add marketplace
claude plugin marketplace add tuannvm/plugins

# Install local plugins
claude plugin install pagent@plugins           # PRD-to-code pipeline (Bash/Node)
claude plugin install pagent-ts@plugins        # PRD-to-code pipeline (TypeScript)
claude plugin install ralph-wiggum@plugins     # Iterative AI loops

# Install Google Workspace skills (fetched from remote)
claude plugin install gws-calendar@plugins     # Calendar management
claude plugin install gws-gmail@plugins        # Email operations
claude plugin install gws-drive@plugins        # File management
# ... and more
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

### [pagent](./plugins/pagent/) [![version](https://img.shields.io/badge/version-0.0.1-blue)](./plugins/pagent/)

Transform PRDs into architecture, test plans, security assessments, production-ready code, and verification reports through 5 specialized AI agents:

| Stage | Agent | Output |
|-------|-------|--------|
| 1 | architect | `architecture.md` |
| 2 | qa | `test-plan.md` |
| 2 | security | `security-assessment.md` |
| 3 | implementer | `code/` |
| 4 | verifier | `verification-report.md` |

**Documentation:** [Tutorial](./plugins/pagent/docs/tutorial.md) | [Architecture](./plugins/pagent/docs/architecture.md) | [Roadmap](./plugins/pagent/docs/roadmap.md)

### [pagent-ts](./plugins/pagent-ts/) [![version](https://img.shields.io/badge/version-0.0.1-blue)](./plugins/pagent-ts/)

TypeScript implementation of the pagent pipeline with full type safety. Transforms PRDs into architecture, test plans, security assessments, production-ready code, and verification reports through 5 specialized AI agents.

**Documentation:** See [pagent-ts README](./plugins/pagent-ts/README.md)

### [ralph-wiggum](./plugins/ralph-wiggum/) [![version](https://img.shields.io/badge/version-0.1.0-blue)](./plugins/ralph-wiggum/)

Implementation of the Ralph Wiggum technique - continuous self-referential AI loops for iterative development. Run Claude in a loop with the same prompt until task completion using a Stop hook that intercepts exit attempts.

**Documentation:** See [ralph-wiggum README](./plugins/ralph-wiggum/README.md)

## Google Workspace Skills

The [Google Workspace CLI](https://github.com/googleworkspace/cli) provides 100+ skills for Gmail, Calendar, Drive, Docs, Sheets, Chat, Meet, Tasks and more.

### Installation

```bash
# Add the marketplace first
claude plugin marketplace add tuannvm/plugins

# Install individual skills as needed
claude plugin install gws-calendar@plugins
claude plugin install gws-gmail@plugins
claude plugin install gws-drive@plugins
# ... or install all at once
claude plugin install gws-*@plugins
```

### Available Skills

#### Core Workspace APIs

| Skill | Description |
|-------|-------------|
| `gws-calendar` | Manage calendars and events |
| `gws-gmail` | Email operations and management |
| `gws-drive` | File and folder management |
| `gws-sheets` | Spreadsheet operations and data management |
| `gws-docs` | Document creation and editing |
| `gws-slides` | Presentation creation and editing |
| `gws-meet` | Video conferencing management |
| `gws-chat` | Team messaging and communication |
| `gws-tasks` | Task and to-do list management |
| `gws-forms` | Survey and form creation |
| `gws-people` | Contact management |
| `gws-workflow` | Workflow automation utilities |

#### Persona Assistants

| Skill | Description |
|-------|-------------|
| `persona-assistants` | Role-based AI assistants (content creator, customer support, event coordinator, exec assistant, HR coordinator, IT admin, project manager, researcher, sales ops, team lead) |

#### Workflow Recipes

| Skill | Description |
|-------|-------------|
| `recipe-workflows` | Curated workflow automation recipes (bulk email, file management, meeting prep, reports, and more) |

### Usage Examples

```bash
# Calendar
/gws-calendar list
/gws-calendar create --title "Team Meeting" --time "2026-03-06 10:00"

# Gmail
/gws-gmail send --to user@example.com --subject "Hello" --body "Hi there!"
/gws-gmail list --label inbox

# Drive
/gws-drive list
/gws-drive upload --file ./document.pdf

# Workflow recipes
/recipe-bulk-invite-to-event
/recipe-create-meeting-prep
```

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
│   ├── pagent-ts/            # Pagent plugin (TypeScript)
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── src/
│   │   └── README.md
│   └── ralph-wiggum/         # Ralph Wiggum iterative loops
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── commands/
│       ├── hooks/
│       ├── scripts/
│       └── README.md
└── README.md
```

**Note:** Google Workspace skills are fetched directly from the [googleworkspace/cli](https://github.com/googleworkspace/cli) repository using `git-subdir` source type, so they don't have local plugin directories.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
