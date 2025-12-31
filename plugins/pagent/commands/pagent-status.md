---
description: "Show current status of active pagent pipeline"
allowed-tools: ["Bash"]
hide-from-slash-command-tool: "true"
---

# Pagent Status

Check pipeline status:

```!
if [[ ! -f .claude/pagent-pipeline.json ]]; then
  echo "ACTIVE=false"
else
  echo "ACTIVE=true"
  STAGE=$(jq -r '.stage' .claude/pagent-pipeline.json)
  STARTED=$(jq -r '.started_at' .claude/pagent-pipeline.json)
  PRD=$(jq -r '.prd_file // "unknown"' .claude/pagent-pipeline.json)
  TOTAL=$(jq '.stages | length' .claude/pagent-pipeline.json)
  CURRENT_INDEX=$(jq -r ".stages | to_entries | map(select(.value.name == \"$STAGE\"))[0].key // 0" .claude/pagent-pipeline.json)

  if [[ "$STAGE" == "complete" ]]; then
    COMPLETED=$TOTAL
  else
    COMPLETED=$CURRENT_INDEX
  fi

  echo "STAGE=$STAGE"
  echo "STARTED=$STARTED"
  echo "PRD=$PRD"
  echo "COMPLETED=$COMPLETED"
  echo "TOTAL=$TOTAL"

  # List outputs
  [[ -f architecture.md ]] && echo "OUTPUT_architecture=$(wc -l < architecture.md)"
  [[ -f test-plan.md ]] && echo "OUTPUT_test_plan=$(wc -l < test-plan.md)"
  [[ -f security-assessment.md ]] && echo "OUTPUT_security=$(wc -l < security-assessment.md)"
  [[ -d src ]] && echo "OUTPUT_src=$(find src -type f | wc -l) files"
  [[ -f verification-report.md ]] && echo "OUTPUT_verification=$(wc -l < verification-report.md)"
fi
```

## Display the Status

**If ACTIVE=false:**
```
No active pagent pipeline.

Start one with: /pagent-run <prd-file>
```

**If ACTIVE=true:**
```
🤖 Pagent Pipeline Status

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
