#!/usr/bin/env bash
# End-to-end orchestrator: builds a self-contained user-message prompt and pipes
# it into `claude -p`. No --system-prompt / --append-system-prompt-file on the
# OUTER call — all workflow instructions live in the user message.
#
# (Inner per-task runs spawned by ab-run.sh DO use --append-system-prompt-file
# to inject each CLAUDE.md being benchmarked — that's the A/B variable.)
#
# Tier-2 isolation pre-flight (replaces --bare for OAuth-auth users):
#   1. Backs up ~/.claude/CLAUDE.md, replaces with empty content
#   2. Inner cells use --setting-sources project (cwd=/tmp has none) to
#      bypass user-level settings (language directive, plugins, hooks, MCP)
#   3. Auto-restores CLAUDE.md on exit / SIGINT / SIGTERM via bash trap
# User confirmation is required before the swap is performed.
#
# Usage:
#   run-bench.sh <A: path-or-url> <B: path-or-url> [mode=both] [n=1] [model=opus]
#
# Example:
#   ./scripts/run-bench.sh \
#     ~/src/andrej-karpathy-skills/CLAUDE.md \
#     https://github.com/forrestchang/andrej-karpathy-skills/blob/main/CLAUDE.md

set -euo pipefail

A_INPUT="${1:?A path or URL required}"
B_INPUT="${2:?B path or URL required}"
MODE="${3:-both}"
N="${4:-1}"
MODEL="${5:-opus}"

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${SKILL_DIR}/runs/$(date +%Y%m%d-%H%M%S)"

command -v claude >/dev/null || { echo "claude CLI not on PATH" >&2; exit 2; }
mkdir -p "$OUT_DIR"

# ---------- Tier-2 isolation pre-flight ----------
USER_CLAUDEMD="${HOME}/.claude/CLAUDE.md"
BACKUP="${USER_CLAUDEMD}.benchbak.$$"
PROMPT_FILE=""
USER_CLAUDEMD_EXISTED=""

# Set up cleanup BEFORE any swap, so partial state is recoverable on early exit.
cleanup() {
  local rc=$?
  [ -n "$PROMPT_FILE" ] && rm -f "$PROMPT_FILE"
  if [ -f "$BACKUP" ]; then
    if cp -p "$BACKUP" "$USER_CLAUDEMD" 2>/dev/null; then
      rm -f "$BACKUP"
      echo "==> Restored ${USER_CLAUDEMD} from backup." >&2
    else
      echo "ERROR: restore failed. Manual restore required:" >&2
      echo "  cp -p ${BACKUP} ${USER_CLAUDEMD}" >&2
    fi
  elif [ "$USER_CLAUDEMD_EXISTED" = "no" ]; then
    rm -f "$USER_CLAUDEMD" 2>/dev/null || true
  fi
  exit "$rc"
}
trap cleanup EXIT INT TERM

# Detect stale backups from previous failed runs.
STALE=$(ls "${USER_CLAUDEMD}".benchbak.* 2>/dev/null | grep -v "^${BACKUP}$" || true)
if [ -n "$STALE" ]; then
  echo "WARN: stale backup file(s) detected from a previous run:" >&2
  echo "$STALE" >&2
  echo "If ${USER_CLAUDEMD} looks empty/wrong, restore one of these manually." >&2
  echo "" >&2
fi

# Estimate cost (tasks count × 2 variants × n replicates × per-cell baseline).
TASKS_COUNT=$(jq '.tasks | length' "${SKILL_DIR}/references/tasks.json" 2>/dev/null || echo 10)
EST_COST=$(awk "BEGIN { printf \"%.2f\", ${TASKS_COUNT} * 2 * ${N} * 0.18 }")

cat >&2 <<EOF
============================================================
claudemd-bench — pre-flight check
============================================================

Estimated quant cost: ${TASKS_COUNT} tasks × 2 × ${N} × \$0.18/cell ≈ \$${EST_COST}
(orchestrator cap: \$8; aborts if exceeded)

To make A/B test cells see ONLY the CLAUDE.md being benchmarked,
this run will neutralize three contamination sources:

  1. Backup ${USER_CLAUDEMD} → empty content for the duration of this run
     auto-restored on exit (success, failure, Ctrl+C)
     backup path: ${BACKUP}
  2. Inner cells use --setting-sources project from cwd=/tmp
     bypasses user settings — disables language directive, plugins, hooks, MCP
  3. cwd=/tmp for inner cells
     skips project CLAUDE.md auto-discovery

Why: --bare (the canonical isolation flag) requires ANTHROPIC_API_KEY.
This swap-based path keeps OAuth/keychain auth working.

Risks:
  - SIGKILL or power loss leaves the backup at ${BACKUP}
    Restore manually:  cp -p ${BACKUP} ${USER_CLAUDEMD}
  - Do NOT run other 'claude' sessions while this is in progress —
    new sessions started during the swap window will see the empty file.

============================================================
EOF

if ! [ -t 0 ]; then
  echo "ERROR: no TTY on stdin; cannot prompt for confirmation." >&2
  echo "Run from an interactive terminal." >&2
  exit 2
fi

read -r -p "Type 'yes' to proceed: " ANSWER
if [ "$ANSWER" != "yes" ]; then
  echo "Aborted by user." >&2
  exit 1
fi

# Perform the swap.
mkdir -p "$(dirname "$USER_CLAUDEMD")"
if [ -f "$USER_CLAUDEMD" ]; then
  USER_CLAUDEMD_EXISTED="yes"
  cp -p "$USER_CLAUDEMD" "$BACKUP" || { echo "backup failed: $USER_CLAUDEMD -> $BACKUP" >&2; exit 2; }
else
  USER_CLAUDEMD_EXISTED="no"
fi
: > "$USER_CLAUDEMD"

# Signal to ab-run.sh that prep is complete; it refuses to run otherwise.
export CLAUDEMDBENCH_PREPPED="yes"

echo "==> CLAUDE.md isolated (backup at: ${BACKUP})" >&2

# ---------- Build orchestrator prompt ----------
PROMPT_FILE="$(mktemp -t claudemd-bench-prompt-XXXXXX)"

cat > "$PROMPT_FILE" <<EOF
You are orchestrating a CLAUDE.md A/B benchmark. All workflow logic is documented in files under ${SKILL_DIR}. There is no system-prompt context for this run — read what you need from disk.

# Pre-flight (already done by run-bench.sh — DO NOT redo)
- ~/.claude/CLAUDE.md has been backed up and emptied for the duration of this run.
- ab-run.sh inner cells use --setting-sources project from cwd=/tmp to bypass
  user settings (language, plugins, hooks, MCP). \$CLAUDEMDBENCH_PREPPED=yes
  is set so ab-run.sh accepts the run.
- Restoration of ~/.claude/CLAUDE.md happens automatically on exit via bash trap.
  Do not touch the backup file.

# Inputs
- A = ${A_INPUT}
- B = ${B_INPUT}
- mode = ${MODE}
- n = ${N}
- model = ${MODEL}
- out_dir = ${OUT_DIR}

# Files to read (in this order)
1. ${SKILL_DIR}/SKILL.md
2. ${SKILL_DIR}/references/rubric-qualitative.md
3. ${SKILL_DIR}/references/tasks.json
4. ${SKILL_DIR}/references/runner.md

# Workflow
Follow the workflow defined in SKILL.md exactly. Specifically:

1. Resolve and validate inputs. Use the resolve_input shell function from SKILL.md to convert URL inputs to local temp files. Verify both resolved files are non-empty markdown. If they are byte-identical, abort with a message saying that no signal is expected because A and B are identical, then exit cleanly.

2. Qualitative pass (skip if mode=quant). Read both CLAUDE.md files. Apply the 12-dimension PEEM rubric from rubric-qualitative.md. Score each dimension 0-10 for both files with quoted evidence for every score. Produce qual.md with the scoreboard, top deltas, and verdict.

3. Quantitative pass (skip if mode=qual). Run this command:
     bash ${SKILL_DIR}/scripts/ab-run.sh "${OUT_DIR}" "<resolved_A>" "<resolved_B>" "${SKILL_DIR}/references/tasks.json" ${N} ${MODEL} 4
   This produces ${OUT_DIR}/cells/<task_id>__<variant>__<rep>.json files. Then for each run:
   - Parse the JSON (extract the result text plus any tool_use entries from messages).
   - Score binary against each task expected_behavior and anti_behavior as defined in runner.md. Each criterion: 0 or 1, with one-line evidence (a quoted sentence from the response, or the tool_use name).
   - Aggregate per-task, per-category, and per-CLAUDE.md.
   Write scores.json (machine-readable) and append the quant section to report.md.

4. Final report. Write ${OUT_DIR}/report.md combining qual plus quant plus verdict. In the report, refer to A and B by their original input strings (${A_INPUT}, ${B_INPUT}), not the resolved temp paths.

5. Cost guardrail. Tasks_count times 2 times ${N} times \$0.18 per cell. Pre-computed estimate: \$${EST_COST}. If actual run-time cost approaches \$5, prefer to abort rather than continue.

6. Print the final report.md to stdout when done. Also print the absolute path of ${OUT_DIR}.

Use Bash, Read, Write, and Edit tools as needed. Do not ask for confirmation — execute end-to-end.
EOF

echo "==> Output dir: $OUT_DIR" >&2
echo "==> Launching outer claude -p (orchestrator)" >&2

# Outer call: NO --append-system-prompt-file, NO --bare. Default settings so the
# orchestrator has full tooling. $(< file) reads the prompt verbatim with no
# subshell quote-parsing.
claude -p "$(< "$PROMPT_FILE")" \
  --model "$MODEL" \
  --max-budget-usd 8.00 \
  --permission-mode bypassPermissions \
  --output-format text
