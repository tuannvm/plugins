# Architecture

## Overview

### v2 (Current Design - Claude Code Plugin)

```
┌─────────────────────────────────────────────────────────┐
│              Claude Code with Pagent Plugin              │
│                                                         │
│  User runs: /pagent-run prd.md                          │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Plugin Command: setup-pipeline.sh               │  │
│  │  - Creates .claude/pagent-pipeline.json          │  │
│  │  - Initializes 5-stage workflow                 │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Stop Hook: pipeline-orchestrator.sh             │  │
│  │  - Reads pipeline state from .claude/            │  │
│  │  - Checks if current stage complete             │  │
│  │  - Blocks exit, injects next stage's prompt      │  │
│  │  - Updates state, advances to next stage        │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│     architect ──▶ qa ──▶ security ──▶ implementer ...   │
│     (same session, new prompt at each handoff)          │
└─────────────────────────────────────────────────────────┘
```

See [ADR-003](decisions/003-self-orchestrating-pipelines.md) for full details.

### v1 (Legacy - Go Orchestrator)

```
┌─────────────────────────────────────────────────┐
│              pagent CLI orchestrator            │
└─────────────────────┬───────────────────────────┘
                      │ HTTP (localhost)
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
   AgentAPI:3284  AgentAPI:3285  AgentAPI:3286
        │             │             │
        ▼             ▼             ▼
   Claude Code    Claude Code   Claude Code
        │             │             │
        └─────────────┴─────────────┘
                      │
               Shared filesystem
            (prd.md, outputs/*.md)
```

*v1 is deprecated. See migration guide in ADR-003.*

## Tech Stack

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Plugin Type | Claude Code Plugin | Native integration, hooks support |
| Orchestration | Stop hooks | Self-orchestrating pipelines |
| Commands | Slash commands | `/pagent-run`, `/pagent-status`, `/pagent-cancel` |
| State | JSON (pagent-pipeline.json) | Declarative, easy to parse |
| Output | Markdown | Universal, version-controllable |

## Project Structure

### v2 Structure (Claude Code Plugin)

```
pagent/
├── .claude-plugin/
│   └── plugin.json             # Plugin metadata
├── hooks/
│   ├── hooks.json              # Hook registration (Stop hook)
│   └── pipeline-orchestrator.sh # Main orchestrator logic
├── commands/                   # Slash commands
│   ├── pagent-run.md           # Start pipeline
│   ├── pagent-status.md        # Show progress
│   └── pagent-cancel.md        # Cancel pipeline
├── scripts/
│   └── setup-pipeline.sh       # Initialize pipeline state
└── docs/
```

### Plugin Installation

```bash
# Install as Claude Code plugin
claude plugin install /path/to/pagent

# Or clone and symlink
git clone https://github.com/tuannvm/pagent.git ~/.claude/plugins/pagent
```

### v1 Structure (Deprecated)

```
pagent/
├── cmd/pagent/main.go           # CLI entry point (includes mcp subcommand)
├── internal/
│   ├── agent/
│   │   ├── manager.go           # Agent lifecycle
│   │   └── orchestrator.go      # Interface for testability
│   ├── api/client.go            # AgentAPI HTTP client
│   ├── cmd/                     # CLI commands
│   ├── config/
│   │   ├── config.go            # YAML loading
│   │   └── options.go           # Shared RunOptions
│   ├── input/discover.go        # Input file discovery
│   ├── cmd/mcp.go               # MCP subcommand
│   ├── mcp/                     # MCP server package
│   │   ├── server.go            # Server + transport methods
│   │   ├── handlers.go          # Tool business logic
│   │   └── types.go             # Input/output types
│   ├── prompt/
│   │   ├── loader.go            # Template loading
│   │   └── templates/           # Embedded prompts
│   ├── runner/
│   │   ├── executor.go          # Shared execution logic
│   │   └── logger.go            # Logger interface
│   ├── state/resume.go          # Content-hash resume
│   ├── tui/                     # Interactive dashboard
│   └── types/types.go           # Shared type definitions
└── docs/
```

## Agents

### Design Principles

1. **Single owner per artifact**: One agent owns all code, another owns all tests
2. **Clear handoffs**: Specs → Code → Tests (linear)
3. **No overlap**: Eliminates file conflicts between agents

### Agent Pipeline

```
┌─────────────────── SPECIFICATION ───────────────────┐
│                                                      │
│  architect ──▶ qa ──▶ security                      │
│      │                                               │
│      ▼                                               │
│  architecture.md   test-plan.md   security.md       │
│                                                      │
├─────────────────── IMPLEMENTATION ──────────────────┤
│                                                      │
│  implementer ──────────▶ verifier                   │
│      │                       │                       │
│      ▼                       ▼                       │
│  code/*                  code/*_test.go             │
│                          verification-report.md     │
└──────────────────────────────────────────────────────┘
```

| Agent | Inputs | Outputs |
|-------|--------|---------|
| architect | PRD | `architecture.md` |
| qa | PRD, architecture | `test-plan.md` |
| security | PRD, architecture | `security-assessment.md` |
| implementer | PRD, architecture, security | `code/*` |
| verifier | PRD, all specs, code | `code/*_test.go`, `verification-report.md` |

## Key Components

### v2 Components (Plugin)

#### Pipeline State (`.claude/pagent-pipeline.json`)

The single source of truth for workflow execution:

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
    }
  ]
}
```

#### Stop Hook (`hooks/pipeline-orchestrator.sh`)

Orchestrates stage transitions by:
1. Reading current stage from `.claude/pagent-pipeline.json`
2. Checking if exit condition is met
3. Blocking exit and injecting next stage's prompt
4. Updating state to next stage
5. Allowing exit when pipeline complete

#### Commands

| Command | Purpose |
|---------|---------|
| `/pagent-run prd.md` | Start pipeline |
| `/pagent-status` | Show current stage and progress |
| `/pagent-cancel` | Cancel active pipeline |

#### Setup Script (`scripts/setup-pipeline.sh`)

Called by `/pagent-run` to:
1. Validate PRD file
2. Generate `.claude/pagent-pipeline.json`
3. Output initial prompt

### v1 Components (Deprecated)

```go
// Endpoints
GET  /status   → {"status": "running|stable"}
POST /message  → {"content": "...", "type": "user|raw"}
GET  /messages → {"messages": [...]}
```

**Startup sequence:**
1. Wait for API to respond (`WaitForHealthy`)
2. Wait for `"stable"` state (`WaitForStable`)
3. Send initial task message

### Orchestrator Interface (`internal/agent/orchestrator.go`)

```go
type Orchestrator interface {
    RunAgent(ctx context.Context, name string) Result
    TopologicalSort(agents []string) []string
    GetDependencyLevels(agents []string) [][]string
    ExpandWithDependencies(agents []string) []string
    GetTransitiveDependencies(agentName string) []string
    StopAll()
    GetRunningAgents() []*RunningAgent
}
```

Enables unit testing, mock implementations, and future extensibility.

### Resume State (`internal/state/resume.go`)

Content-hash based change detection (SHA-256):
- Input files hash
- Config hash (persona, stack, preferences)
- Dependency output hashes

State persisted to `.pagent/.resume-state.json`.

### Shared Execution (`internal/runner/executor.go`)

Both CLI and TUI share the same execution path:

```
pagent run    ─┐
               ├──▶ config.RunOptions ──▶ runner.Execute()
pagent ui    ─┘
```

## Execution Modes

### Dependency-Level Parallelism (default)

```
Level 0: architect
Level 1: qa, security (parallel)
Level 2: implementer
Level 3: verifier
```

Each level completes before the next starts.

### Sequential (`--sequential`)

Topological sort: `architect → qa → security → implementer → verifier`

### Resume (`--resume`)

Skips agents whose outputs are up-to-date based on content hashing.

## State Management

| Type | Location | Purpose |
|------|----------|---------|
| Runtime | `/tmp/pagent-state.json` | Port assignments for running agents |
| Resume | `.pagent/.resume-state.json` | Content hashes for change detection |

## TUI Architecture

```
cmd/ui.go ──▶ tui.RunDashboard() ──▶ config.RunOptions ──▶ runner.Execute()
```

- Single-screen form using [charmbracelet/huh](https://github.com/charmbracelet/huh)
- Smart defaults from config
- Advanced options in collapsible panel

## MCP Server Architecture

The MCP (Model Context Protocol) server enables integration with Claude Desktop, Claude Code, and other MCP clients.

```
┌─────────────────────────────────────────────────────────────┐
│                      MCP Clients                            │
│  (Claude Desktop, Claude Code, custom clients)              │
└─────────────────────────┬───────────────────────────────────┘
                          │ MCP Protocol (JSON-RPC 2.0)
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                    pagent mcp Server                        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                  Transport Layer                     │   │
│  │  stdio (default) │ HTTP (streamable) │ HTTP+OAuth   │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                   MCP Tools                          │   │
│  │  run_agent │ run_pipeline │ list_agents │ get_status│   │
│  │  send_message │ stop_agents                          │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                   Handlers                           │   │
│  │  Reuses internal/agent, internal/config              │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Package Structure (`internal/mcp/`)

| File | Purpose |
|------|---------|
| `server.go` | Server struct with `ServeStdio()`, `ServeHTTP()`, `ServeHTTPWithOAuth()` methods |
| `handlers.go` | Business logic wrapping `agent.Manager` |
| `types.go` | Input/output types with JSON schema annotations |

### Transport Modes

| Mode | Use Case | Protocol Version |
|------|----------|------------------|
| stdio | Claude Desktop, CLI piping | MCP 2025-11-25 |
| HTTP | Web integration, microservices | Streamable HTTP |
| HTTP+OAuth | Authenticated access | OAuth 2.1 (RFC 9728) |

### Tool Annotations (MCP 2025-11-25)

Tools include semantic hints for clients:

```go
&mcp.ToolAnnotations{
    Title:           "Run Pipeline",
    ReadOnlyHint:    false,        // Modifies state
    DestructiveHint: boolPtr(false), // Non-destructive
    IdempotentHint:  false,        // Not idempotent
    OpenWorldHint:   boolPtr(true), // Interacts with external systems
}
```

### Dependencies

| Package | Purpose |
|---------|---------|
| `github.com/modelcontextprotocol/go-sdk` | Official MCP SDK |
| `github.com/tuannvm/oauth-mcp-proxy` | OAuth 2.1 integration |
