---
description: "Cancel active pagent pipeline"
allowed-tools: ["Bash"]
hide-from-slash-command-tool: "true"
---

# Pagent Cancel

Check if a pipeline is active and cancel it:

```!
if [[ ! -f .claude/pagent-pipeline.json ]]; then
  echo "FOUND=false"
else
  echo "FOUND=true"
  STAGE=$(jq -r '.stage' .claude/pagent-pipeline.json)
  echo "STAGE=$STAGE"

  # List outputs that exist
  OUTPUTS=()
  [[ -f architecture.md ]] && OUTPUTS+=("architecture.md")
  [[ -f test-plan.md ]] && OUTPUTS+=("test-plan.md")
  [[ -f security-assessment.md ]] && OUTPUTS+=("security-assessment.md")
  [[ -d src ]] && OUTPUTS+=("src/")
  [[ -f verification-report.md ]] && OUTPUTS+=("verification-report.md")

  if [[ ${#OUTPUTS[@]} -gt 0 ]]; then
    local IFS=", "
    echo "OUTPUTS=${OUTPUTS[*]}"
  fi
fi
```

## Handle the Result

**If FOUND=false:**
- Say "No active pagent pipeline found."
- Nothing to cancel.

**If FOUND=true:**
1. Use Bash to remove the pipeline state file:
   ```
   rm .claude/pagent-pipeline.json
   ```

2. Report cancellation:
   ```
   ⚠️  Cancelling pagent pipeline...
   Current stage: {STAGE}
   The current stage will finish its work, then the pipeline will stop.
   ```

3. If OUTPUTS were listed, show what will be preserved:
   ```
   Outputs created so far will be preserved:
   - {each output file}
   ```

4. Explain resume capability:
   ```
   To resume later, run: /pagent-run {PRD file}
   The pipeline will skip completed stages.
   ```
