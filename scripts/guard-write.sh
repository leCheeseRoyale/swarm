#!/bin/bash
# State machine write guard — blocks code writes when no task is in CODING state.
# Called by PreToolUse hook on Write|Edit.
set -euo pipefail

# Require jq
if ! command -v jq &>/dev/null; then
  # Cannot enforce without jq — allow and warn
  echo "swarm: jq not found, skipping write guard" >&2
  exit 0
fi

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.file // ""')

# Always allow writes to .swarm/ (state management)
case "$file_path" in
  *.swarm/*|*.swarm\\*|*/.swarm/*) exit 0 ;;
esac

# If no state file exists, swarm is not active — allow everything
state_file="${CLAUDE_PROJECT_DIR:-.}/.swarm/state.json"
if [ ! -f "$state_file" ]; then
  exit 0
fi

# Check machine state
machine_state=$(jq -r '.state' "$state_file" 2>/dev/null || echo "IDLE")

# If swarm is not RUNNING, allow (no enforcement outside active swarm)
if [ "$machine_state" != "RUNNING" ]; then
  exit 0
fi

# During RUNNING: code writes only permitted when at least one task is CODING
coding_count=$(jq '[.tasks[] | select(.status == "CODING")] | length' "$state_file" 2>/dev/null || echo "0")

if [ "$coding_count" -eq 0 ]; then
  echo "BLOCKED: State machine violation — no task is in CODING state. Code writes are only permitted during the CODING phase." >&2
  exit 2
fi

exit 0
