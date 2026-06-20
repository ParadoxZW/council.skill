#!/usr/bin/env bash
# council.sh — run ONE round of the council in the foreground.
#
# Fans a curated query out to all councilors in parallel (read-only CLI agents on different model
# backends), waits, and prints a RESULT manifest. No internal timeout: the caller bounds the wait
# via the Bash tool's own timeout — finishes in time → returns normally; exceeds it → the call
# auto-backgrounds and the caller reaps leftover councilors by the PIDs printed below.
#
# Usage:  council.sh <query_file> [out_dir]      (query fed to each councilor via stdin)
# Stdout: OUT=<tmp> / COUNCIL=<.council dir> / LAUNCHED <name> <pid> ... / RESULT <name> <status> <outfile>
#   status ∈ ok|empty|failed. Each opinion → ./.council/<codename>-<ts>.md (kept). Exit 0 if ≥1 ok.

set -uo pipefail

# Best-effort TTL sweep of stale temp files (never fatal).
_TMPROOT="${TMPDIR:-/tmp}"
find "$_TMPROOT" -maxdepth 1 -type f \( -name 'council-*.jsonl' -o -name 'council-*.txt' -o -name 'council-query.*' \) -mtime +1 -delete 2>/dev/null || true
find "$_TMPROOT" -maxdepth 1 -type d -name 'council-out.*' -mtime +1 -exec rm -rf {} + 2>/dev/null || true

# Councilor backends: shell functions sourced from council-def.sh (override path via COUNCILOR_LIB).
COUNCILOR_LIB="${COUNCILOR_LIB:-$HOME/.local/bin/council-def.sh}"
if [[ -r "$COUNCILOR_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$COUNCILOR_LIB"
fi

# Councilor list from config.json (councilors[]); each must be a function in the lib above.
# Fall back to the built-in three. (jq if available, else python3; bash-3.2-safe array build.)
COUNCILORS=(council-cc-glm council-codex-gpt council-cc-kimi)
_CFG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../config.json"
if [[ -r "$_CFG" ]]; then
  _list=()
  if command -v jq >/dev/null 2>&1; then
    while IFS= read -r _n; do [[ -n "$_n" ]] && _list+=("$_n"); done < <(jq -r '.councilors[]? // empty' "$_CFG" 2>/dev/null)
  else
    while IFS= read -r _n; do [[ -n "$_n" ]] && _list+=("$_n"); done < <(python3 -c "import json,sys
d=json.load(open(sys.argv[1])).get('councilors') or []
print('\n'.join(x for x in d if isinstance(x,str)))" "$_CFG" 2>/dev/null)
  fi
  [[ ${#_list[@]} -gt 0 ]] && COUNCILORS=("${_list[@]}")
fi

# Councilor prompt is LAYERED: a shared role/task + a per-backend capability note. Edit
# COUNCILOR_ROLE once and both backends track it; only the boundary text differs.

# Shared role + task (single source of truth).
COUNCILOR_ROLE="You are an external councilor invited to a consultation: give an independent second opinion on the query below, grounded in reading the working directory and reasoning. Respond with your analysis and a clear recommendation. Your output is only an opinion for the lead decision-maker to weigh — do not try to land any change on the user's behalf, and you never need to write your report to a file (your stdout is captured)."

# cc-* are NOT sandboxed (Bash can still write); the no-write boundary is on the model's honor — load-bearing.
COUNCILOR_CHARTER_EXTRA="You run on the user's machine with read access to the working directory and the ability to search the web, but you are NOT sandboxed — these limits are on your honor.
You MAY: read files in the working directory and the files named in the query; use WebSearch / WebFetch; and run a Bash command ONLY when you have confirmed it writes NOTHING to disk and is otherwise side-effect-free (no file / cache / artifact anywhere — not even a temp file; no git change; no heavy or long-running compute) — e.g. a read-only inspection. If a command or test would write to disk at all (most real test suites do — pytest caches, build artifacts), do NOT run it; reason from reading instead.
You MUST NOT: write any file to disk anywhere; change git (commit / push / add / checkout / rebase / reset / stash, or anything that writes .git); read credential / secret files outside the working tree (e.g. ~/.local/bin/council-def.sh, ~/.ssh, ~/.aws, any config holding a token / secret); install dependencies, start services or daemons; or run long / heavy commands. If unsure whether something is safe, do not run it."

# codex runs under `codex exec --sandbox read-only` (council-def.sh) — writes blocked at OS level; just name the mode.
CODEX_SANDBOX_NOTE="You are in a READ-ONLY sandbox: you can read files and run read-only commands, but any write / git change / side effect is blocked at the OS level. Just read, reason, and answer."

# Composed per-backend prompts.
COUNCILOR_CHARTER="$COUNCILOR_ROLE

$COUNCILOR_CHARTER_EXTRA"          # cc-* system prompt (via --append-system-prompt)
CODEX_PREAMBLE="$COUNCILOR_ROLE

$CODEX_SANDBOX_NOTE"               # codex: prepended to the query via stdin

COUNCILOR_FLAGS=(
  --allowedTools "Read" "Grep" "Glob" "WebSearch" "WebFetch" "Bash"
  --disallowedTools "Write" "Edit" "NotebookEdit"
  --append-system-prompt "$COUNCILOR_CHARTER"
)

# --- args ---------------------------------------------------------------------
if [[ $# -lt 1 ]]; then
  echo "usage: council.sh <query_file> [out_dir]" >&2
  exit 2
fi
QUERY_FILE=$1
if [[ ! -r "$QUERY_FILE" ]]; then
  echo "council.sh: query file not readable: $QUERY_FILE" >&2
  exit 2
fi
if [[ $# -ge 2 && -n ${2:-} ]]; then
  OUT=$2
  mkdir -p "$OUT" || { echo "council.sh: cannot create out_dir: $OUT" >&2; exit 2; }
else
  OUT=$(mktemp -d "${TMPDIR:-/tmp}/council-out.XXXXXX") \
    || { echo "council.sh: mktemp -d failed" >&2; exit 2; }
fi

# Per-round persisted opinions live in $PWD/.council/; .err/.status stay in the temp $OUT.
COUNCIL_DIR="$PWD/.council"
mkdir -p "$COUNCIL_DIR" || { echo "council.sh: cannot create $COUNCIL_DIR" >&2; exit 2; }
ROUND_TS=$(date +%Y%m%d-%H%M%S)

# --- fan out: launch every councilor in the background, print PID -------------
echo "OUT=$OUT"
echo "COUNCIL=$COUNCIL_DIR"

declare -a LABELS=() OUTFILES=() STATFILES=()
for name in "${COUNCILORS[@]}"; do
  label=$(basename -- "$name")
  codename=${label#council-}                  # council-cc-glm -> cc-glm
  outf="$COUNCIL_DIR/$codename-$ROUND_TS.md"   # the OPINION document (persisted under .council/)
  errf="$OUT/$codename.err"
  statf="$OUT/$codename.status"

  if ! command -v "$name" >/dev/null 2>&1; then
    echo "NOTFOUND $label"
    continue
  fi

  # Run the councilor in the background.
  case "$name" in
    council-codex-*)  # codex harness
      ( { printf '%s\n\n----- consultation query -----\n\n' "$CODEX_PREAMBLE"; cat "$QUERY_FILE"; } | "$name" >"$outf" 2>"$errf"; echo $? >"$statf" ) </dev/null >/dev/null 2>/dev/null &
      ;;
    *)                # claude code harness
      ( "$name" -p "${COUNCILOR_FLAGS[@]}" <"$QUERY_FILE" >"$outf" 2>"$errf"; echo $? >"$statf" ) </dev/null >/dev/null 2>/dev/null &
      ;;
  esac
  echo "LAUNCHED $label $! $outf $statf"
  LABELS+=("$label"); OUTFILES+=("$outf"); STATFILES+=("$statf")
done

# Wait under the caller's Bash timeout (finish → RESULT manifest below; exceed → auto-backgrounded).
wait

# --- RESULT manifest (statuses now known) -------------------------------------
any_ok=0
for i in "${!LABELS[@]}"; do
  label=${LABELS[$i]}
  outf=${OUTFILES[$i]}
  statf=${STATFILES[$i]}

  rc=1
  [[ -r "$statf" ]] && rc=$(tr -dc '0-9' <"$statf"); rc=${rc:-1}

  if [[ "$rc" -eq 0 && -s "$outf" ]]; then
    status="ok"; any_ok=1
  elif [[ "$rc" -eq 0 ]]; then
    status="empty"
  else
    status="failed"
  fi
  echo "RESULT $label $status $outf"
done

if [[ "$any_ok" -eq 1 ]]; then
  exit 0
else
  echo "council.sh: all councilors failed (no usable output)" >&2
  exit 1
fi
