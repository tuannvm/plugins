---
description: "Show current status of active pagent pipeline"
allowed-tools: ["Bash"]
hide-from-slash-command-tool: "true"
---

# Pagent Status

Check if a pipeline is active and show its status:

```!
if [[ ! -f .claude/pagent-pipeline.json ]]; then
  echo "ACTIVE=false"
else
  echo "ACTIVE=true"
  STAGE=$(jq -r '.stage' .claude/pagent-pipeline.json)
  STARTED=$(jq -r '.started_at' .claude/pagent-pipeline.json)
  PRD_FILE=$(jq -r '.prd_file // "unknown"' .claude/pagent-pipeline.json)

  # Count total stages
  TOTAL=$(jq '.stages | length' .claude/pagent-pipeline.json)

  # Find current stage index
  CURRENT_INDEX=$(jq -r ".stages | to_entries | map(select(.value.name == \"$STAGE\"))[0].key // -1" .claude/pagent-pipeline.json)

  # Count completed stages (before current)
  if [[ "$CURRENT_INDEX" == "-1" ]] || [[ "$STAGE" == "complete" ]]; then
    COMPLETED=$TOTAL
  else
    COMPLETED=$CURRENT_INDEX
  fi

  echo "STAGE=$STAGE"
  echo "STARTED=$STARTED"
  echo "PRD=$PRD_FILE"
  echo "COMPLETED=$COMPLETED"
  echo "TOTAL=$TOTAL"
fi
```

## Display the Status

**If ACTIVE=false:**
- Say "No active pagent pipeline found."
- Suggest running `/pagent-run <prd-file>` to start one.

**If ACTIVE=true:**
Display formatted status:

```
🤖 Pagent Pipeline Status

Current Stage: {STAGE} ({COMPLETED}/{TOTAL} complete)
Started: {STARTED}
PRD: {PRD}

Outputs:
- List each output file that exists:
  - architecture.md (142 lines)
  - test-plan.md (87 lines)
  - etc.

```

For each stage before current, show its output file with line count if it exists.

## Time Estimation

If the pipeline is active (not complete), estimate time remaining based on typical durations:
- architect: ~5 min
- qa: ~3 min
- security: ~3 min
- implementer: ~10 min
- verifier: ~5 min

## If Complete

If STAGE=complete, show "✅ Pipeline complete!" and list all final outputs.
