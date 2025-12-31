# Tutorial

## 1. Write a PRD

```markdown
# My App

## Requirements
- User authentication
- CRUD operations for items
- API documentation

## Constraints
- Go or TypeScript
- PostgreSQL database
```

## 2. Run Pagent

```bash
/pagent-run my-prd.md
```

## 3. Walk Away

The Ralph loop handles everything:

```
┌─────────────────────────────────────────────────┐
│  Stage 1: Architect                              │
│  Prompt: "Create architecture.md..."            │
│  Loop until: architecture.md exists (50+ lines) │
│                                                  │
│  [Claude works] → Not done? → Loop again        │
│  [Claude works] → Done! → Next stage            │
└─────────────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────────────┐
│  Stage 2: QA                                     │
│  Prompt: "Create test-plan.md..."                │
│  Loop until: test-plan.md exists (30+ lines)     │
│                                                  │
│  [Claude works] → Done! → Next stage            │
└─────────────────────────────────────────────────┘
           ↓
... continues through all 5 stages ...
```

Each stage loops until its goal is met. Then advances automatically.

## Check Progress

```bash
/pagent-status
```

Shows current stage, iteration count, and outputs.

## Cancel If Needed

```bash
/pagent-cancel
```

Stops the pipeline. Outputs created so far are preserved.

---

**That's the whole tutorial.**

The Ralph loop makes it work like a human: iterate until done, then move on.

For technical details, see [architecture.md](architecture.md).
