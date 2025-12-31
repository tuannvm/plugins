---
description: "Cancel active pagent pipeline"
allowed-tools: ["Bash"]
hide-from-slash-command-tool: "true"
---

# Pagent Cancel

Cancel the active pipeline:

```!
if [ -f .claude/pagent-pipeline.json ]; then
  echo "FOUND=true"
  STAGE=$(jq -r '.stage' .claude/pagent-pipeline.json)
  echo "STAGE=$STAGE"
else
  echo "FOUND=false"
fi
```

## Handle the Result

**If FOUND=false:**
```
No active pagent pipeline to cancel.
```

**If FOUND=true:**
1. Remove the pipeline state:
   ```
   rm .claude/pagent-pipeline.json
   rm -rf .claude/prompts
   ```

2. Report cancellation:
   ```
   ⚠️  Cancelling pagent pipeline at stage: {STAGE}

   The pipeline will stop. Outputs created so far are preserved.
   ```

3. Show what was created:
   ```
   Preserved outputs:
   - architecture.md (or not created yet)
   - test-plan.md (or not created yet)
   - ...
   ```

4. Offer restart:
   ```
   To resume, run: /pagent-run <prd-file>
   ```
