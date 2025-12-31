#!/bin/bash
# Pagent Pipeline Setup Script
#
# Initializes the Ralph loop that orchestrates the entire pipeline.
#
# Usage: setup-pipeline.sh <prd-file> [--workflow prd-to-code] [--max-stages N]

set -euo pipefail

# Default values
PRD_FILE=""
WORKFLOW_TYPE="prd-to-code"
MAX_STAGES=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --workflow)
            WORKFLOW_TYPE="$2"
            shift 2
            ;;
        --max-stages)
            MAX_STAGES="$2"
            shift 2
            ;;
        -*)
            echo "❌ Error: Unknown option: $1" >&2
            echo "   Usage: /pagent-run <prd-file> [--workflow prd-to-code] [--max-stages N]" >&2
            exit 1
            ;;
        *)
            PRD_FILE="$1"
            if [[ "$PRD_FILE" == @* ]]; then
                PRD_FILE="${PRD_FILE#@}"
            fi
            shift
            ;;
    esac
done

# ============================================================
# Validation
# ============================================================

if [[ -z "$PRD_FILE" ]]; then
    echo "❌ Error: No PRD file specified" >&2
    echo "   Usage: /pagent-run <prd-file>" >&2
    exit 1
fi

if [[ ! -f "$PRD_FILE" ]]; then
    echo "❌ Error: PRD file not found: $PRD_FILE" >&2
    exit 1
fi

# Check for existing pipeline
if [[ -f .claude/pagent-pipeline.json ]]; then
    CURRENT_STAGE=$(jq -r '.stage // empty' .claude/pagent-pipeline.json 2>/dev/null || echo "")
    if [[ -n "$CURRENT_STAGE" ]] && [[ "$CURRENT_STAGE" != "complete" ]]; then
        echo "⚠️  Active pipeline found at stage: $CURRENT_STAGE" >&2
        echo "   Use /pagent-cancel first to stop it, then run again." >&2
        exit 1
    fi
fi

# ============================================================
# Initialize Pipeline State
# ============================================================

mkdir -p .claude/prompts

# Create prompt templates
cat > .claude/prompts/architect.txt <<'ARCHITEOF'
You are the Software Architect.

Read the PRD at PRD_PATH and create a comprehensive technical architecture in architecture.md.

Your architecture.md should include:
1. **System Overview**: High-level system design and components
2. **Technology Stack**: Recommended languages, frameworks, and libraries (justify choices)
3. **API Design**: All endpoints with methods, paths, request/response schemas
4. **Data Models**: Database schema, data structures, relationships
5. **Architecture Decisions (ADRs)**: Key technical decisions with rationale
6. **Security Considerations**: Authentication, authorization, data protection
7. **Deployment Architecture**: How the system will be deployed and scaled

Be thorough and specific. Use markdown formatting with clear sections.
Target 100+ lines of detailed technical specification.
ARCHITEOF

cat > .claude/prompts/qa.txt <<'QAOF'
You are the QA Engineer.

Read architecture.md and create a comprehensive test plan in test-plan.md.

Your test-plan.md should include:
1. **Test Strategy**: Overall approach (unit, integration, e2e, performance)
2. **Test Coverage Plan**: What will be tested, coverage targets
3. **Test Cases**: Specific test scenarios with preconditions, steps, expected results, priority
4. **Acceptance Criteria**: Definition of done for each feature
5. **Testing Tools**: Recommended frameworks and tools
6. **Test Data Strategy**: How test data will be managed

Focus on practical, actionable test cases that validate the architecture.
Target 80+ lines.
QAOF

cat > .claude/prompts/security.txt <<'SECOF'
You are the Security Analyst.

Read architecture.md and create a security assessment in security-assessment.md.

Your security-assessment.md should include:
1. **Threat Model**: Potential attack vectors and threats
2. **Security Requirements**: Authentication, authorization, encryption, audit logging
3. **Vulnerability Analysis**: OWASP Top 10, common vulnerabilities to address
4. **Security Controls**: Mitigation strategies for identified threats
5. **Compliance**: GDPR, SOC2, PCI-DSS considerations (if applicable)
6. **Security Testing Plan**: How security will be validated
7. **Secure Development Practices**: Guidelines for secure coding

Be specific about security measures. Don't just say 'use encryption' - specify what, where, and how.
Target 60+ lines.
SECOF

cat > .claude/prompts/implementer.txt <<'IMPOF'
You are the Software Implementer.

Read the PRD, architecture.md, test-plan.md, and security-assessment.md.
Implement the complete, working codebase in a src/ directory.

Requirements:
1. **Follow the architecture**: Implement what was specified in architecture.md
2. **Write clean code**: Follow language best practices, proper error handling
3. **Include comments**: Document non-obvious code, complex logic
4. **Security first**: Implement the security controls from security-assessment.md
5. **API implementation**: All endpoints from architecture.md must work
6. **Data models**: Implement the database schema and data structures
7. **Entry point**: Include main.go or equivalent entry point
8. **README**: Create README.md with setup/run instructions
9. **Dependencies**: Include go.mod, package.json, requirements.txt, etc.

The code should be production-ready, fully functional, well-organized, and error-handled.
Create at least 3 source files in src/ directory.
IMPOF

cat > .claude/prompts/verifier.txt <<'VEROF'
You are the Verification Engineer.

Review all work: PRD requirements, architecture.md, test-plan.md, security-assessment.md, src/ code.

Your tasks:
1. **Verify completeness**: Check all PRD requirements are addressed
2. **Add tests**: Create comprehensive tests (src/*_test.go or tests/)
3. **Verify implementation**: Code matches architecture specifications
4. **Security check**: Confirm security controls are implemented
5. **Create verification-report.md** documenting what was verified, test results, issues found, recommendations

After completing verification and all tests pass, output:
<promise>DONE</promise>

This signals the pipeline is complete.
VEROF

# Generate pipeline state
FULL_PRD_PATH="$(pwd)/$PRD_FILE"
cat > .claude/pagent-pipeline.json <<EOF
{
  "stage": "architect",
  "max_stages": $MAX_STAGES,
  "workflow_type": "$WORKFLOW_TYPE",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "prd_file": "$PRD_FILE",
  "prd_path": "$FULL_PRD_PATH",
  "iterations": {},
  "stages": [
    {
      "name": "architect",
      "prompt_file": ".claude/prompts/architect.txt",
      "exit_when": {"file_exists": "architecture.md", "min_lines": 50}
    },
    {
      "name": "qa",
      "prompt_file": ".claude/prompts/qa.txt",
      "exit_when": {"file_exists": "test-plan.md", "min_lines": 30}
    },
    {
      "name": "security",
      "prompt_file": ".claude/prompts/security.txt",
      "exit_when": {"file_exists": "security-assessment.md", "min_lines": 20}
    },
    {
      "name": "implementer",
      "prompt_file": ".claude/prompts/implementer.txt",
      "exit_when": {"directory_exists": "src", "min_files": 3}
    },
    {
      "name": "verifier",
      "prompt_file": ".claude/prompts/verifier.txt",
      "exit_when": {"promise_in_output": "DONE"}
    }
  ]
}
EOF

# Output summary
cat <<'EOF'

🤖 Pagent pipeline initialized!

The Ralph loop orchestrator is now active.
It will automatically progress through 5 stages:
  1. architect → 2. qa → 3. security → 4. implementer → 5. verifier

Use /pagent-status to check progress.
Use /pagent-cancel to stop.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Starting Stage 1: Architect
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Output the first prompt (substituting PRD_PATH)
sed "s|PRD_PATH|$FULL_PRD_PATH|g" .claude/prompts/architect.txt
