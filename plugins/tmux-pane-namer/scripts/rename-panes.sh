#!/usr/bin/env bash
# tmux-pane-namer: Rename tmux panes using Claude CLI (haiku).
# Skips panes owned by Claude Code. Caches state to avoid redundant LLM calls.
# Works from cron (minimal PATH) on both macOS and Linux.

set -euo pipefail

# -- PATH: ensure tmux and claude are findable from cron -----------------------
for p in "$HOME/.local/bin" /opt/homebrew/bin /usr/local/bin /run/current-system/sw/bin; do
  [[ -d "$p" ]] && PATH="$p:$PATH"
done
export PATH

# -- preflight: bail early if deps missing ------------------------------------
command -v tmux  >/dev/null 2>&1 || exit 0
command -v claude >/dev/null 2>&1 || exit 0
tmux list-sessions >/dev/null 2>&1 || exit 0

# -- lock: prevent overlapping runs -------------------------------------------
LOCKDIR="/tmp/tmux-rename-panes.lock"
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  if [[ -n "$(find "$LOCKDIR" -maxdepth 0 -mmin +2 2>/dev/null)" ]]; then
    rm -rf "$LOCKDIR" && mkdir "$LOCKDIR"
  else
    exit 0
  fi
fi
trap 'rm -rf "$LOCKDIR"' EXIT

# -- collect pane metadata ----------------------------------------------------
pane_data=""
pane_count=0

while IFS='|' read -r pane_id title cmd cwd pid; do
  [[ "$title" == *"Claude Code"* ]] && continue
  [[ "$cmd" =~ ^[0-9]+\.[0-9]+ ]] && continue

  procs=$(pgrep -P "$pid" 2>/dev/null | xargs -I{} ps -o comm= -p {} 2>/dev/null | grep -v "^$" | tr '\n' ',' | sed 's/,$//' || true)

  pane_data+="PANE=${pane_id} | cmd=${cmd} | cwd=${cwd} | procs=${procs:-$cmd}"$'\n'
  pane_count=$((pane_count + 1))
done < <(tmux list-panes -a -F '#{pane_id}|#{pane_title}|#{pane_current_command}|#{pane_current_path}|#{pane_pid}')

[[ $pane_count -eq 0 ]] && exit 0

# -- state cache: skip LLM call if panes haven't changed ----------------------
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-pane-namer"
mkdir -p "$CACHE_DIR"
HASH_FILE="$CACHE_DIR/state.hash"
LABEL_CACHE="$CACHE_DIR/labels.cache"

sha_cmd() { sha256sum 2>/dev/null || shasum -a 256 2>/dev/null; }
current_hash=$(printf '%s' "$pane_data" | sha_cmd | cut -d' ' -f1)
if [[ -f "$HASH_FILE" && -f "$LABEL_CACHE" ]]; then
  prev_hash=$(cat "$HASH_FILE")
  if [[ "$current_hash" == "$prev_hash" ]]; then
    while IFS='|' read -r pane_id label || [[ -n "$pane_id" ]]; do
      [[ -z "$pane_id" || -z "$label" ]] && continue
      [[ "$pane_id" != %* ]] && continue
      tmux select-pane -t "$pane_id" -T "$label" 2>/dev/null || true
    done < "$LABEL_CACHE"
    exit 0
  fi
fi

# -- ask Claude to name panes -------------------------------------------------
response=$(echo "$pane_data" | claude -p \
  --model haiku \
  "You are a tmux pane naming assistant. Given pane info, output EXACTLY one line per pane:
PANE_ID|short_label

Rules:
- Labels must be ≤30 chars, no pipes
- Use a relevant emoji prefix
- For idle shells, derive a name from the cwd path (last 1-2 meaningful segments)
- For running commands, name by what the command does
- Be concise and descriptive
- Output ONLY the lines, nothing else" 2>/dev/null) || exit 0

[[ -z "$response" ]] && exit 0

# -- apply labels and update cache --------------------------------------------
applied=0
while IFS='|' read -r pane_id label || [[ -n "$pane_id" ]]; do
  [[ -z "$pane_id" || -z "$label" ]] && continue
  [[ "$pane_id" != %* ]] && continue
  tmux select-pane -t "$pane_id" -T "$label" 2>/dev/null || true
  applied=$((applied + 1))
done <<< "$response"

if [[ $applied -gt 0 ]]; then
  echo "$current_hash" > "$HASH_FILE"
  echo "$response" > "$LABEL_CACHE"
fi
