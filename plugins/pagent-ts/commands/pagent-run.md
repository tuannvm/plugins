---
description: "Start pagent-ts pipeline to transform PRD into working software through 5 specialized AI agents (TypeScript version)"
argument-hint: "<prd-file> [--workflow prd-to-code] [--max-stages N]"
allowed-tools: ["Bash(npx tsx ${CLAUDE_PLUGIN_ROOT}/scripts/setup-pipeline.ts *)"]
hide-from-slash-command-tool: "true"
---

# Pagent-TS Run

Execute the setup script to initialize the pagent-ts pipeline:

```!
npx tsx "${CLAUDE_PLUGIN_ROOT}/scripts/setup-pipeline.ts" $ARGUMENTS
```

The script will:
1. Validate the PRD file
2. Create `.claude/pagent-pipeline.json` with pipeline state
3. Output the initial architect prompt

The stop hook automatically handles all subsequent stage transitions.

## Pipeline Stages

The pipeline progresses through 5 stages sequentially:

1. **architect** → Creates `architecture.md` (technical specs)
2. **qa** → Creates `test-plan.md` (test strategy)
3. **security** → Creates `security-assessment.md` (security review)
4. **implementer** → Creates `src/` (complete codebase)
5. **verifier** → Creates `verification-report.md` and outputs `<promise>DONE</promise>`

## Notes

- Files are created in the same directory as the PRD
- Use `/pagent-status` to check progress
- Use `/pagent-cancel` to stop the pipeline
