#!/bin/bash
# Pagent Ralph Loop Orchestrator
#
# A single Ralph-style loop that orchestrates all pipeline stages.
# Each stage loops until its exit condition is met, then advances.
# Only when ALL stages complete does it output DONE.
#
# This mimics human-like software development: iterate until done.

set -euo pipefail

# ============================================================
# Helper Functions
# ============================================================

check_exit_condition() {
    local CONDITION="$1"
    local WORK_DIR="$2"
    local TRANSCRIPT_PATH="$3"

    local TYPE
    TYPE=$(echo "$CONDITION" | jq -r 'keys[0] // empty')

    case "$TYPE" in
        file_exists)
            local FILE
            local MIN_LINES
            FILE=$(echo "$CONDITION" | jq -r '.file_exists')
            MIN_LINES=$(echo "$CONDITION" | jq -r '.min_lines // 0')
            local FILE_PATH="$WORK_DIR/$FILE"

            [[ -f "$FILE_PATH" ]] || return 1

            if [[ "$MIN_LINES" -gt 0 ]]; then
                local LINES
                LINES=$(wc -l < "$FILE_PATH" 2>/dev/null || echo "0")
                [[ "$LINES" -ge "$MIN_LINES" ]] || return 1
            fi
            return 0
            ;;

        directory_exists)
            local DIR
            local MIN_FILES
            DIR=$(echo "$CONDITION" | jq -r '.directory_exists')
            MIN_FILES=$(echo "$CONDITION" | jq -r '.min_files // 0')
            local DIR_PATH="$WORK_DIR/$DIR"

            [[ -d "$DIR_PATH" ]] || return 1

            if [[ "$MIN_FILES" -gt 0 ]]; then
                local FILE_COUNT
                FILE_COUNT=$(find "$DIR_PATH" -type f 2>/dev/null | wc -l || echo "0")
                [[ "$FILE_COUNT" -ge "$MIN_FILES" ]] || return 1
            fi
            return 0
            ;;

        promise_in_output)
            local PROMISE
            PROMISE=$(echo "$CONDITION" | jq -r '.promise_in_output')
            if [[ -f "$TRANSCRIPT_PATH" ]] && grep -qF "<promise>$PROMISE</promise>" "$TRANSCRIPT_PATH" 2>/dev/null; then
                return 0
            fi
            return 1
            ;;

        *)
            return 0
            ;;
    esac
}

get_stage_progress() {
    local WORK_DIR="$1"
    local outputs=()
    [[ -f "$WORK_DIR/architecture.md" ]] && outputs+="architecture.md ✓"
    [[ -f "$WORK_DIR/test-plan.md" ]] && outputs+="test-plan.md ✓"
    [[ -f "$WORK_DIR/security-assessment.md" ]] && outputs+="security-assessment.md ✓"
    [[ -d "$WORK_DIR/src" ]] && outputs+="src/ ✓"
    [[ -f "$WORK_DIR/verification-report.md" ]] && outputs+="verification-report.md ✓"

    if [[ ${#outputs[@]} -eq 0 ]]; then
        echo "(no outputs yet)"
    else
        local IFS=", "
        echo "${outputs[*]}"
    fi
}

# ============================================================
# Main Logic
# ============================================================

# Read hook input
HOOK_INPUT=$(cat)

# Get paths
WORK_DIR="${CLAUDE_PROJECT_DIR:-${PWD}}"
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty')
PIPELINE_STATE="${WORK_DIR}/.claude/pagent-pipeline.json"

# Check if pipeline exists
if [[ ! -f "$PIPELINE_STATE" ]]; then
    # No pipeline - allow exit
    exit 0
fi

# Validate JSON
if ! jq empty "$PIPELINE_STATE" 2>/dev/null; then
    echo "⚠️  Pagent: Corrupted state. Run /pagent-run to reinitialize." >&2
    exit 1
fi

# Read pipeline state
STAGE=$(jq -r '.stage // empty' "$PIPELINE_STATE")
STAGES=$(jq '.stages // []' "$PIPELINE_STATE")
MAX_STAGES=$(jq -r '.max_stages // 0' "$PIPELINE_STATE")
PRD_PATH=$(jq -r '.prd_path // ""' "$PIPELINE_STATE")

if [[ -z "$STAGE" ]]; then
    exit 0
fi

# Check max stages
if [[ "$MAX_STAGES" -gt 0 ]]; then
    CURRENT_INDEX=$(echo "$STAGES" | jq -r "to_entries | map(select(.value.name == \"$STAGE\"))[0].key // -1")
    if [[ "$CURRENT_INDEX" -ge "$MAX_STAGES" ]]; then
        echo "🛑 Pagent: Max stages ($MAX_STAGES) reached." >&2
        jq ".stage = \"stopped_at_max\"" "$PIPELINE_STATE" > "${PIPELINE_STATE}.tmp"
        mv "${PIPELINE_STATE}.tmp" "$PIPELINE_STATE"
        exit 0
    fi
fi

# Find current stage index
STAGE_INDEX=$(echo "$STAGES" | jq -r "to_entries | map(select(.value.name == \"$STAGE\"))[0].key // empty")

if [[ -z "$STAGE_INDEX" ]] || [[ "$STAGE_INDEX" == "null" ]]; then
    exit 0
fi

# Get current stage config
STAGE_CONFIG=$(echo "$STAGES" | jq ".[$STAGE_INDEX]")
STAGE_NAME=$(echo "$STAGE_CONFIG" | jq -r '.name')
EXIT_CONDITION=$(echo "$STAGE_CONFIG" | jq -r '.exit_when // {}')
PROMPT_FILE=$(echo "$STAGE_CONFIG" | jq -r '.prompt_file // empty')

# Increment iteration count for this stage
ITERATIONS=$(jq ".iterations[\"$STAGE_NAME\"] // 0" "$PIPELINE_STATE")
ITERATIONS=$((ITERATIONS + 1))
jq ".iterations[\"$STAGE_NAME\"] = $ITERATIONS" "$PIPELINE_STATE" > "${PIPELINE_STATE}.tmp"
mv "${PIPELINE_STATE}.tmp" "$PIPELINE_STATE"

# Check if stage is complete
if check_exit_condition "$EXIT_CONDITION" "$WORK_DIR" "$TRANSCRIPT_PATH"; then
    # Stage complete - try to advance
    NEXT_INDEX=$((STAGE_INDEX + 1))
    NEXT_STAGE=$(echo "$STAGES" | jq -r ".[$NEXT_INDEX] // empty")

    if [[ "$NEXT_STAGE" == "null" ]] || [[ -z "$NEXT_STAGE" ]]; then
        # All stages complete!
        jq ".stage = \"complete\" | .completed_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$PIPELINE_STATE" > "${PIPELINE_STATE}.tmp"
        mv "${PIPELINE_STATE}.tmp" "$PIPELINE_STATE"

        echo "" >&2
        echo "✅ Pagent: All stages complete!" >&2
        echo "   $(echo "$STAGES" | jq 'length') stages finished successfully." >&2
        echo "" >&2

        # Output final completion promise
        jq -n '{"decision": "block", "reason": "Pipeline complete! All 5 stages finished successfully."}'
        exit 0
    fi

    # Advance to next stage
    NEXT_STAGE_NAME=$(echo "$NEXT_STAGE" | jq -r '.name')
    NEXT_PROMPT_FILE=$(echo "$NEXT_STAGE" | jq -r '.prompt_file // empty')
    NEXT_PROMPT=$(sed "s|PRD_PATH|$PRD_PATH|g" "$WORK_DIR/$NEXT_PROMPT_FILE" 2>/dev/null || echo "Prompt not found")

    echo "🔄 Pagent: '$STAGE_NAME' → '$NEXT_STAGE_NAME' (after $ITERATIONS iteration(s))" >&2

    # Update state
    jq ".stage = \"$NEXT_STAGE_NAME\"" "$PIPELINE_STATE" > "${PIPELINE_STATE}.tmp"
    mv "${PIPELINE_STATE}.tmp" "$PIPELINE_STATE"

    # Inject next stage prompt
    SYSTEM_MSG="🔄 Pagent Stage: $NEXT_STAGE_NAME
Previous stage '$STAGE_NAME' completed after $ITERATIONS iteration(s).
Working with: $(get_stage_progress "$WORK_DIR")"

    jq -n \
        --arg prompt "$NEXT_PROMPT" \
        --arg msg "$SYSTEM_MSG" \
        '{"decision": "block", "reason": $prompt, "systemMessage": $msg}'
    exit 0
fi

# Stage NOT complete - loop on same stage
# Read the current prompt again
CURRENT_PROMPT=$(sed "s|PRD_PATH|$PRD_PATH|g" "$WORK_DIR/$PROMPT_FILE" 2>/dev/null || echo "Prompt not found")

# Build retry message with iteration context
SYSTEM_MSG="🔄 Pagent Stage: $STAGE_NAME (iteration $ITERATIONS)
Stage not complete yet. Continue working.
Progress: $(get_stage_progress "$WORK_DIR")
Tip: Focus on completing the exit condition: $(echo "$EXIT_CONDITION" | jq -c '.')"

# Block exit and inject the same prompt (Ralph-style loop)
jq -n \
    --arg prompt "$CURRENT_PROMPT" \
    --arg msg "$SYSTEM_MSG" \
    '{"decision": "block", "reason": $prompt, "systemMessage": $msg}'

exit 0
