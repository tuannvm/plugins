# ADR-001: AgentAPI over Claude Agent SDK

**Date:** December 2025
**Status:** Accepted

## Context

We needed to orchestrate multiple Claude Code instances for a PM workflow. Options evaluated:

| Option | Description |
|--------|-------------|
| Claude Agent SDK | Official Anthropic SDK, TypeScript/Python |
| Mastra | TypeScript framework, 18k stars, Y Combinator backed |
| VoltAgent | TypeScript framework with built-in observability |
| AgentAPI | HTTP wrapper for Claude Code by Coder |

## Decision

Use **AgentAPI** for v1.

## Rationale

| Factor | AgentAPI | Claude Agent SDK |
|--------|----------|------------------|
| Integration | HTTP API calls | SDK integration |
| Language | Any (we chose Go) | TypeScript/Python |
| Process model | Each agent = separate process | Single process |
| Complexity | Low | Higher |
| Learning curve | Minimal | SDK abstractions |

**Trade-offs accepted:**
- No native hooks (must poll for status)
- No session persistence across runs
- Less fine-grained control

These are acceptable for a CLI tool prioritizing simplicity.

## Alternatives Rejected

### Claude Agent SDK
- Would require TypeScript/Node.js dependency
- More complex for a simple orchestrator
- Overkill for file-based communication

### Mastra / VoltAgent
- Neither integrates with Claude Code
- Would require implementing all tools from scratch
- Different LLM abstraction layer

## Consequences

- Single Go binary with minimal dependencies
- Simple HTTP-based agent communication
- Faster iteration during development
- Claude Agent SDK remains viable for v2 if more sophisticated orchestration needed
