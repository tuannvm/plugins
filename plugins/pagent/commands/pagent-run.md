---
description: "Start pagent pipeline to transform PRD into working software through 5 specialized AI agents"
argument-hint: "<prd-file> [--workflow prd-to-code] [--max-stages N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-pipeline.sh)"]
hide-from-slash-command-tool: "true"
---

# Pagent Run

Execute the setup script to initialize the pagent pipeline:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-pipeline.sh" $ARGUMENTS
```

After the setup script completes, read its output which will include:
1. The pipeline stage being started
2. The initial prompt for the first stage (architect)

**Execute the initial prompt** to begin the pipeline. The Stop hook will automatically handle all subsequent stage transitions.

## Pipeline Stages

The pipeline will progress through these stages autonomously:

1. **architect** → Creates `architecture.md` (technical specs, API design, data models)
2. **qa** → Creates `test-plan.md` (test strategy, test cases, acceptance criteria)
3. **security** → Creates `security-assessment.md` (threat model, security requirements)
4. **implementer** → Creates `src/` (complete working codebase)
5. **verifier** → Creates `verification-report.md` and tests, outputs `<promise>DONE</promise>`

## Notes

- The pipeline runs in the current working directory
- All outputs are created alongside the PRD file
- The user can walk away - the pipeline completes autonomously
- Use `/pagent-status` to check progress anytime
- Use `/pagent-cancel` to stop the pipeline
