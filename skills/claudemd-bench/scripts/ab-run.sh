#!/usr/bin/env bash
# A/B run orchestrator for claudemd-bench.
#
# Usage:
#   ab-run.sh <out_dir> <claude_md_A> <claude_md_B> <tasks_json> [n=1] [model=opus] [parallel=4]
#
# Reads tasks from tasks_json, runs `claude -p` for each (task × variant × replicate),
# writes one JSON per cell into <out_dir>/cells/.
#
# Pre-flight requirement (Tier-2 isolation):
#   The caller (run-bench.sh, or the skill orchestrator) is responsible for
#   swapping ~/.claude/CLAUDE.md to an empty file BEFORE invoking this script,
#   and restoring it on exit. See run-bench.sh for the canonical implementation.
#   $CLAUDEMDBENCH_PREPPED=yes signals the caller has done the swap.
#
#   Per-cell isolation flags used here:
#     --setting-sources project   (excludes user settings; cwd=/tmp has none)
#     --append-system-prompt-file (injects the CLAUDE.md being benchmarked)
#     cwd=/tmp                    (skips project CLAUDE.md auto-discovery)

set -euo pipefail

OUT_DIR="${1:?out_dir required}"
A_PATH="${2:?CLAUDE.md A path required}"
B_PATH="${3:?CLAUDE.md B path required}"
TASKS_JSON="${4:?tasks json path required}"
N="${5:-1}"
MODEL="${6:-opus}"
PARALLEL="${7:-4}"

# Pre-flight: caller must have done the CLAUDE.md swap.
if [[ "${CLAUDEMDBENCH_PREPPED:-}" != "yes" ]]; then
  echo "ERROR: CLAUDEMDBENCH_PREPPED!=yes." >&2
  echo "Caller must swap ~/.claude/CLAUDE.md before invoking this script." >&2
  echo "Use scripts/run-bench.sh as the canonical entry point." >&2
  exit 2
fi

# Sanity checks
for f in "$A_PATH" "$B_PATH" "$TASKS_JSON"; do
  [[ -f "$f" ]] || { echo "missing: $f" >&2; exit 2; }
done
command -v claude >/dev/null || { echo "claude CLI not on PATH" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq required (brew install jq)" >&2; exit 2; }

mkdir -p "$OUT_DIR/cells"

# Build a flat list of: task_id|variant|rep|prompt
WORK_FILE="$(mktemp)"
trap 'rm -f "$WORK_FILE"' EXIT

jq -r '.tasks[] | [.id, .prompt] | @tsv' "$TASKS_JSON" | \
while IFS=$'\t' read -r task_id prompt; do
  for variant in A B; do
    for rep in $(seq 1 "$N"); do
      printf '%s\t%s\t%s\t%s\n' "$task_id" "$variant" "$rep" "$prompt"
    done
  done
done > "$WORK_FILE"

TOTAL=$(wc -l < "$WORK_FILE" | tr -d ' ')
echo "Running $TOTAL cells (parallel=$PARALLEL, model=$MODEL)..." >&2

run_one() {
  local task_id="$1" variant="$2" rep="$3" prompt="$4"
  local cm_path
  if [[ "$variant" == "A" ]]; then cm_path="$A_PATH"; else cm_path="$B_PATH"; fi
  local out="$OUT_DIR/cells/${task_id}__${variant}__${rep}.json"

  if [[ -f "$out" ]]; then
    echo "skip $task_id/$variant/$rep (exists)" >&2
    return 0
  fi

  # Run from /tmp so cwd has no project files to influence the model.
  # --setting-sources project (with cwd=/tmp) excludes user-level settings —
  # no language directive, no plugins, no hooks, no MCP. Caller must have
  # already swapped ~/.claude/CLAUDE.md to empty for full isolation.
  (cd /tmp && claude -p "$prompt" \
    --append-system-prompt-file "$cm_path" \
    --setting-sources project \
    --output-format json \
    --max-budget-usd 0.30 \
    --model "$MODEL" \
    --disallowedTools "Bash(git push:*) Bash(gh:*) Bash(curl:*) Bash(wget:*) Bash(rm -rf:*)" \
    > "$out" 2>"$out.stderr") || {
      echo "FAIL $task_id/$variant/$rep (see $out.stderr)" >&2
      # Keep an error stub so the scorer can detect it.
      echo "{\"is_error\":true,\"failure_reason\":\"claude -p exited non-zero\"}" > "$out"
    }
  echo "done $task_id/$variant/$rep" >&2
}
export -f run_one
export A_PATH B_PATH OUT_DIR MODEL

# Parallel runner via xargs
< "$WORK_FILE" xargs -P "$PARALLEL" -I {} bash -c '
  IFS=$"\t" read -r task_id variant rep prompt <<< "$1"
  run_one "$task_id" "$variant" "$rep" "$prompt"
' _ {}

echo "All runs complete. Outputs in $OUT_DIR/cells/" >&2
