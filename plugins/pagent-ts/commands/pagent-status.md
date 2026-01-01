---
description: "Show current status of active pagent-ts pipeline"
allowed-tools: ["Bash(npx tsx ${CLAUDE_PLUGIN_ROOT}/scripts/status.ts)"]
hide-from-slash-command-tool: "true"
---

# Pagent-TS Status

Check pipeline status:

```!
npx tsx "${CLAUDE_PLUGIN_ROOT}/scripts/status.ts"
```

## Display the Status

**If ACTIVE=false:**
```
No active pagent-ts pipeline.

Start one with: /pagent-run <prd-file>
```

**If ACTIVE=true:**
```
🤖 Pagent-TS Pipeline Status

Stage: {STAGE} ({COMPLETED}/{TOTAL} complete)
Started: {STARTED}
PRD: {PRD}

Outputs:
- architecture.md ({OUTPUT_architecture} lines)
- test-plan.md ({OUTPUT_test_plan} lines)
...
```

**If STAGE=complete:**
```
✅ Pipeline complete!

All {TOTAL} stages finished successfully.
```
