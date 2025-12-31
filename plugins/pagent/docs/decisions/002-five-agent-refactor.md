# ADR-002: Five-Agent Refactor

**Date:** December 2025
**Status:** Accepted

## Context

Original design had 8 agents:

| Agent | Type | Issue |
|-------|------|-------|
| design | spec | — |
| tech | spec | — |
| qa | spec | — |
| security | spec | — |
| infra | spec | — |
| backend | code | Conflicts with database on `db.go` |
| database | code | Conflicts with backend |
| tests | code | Depends on both conflicting agents |

**Problem:** `backend` and `database` both touched `internal/db/` area, causing file conflicts.

## Decision

Consolidate to **5 agents** with clear boundaries:

| Phase | Agent | Output |
|-------|-------|--------|
| Spec | architect | `architecture.md` (merges design + tech + infra) |
| Spec | qa | `test-plan.md` |
| Spec | security | `security-assessment.md` |
| Impl | implementer | `code/*` (all code, no conflicts) |
| Impl | verifier | `code/*_test.go`, `verification-report.md` |

## Rationale

1. **Single owner per artifact**: `implementer` owns ALL code, `verifier` owns ALL tests
2. **No overlap**: Eliminates file conflicts
3. **Clear contracts**: Each agent reads specific inputs, produces specific outputs
4. **Simpler dependency graph**: Linear flow from specs to implementation

## Consequences

### Positive
- No file conflicts between agents
- Simpler orchestration logic
- Easier to reason about dependencies

### Negative
- `implementer` has larger scope (more work per agent)
- Less parallelism in implementation phase

## Future Consideration

If `implementer` becomes a bottleneck, consider:
- Iterative rounds with verifier feedback
- Breaking into sub-tasks within single agent context
