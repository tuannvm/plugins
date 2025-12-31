#!/bin/bash
# Pagent Pipeline Orchestrator Stop Hook
#
# This hook runs when Claude tries to exit. It orchestrates multi-stage
# pipelines by checking if the current stage is complete, and if so,
# advancing to the next stage by injecting a new prompt.
#
# Based on the Ralph Wiggum technique, but adapted for multi-stage pipelines
# where each stage has a different prompt (not same-prompt iteration).

set -euo pipefail

# Trap to clean up temporary files on exit
trap 'rm -f "${PIPELINE_STATE}.tmp" 2>/dev/null' EXIT

# ============================================================
# Helper Functions (must be defined before main logic)
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

        all_files_exist)
            local FILES
            FILES=$(echo "$CONDITION" | jq -r '.all_files_exist[]')
            local ALL_EXIST=true
            # Use while-read for proper handling of filenames with spaces
            while IFS= read -r FILE; do
                [[ -n "$FILE" ]] || continue
                if [[ ! -f "$WORK_DIR/$FILE" ]]; then
                    ALL_EXIST=false
                    break
                fi
            done <<< "$FILES"
            [[ "$ALL_EXIST" == "true" ]]
            return $?
            ;;

        custom)
            local SCRIPT
            SCRIPT=$(echo "$CONDITION" | jq -r '.custom')
            local SCRIPT_PATH="$WORK_DIR/$SCRIPT"

            # Security: validate script path is within workspace
            case "$SCRIPT_PATH" in
                "$WORK_DIR"/*) ;;  # OK - within workspace
                *) echo "⚠️  Pagent: Script path outside workspace, blocked" >&2; return 1 ;;
            esac

            if [[ -f "$SCRIPT_PATH" ]]; then
                bash "$SCRIPT_PATH" "$WORK_DIR"
                return $?
            fi
            return 1
            ;;

        *)
            # Unknown condition type - allow exit (fail open)
            echo "⚠️  Pagent: Unknown exit condition type: $TYPE" >&2
            return 0
            ;;
    esac
}

list_outputs() {
    local WORK_DIR="$1"
    # List key output files that might exist
    local outputs=()
    [[ -f "$WORK_DIR/architecture.md" ]] && outputs+=("architecture.md")
    [[ -f "$WORK_DIR/test-plan.md" ]] && outputs+=("test-plan.md")
    [[ -f "$WORK_DIR/security-assessment.md" ]] && outputs+=("security-assessment.md")
    [[ -d "$WORK_DIR/src" ]] && outputs+=("src/")
    [[ -f "$WORK_DIR/verification-report.md" ]] && outputs+=("verification-report.md")

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

# Read hook input from stdin (advanced stop hook API)
HOOK_INPUT=$(cat)

# Get working directory - use CLAUDE_PROJECT_DIR if set, else PWD
# Don't derive from transcript path (unreliable)
WORK_DIR="${CLAUDE_PROJECT_DIR:-${PWD}}"

# Get transcript path for promise checking
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty')

# Pipeline state file in the working directory
PIPELINE_STATE="${WORK_DIR}/.claude/pagent-pipeline.json"

# Check if pagent pipeline is active
if [[ ! -f "$PIPELINE_STATE" ]]; then
    # No active pipeline - allow exit
    exit 0
fi

# Validate JSON is well-formed
if ! jq empty "$PIPELINE_STATE" 2>/dev/null; then
    echo "⚠️  Pagent: Corrupted pipeline state file" >&2
    echo "   Run /pagent-run to reinitialize" >&2
    exit 1
fi

# Read current state
STAGE=$(jq -r '.stage // empty' "$PIPELINE_STATE")
STAGES=$(jq '.stages // []' "$PIPELINE_STATE")
MAX_STAGES=$(jq -r '.max_stages // 0' "$PIPELINE_STATE")

# Validate stage exists
if [[ -z "$STAGE" ]]; then
    echo "⚠️  Pagent: No stage found in pipeline state" >&2
    exit 0
fi

# Check if max stages limit reached
if [[ "$MAX_STAGES" -gt 0 ]]; then
    CURRENT_INDEX_CHECK=$(echo "$STAGES" | jq -r "to_entries | map(select(.value.name == \"$STAGE\"))[0].key // -1" "$PIPELINE_STATE")
    if [[ "$CURRENT_INDEX_CHECK" -ge "$MAX_STAGES" ]]; then
        echo "🛑 Pagent: Max stages ($MAX_STAGES) reached." >&2
        jq ".stage = \"stopped_at_max\"" "$PIPELINE_STATE" > "${PIPELINE_STATE}.tmp"
        mv "${PIPELINE_STATE}.tmp" "$PIPELINE_STATE"
        exit 0
    fi
fi

# Find current stage index
STAGE_INDEX=$(echo "$STAGES" | jq -r "to_entries | map(select(.value.name == \"$STAGE\"))[0].key // empty")

if [[ -z "$STAGE_INDEX" ]] || [[ "$STAGE_INDEX" == "null" ]]; then
    echo "⚠️  Pagent: Stage '$STAGE' not found in pipeline definition" >&2
    exit 0
fi

# Get current stage config
STAGE_CONFIG=$(echo "$STAGES" | jq ".[$STAGE_INDEX]")
STAGE_NAME=$(echo "$STAGE_CONFIG" | jq -r '.name')
EXIT_CONDITION=$(echo "$STAGE_CONFIG" | jq -r '.exit_when // {}')

# Check exit condition
if check_exit_condition "$EXIT_CONDITION" "$WORK_DIR" "$TRANSCRIPT_PATH"; then
    # Stage complete - advance to next stage
    NEXT_INDEX=$((STAGE_INDEX + 1))
    NEXT_STAGE=$(echo "$STAGES" | jq -r ".[$NEXT_INDEX] // empty")

    if [[ "$NEXT_STAGE" == "null" ]] || [[ -z "$NEXT_STAGE" ]]; then
        # Pipeline complete!
        NEXT_STAGE_NAME=$(echo "$STAGE_CONFIG" | jq -r '.name')
        jq ".stage = \"complete\" | .completed_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$PIPELINE_STATE" > "${PIPELINE_STATE}.tmp"
        mv "${PIPELINE_STATE}.tmp" "$PIPELINE_STATE"

        echo "✅ Pagent: Pipeline complete!" >&2
        echo "   All $(echo "$STAGES" | jq 'length') stages finished successfully." >&2
        exit 0
    fi

    # Advance to next stage
    NEXT_STAGE_NAME=$(echo "$NEXT_STAGE" | jq -r '.name')
    NEXT_PROMPT=$(echo "$NEXT_STAGE" | jq -r '.prompt // empty')

    echo "🔄 Pagent: Stage '$STAGE_NAME' complete, advancing to '$NEXT_STAGE_NAME'" >&2

    # Update state atomically
    jq ".stage = \"$NEXT_STAGE_NAME\"" "$PIPELINE_STATE" > "${PIPELINE_STATE}.tmp"
    mv "${PIPELINE_STATE}.tmp" "$PIPELINE_STATE"

    # Build system message
    SYSTEM_MSG="🔄 Pagent Stage: $NEXT_STAGE_NAME
Previous stage '$STAGE_NAME' completed successfully.
Working with outputs from: $(list_outputs "$WORK_DIR")"

    # Inject next prompt by blocking exit
    jq -n \
        --arg prompt "$NEXT_PROMPT" \
        --arg msg "$SYSTEM_MSG" \
        '{
            "decision": "block",
            "reason": $prompt,
            "systemMessage": $msg
        }'
    exit 0
fi

# Stage not complete - let agent continue working
exit 0
