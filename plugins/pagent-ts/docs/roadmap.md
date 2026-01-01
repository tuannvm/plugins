# Roadmap

> **pagent** transforms Product Requirements into working software through self-orchestrating AI agents.

## v2.0 (Current Development)

**Self-Orchestrating Pipelines via Claude Code Hooks**

See [ADR-003](decisions/003-self-orchestrating-pipelines.md) for full details.

### Architecture Shift

| Aspect | v1 (Deprecated) | v2 (Current) |
|--------|-----------------|--------------|
| Orchestrator | Go code (~500 lines) | Stop hooks (~80 lines bash) |
| Processes | 5 separate Claude Code instances | 1 instance |
| State | Resume JSON + runtime | Single `pipeline.json` |
| Communication | HTTP polling | Hook blocks exit |
| API | CLI only | HTTP + SSE |

### Implementation Phases

#### Phase 1: Proof of Concept 🔄 In Progress
- [ ] 2-stage pipeline (architect → qa)
- [ ] Validate Stop hook handoff mechanism
- [ ] Test with real PRDs

#### Phase 2: Full Pipeline
- [ ] All 5 agents with hook-based orchestration
- [ ] Validation gates (schema, checklist)
- [ ] Revision mechanism (go back N stages on failure)

#### Phase 3: API Server
- [ ] `claude-code-api` HTTP server (~150 lines Go)
- [ ] SSE streaming for real-time updates
- [ ] Workflow type registration

#### Phase 4: Examples & Documentation
- [ ] Usage examples (curl, Python, Go, JS)
- [ ] Workflow authoring guide
- [ ] Migration guide from v1

## v1.x (Legacy - Deprecated)

The v1 Go orchestrator architecture is deprecated. Key features shipped:

| Feature | Description |
|---------|-------------|
| **5-Agent Pipeline** | architect, qa, security, implementer, verifier |
| **Dependency Resolution** | Topological sort, parallel execution by level |
| **Resume State** | Content-hash based change detection |
| **TUI Dashboard** | Interactive terminal UI |
| **MCP Server** | Stdio + HTTP + OAuth 2.1 transport |

## v2.x Future Enhancements

| Priority | Feature | Description |
|----------|---------|-------------|
| P1 | Parallel Stages | Multi-session hooks for parallel execution |
| P1 | Validation Framework | Pluggable validators per stage |
| P2 | Cost Tracking | Token usage, estimated costs per run |
| P2 | Workflow Templates | Gallery of pre-built workflows |
| P3 | IDE Extensions | VS Code, JetBrains integration |
| P3 | Team Mode | Shared configs, audit logs |

### Multi-LLM Support (Deferred)

| Provider | Backend | v2 Status |
|----------|---------|-----------|
| Claude Code | Claude | ✅ Primary |
| Gemini CLI | Gemini | 📋 Future |
| Codex CLI | OpenAI | 📋 Future |

**Note:** v2 focuses on Claude Code hooks first. Multi-LLM support deferred until hooks pattern is proven.
