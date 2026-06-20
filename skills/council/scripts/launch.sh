#!/usr/bin/env bash
# launch.sh — launch the council "chief" as a forked copy of the main session.
#
# chief = `claude --resume <main-session> --fork-session` (model from config.json). The fork
# inherits the full main conversation, so chief composes the consultation query itself (the main
# agent passes nothing), then follows references/chief.md: compose query → run council.sh →
# judge → return a verdict. The main agent runs this in the background; chief's verdict is stdout.
#
# Usage: launch.sh    (no args; pass a session id as $1 only to override, e.g. for testing)

set -uo pipefail

SID=${1:-${CLAUDE_CODE_SESSION_ID:-}}
if [[ -z "$SID" ]]; then
  echo "launch.sh: no session id (CLAUDE_CODE_SESSION_ID unset and none passed as \$1)" >&2
  exit 2
fi

# Resolve paths from this script's own location (BASH_SOURCE), never hard-coded → portable.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
CHIEF_PROC="$SKILL_DIR/references/chief.md"
CONFIG="$SKILL_DIR/config.json"
COUNCIL_SH="$SKILL_DIR/scripts/council.sh"

# chief model from config.json (chief_model); fall back to Opus.
CHIEF_MODEL="Opus"
if [[ -r "$CONFIG" ]]; then
  if command -v jq >/dev/null 2>&1; then
    _m=$(jq -r '.chief_model // empty' "$CONFIG" 2>/dev/null)
  else
    _m=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('chief_model') or '')" "$CONFIG" 2>/dev/null)
  fi
  [[ -n "${_m:-}" ]] && CHIEF_MODEL="$_m"
fi

# Identity override: --system-prompt (full replace) makes the fork act as chief instead of a
# clone of the main agent, while keeping the inherited conversation as background context.
CHIEF_ROLE="You are 'chief', an isolated council-orchestration subagent. The conversation you can see is INHERITED BACKGROUND ONLY: you did not write it, you must NOT continue it, must NOT address the user, and must NOT resume the main agent's task. You act solely as chief — run the council consultation per the procedure file you are pointed to. Your final message must be ONLY the verdict document it specifies: a clear, actionable conclusion the main agent can act on directly — no wrapping text, no vague hedging."

# Task: point chief at the procedure file + the council.sh path; chief picks what to review from
# the inherited conversation and composes the query itself.
TASK="Act as chief. Read and strictly follow this procedure file:
$CHIEF_PROC

Run the council with THIS script (use this exact absolute path; quote it as it may contain spaces):
$COUNCIL_SH

From the inherited conversation, find what the main agent is about to commit to, about to declare done, or stuck on — the approach, interpretation, result, or recurring error that needs reviewing — and put THAT to the council, composing the full curated query yourself.

Run the consultation to completion per the procedure, and return a clear, actionable verdict the main agent can act on directly — not vague advice."

# chief is the trusted orchestrator → skip-permissions (it writes the query, runs council.sh,
# cleans temp; avoids -p permission stalls). --disable-slash-commands stops it recursively
# invoking /council. </dev/null: -p carries the prompt, so don't wait on stdin.
exec claude \
  --resume "$SID" --fork-session \
  --model "$CHIEF_MODEL" \
  --dangerously-skip-permissions \
  --disable-slash-commands \
  --system-prompt "$CHIEF_ROLE" \
  -p "$TASK" < /dev/null
