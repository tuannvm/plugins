#!/bin/bash
# Pagent Pipeline Setup Script
#
# This script is invoked by the /pagent-run command to:
# 1. Read and parse the PRD file
# 2. Generate the pipeline state file
# 3. Initialize the workflow
#
# Usage: setup-pipeline.sh <prd-file> [workflow-type] [max-stages]

set -euo pipefail

PRD_FILE="${1:-}"
WORKFLOW_TYPE="${2:-prd-to-code}"
MAX_STAGES="${3:-0}"

# ============================================================
# Helper Functions (must be defined before main logic)
# ============================================================

get_initial_prompt() {
    case "$WORKFLOW_TYPE" in
        prd-to-code)
            cat <<'EOF'
You are the Software Architect. Read the PRD and create architecture.md with:
- System overview and components
- Technology stack with rationale
- API design (endpoints, methods, schemas)
- Data models and database schema
- Architecture decisions with rationale
- Security considerations
- Deployment architecture

Be thorough and specific. Target 100+ lines.
EOF
            ;;
    esac
}

generate_prd_to_code_pipeline() {
    cat > .claude/pagent-pipeline.json <<EOF
{
  "stage": "architect",
  "max_stages": $MAX_STAGES,
  "workflow_type": "prd-to-code",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "prd_file": "$PRD_FILE",
  "stages": [
    {
      "name": "architect",
      "prompt": "You are the Software Architect.

Read the PRD at $(pwd)/$PRD_FILE and create a comprehensive technical architecture in architecture.md.

Your architecture.md should include:
1. **System Overview**: High-level system design and components
2. **Technology Stack**: Recommended languages, frameworks, and libraries (justify choices)
3. **API Design**: All endpoints with methods, paths, request/response schemas
4. **Data Models**: Database schema, data structures, relationships
5. **Architecture Decisions (ADRs)**: Key technical decisions with rationale
6. **Security Considerations**: Authentication, authorization, data protection
7. **Deployment Architecture**: How the system will be deployed and scaled

Be thorough and specific. Use markdown formatting with clear sections.
Target 100+ lines of detailed technical specification.",
      "exit_when": {
        "file_exists": "architecture.md",
        "min_lines": 50
      }
    },
    {
      "name": "qa",
      "prompt": "You are the QA Engineer.

Read architecture.md and create a comprehensive test plan in test-plan.md.

Your test-plan.md should include:
1. **Test Strategy**: Overall approach (unit, integration, e2e, performance)
2. **Test Coverage Plan**: What will be tested, coverage targets
3. **Test Cases**: Specific test scenarios with:
   - Preconditions
   - Test steps
   - Expected results
   - Priority (P0/P1/P2)
4. **Acceptance Criteria**: Definition of done for each feature
5. **Testing Tools**: Recommended frameworks and tools
6. **Test Data Strategy**: How test data will be managed

Focus on practical, actionable test cases that validate the architecture.
Target 80+ lines.",
      "exit_when": {
        "file_exists": "test-plan.md",
        "min_lines": 30
      }
    },
    {
      "name": "security",
      "prompt": "You are the Security Analyst.

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
Target 60+ lines.",
      "exit_when": {
        "file_exists": "security-assessment.md",
        "min_lines": 20
      }
    },
    {
      "name": "implementer",
      "prompt": "You are the Software Implementer.

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

The code should be:
- Production-ready (not just placeholders)
- Fully functional (all features from PRD work)
- Well-organized (proper directory structure)
- Error-handled (graceful failures, not crashes)

Create at least 3 source files in src/ directory.",
      "exit_when": {
        "directory_exists": "src",
        "min_files": 3
      }
    },
    {
      "name": "verifier",
      "prompt": "You are the Verification Engineer.

Review all work:
- PRD requirements
- architecture.md
- test-plan.md
- security-assessment.md
- src/ code

Your tasks:
1. **Verify completeness**: Check all PRD requirements are addressed
2. **Add tests**: Create comprehensive tests (src/*_test.go or tests/)
3. **Verify implementation**: Code matches architecture specifications
4. **Security check**: Confirm security controls are implemented
5. **Create verification-report.md** documenting:
   - What was verified
   - Test results
   - Issues found (if any)
   - Recommendations

After completing verification and all tests pass, output:
<promise>DONE</promise>

This signals the pipeline is complete.",
      "exit_when": {
        "promise_in_output": "DONE"
      }
    }
  ]
}
EOF
}


# ============================================================
# Main Logic
# ============================================================

# Validate PRD file exists
if [[ -z "$PRD_FILE" ]]; then
    echo "❌ Error: No PRD file specified" >&2
    echo "" >&2
    echo "   Usage: /pagent-run <prd-file>" >&2
    echo "" >&2
    echo "   Example: /pagent-run prd.md" >&2
    exit 1
fi

if [[ ! -f "$PRD_FILE" ]]; then
    echo "❌ Error: PRD file not found: $PRD_FILE" >&2
    exit 1
fi

# Read PRD content
PRD_CONTENT=$(cat "$PRD_FILE")

# Validate PRD has content
if [[ $(echo "$PRD_CONTENT" | wc -l) -lt 10 ]]; then
    echo "⚠️  Warning: PRD file seems too short ($(echo "$PRD_CONTENT" | wc -l) lines)" >&2
    echo "   A good PRD should have at least: problem statement, requirements, constraints" >&2
fi

# Check for existing pipeline
if [[ -f .claude/pagent-pipeline.json ]]; then
    CURRENT_STAGE=$(jq -r '.stage // empty' .claude/pagent-pipeline.json 2>/dev/null || echo "")
    if [[ -n "$CURRENT_STAGE" ]] && [[ "$CURRENT_STAGE" != "complete" ]]; then
        echo "⚠️  Active pipeline found at stage: $CURRENT_STAGE" >&2
        echo "" >&2
        echo "   Use /pagent-cancel first to stop it," >&2
        echo "   or confirm you want to restart (will overwrite state)." >&2
        echo "" >&2
        read -p "Restart anyway? [y/N] " -n 1 -r
        echo "" >&2
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled." >&2
            exit 1
        fi
    fi
fi

# Create .claude directory
mkdir -p .claude

# Generate pipeline state based on workflow type
case "$WORKFLOW_TYPE" in
    prd-to-code)
        generate_prd_to_code_pipeline
        ;;
    *)
        echo "❌ Error: Unknown workflow type: $WORKFLOW_TYPE" >&2
        echo "   Supported workflows: prd-to-code" >&2
        exit 1
        ;;
esac

# Output summary
cat <<EOF

🤖 Pagent pipeline activated!

PRD: $PRD_FILE
Workflow: $WORKFLOW_TYPE
Max Stages: $(if [[ "$MAX_STAGES" -gt 0 ]]; then echo "$MAX_STAGES"; else echo "unlimited"; fi)

The Stop hook is now active. When you complete each stage, the hook will
automatically transition to the next stage by injecting the next prompt.

To monitor progress: /pagent-status
To cancel: /pagent-cancel

🔄
EOF

# Output the initial architect prompt
echo ""
echo "--- Initial Prompt ---"
get_initial_prompt
