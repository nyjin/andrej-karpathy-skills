---
name: claudemd-bench
description: A/B benchmark two CLAUDE.md files. Runs qualitative (PEEM/G-Eval rubric) and quantitative (headless `claude -p` task battery) evaluations and produces a side-by-side scoreboard. Use when the user asks to "compare CLAUDE.md", "evaluate my CLAUDE.md", "is X better than Y", "benchmark global instructions", or "A/B test system prompt".
license: MIT
---

# claudemd-bench

Compare two `CLAUDE.md` files head-to-head. Two evaluation tracks:

| Mode | Cost | Time | Signal |
|------|------|------|--------|
| `qual` | free (inline) | ~30s | PEEM rubric, 12 dimensions × 2 files |
| `quant` | ~$1–6 (API) | ~3–15min | Behavioral A/B over task suite, headless `claude -p` |
| `both` *(default)* | quant cost | ~5–15min | Both reports + a verdict |

## When to invoke

- "내 CLAUDE.md가 X보다 더 잘 동작할까?"
- "이 CLAUDE.md 변경이 실제로 도움이 되는지 측정"
- "두 CLAUDE.md 비교", "A/B test system prompt", "evaluate global instructions"

## Inputs

```
/claudemd-bench <A> <B> [--mode=qual|quant|both] [--n=1] [--tasks=<file>] [--model=opus|sonnet|haiku]
```

- `<A>`, `<B>`: each may be **either** a local file path **or** a URL. Supported URL forms:
  - GitHub blob: `https://github.com/<owner>/<repo>/blob/<ref>/<path>` *(auto-rewritten to raw)*
  - Raw GitHub: `https://raw.githubusercontent.com/<owner>/<repo>/<ref>/<path>`
  - Gist raw: `https://gist.githubusercontent.com/...`
  - Any other plain HTTP(S) markdown URL
- `--mode`: default `both`.
- `--n`: replicates per (task × CLAUDE.md). Default `1`. Use `3` for variance estimates.
- `--tasks`: optional user-provided task file (JSON, schema in `references/runner.md`). Merged with built-in suite.
- `--model`: override model. Default = current session model.

Confirm with the user before running `quant` if estimated cost > $3 (compute: `n_tasks × 2 × n × ~$0.18`).

### URL → local file resolution

`scripts/ab-run.sh` only accepts local paths. Before invoking it, resolve each URL argument:

```bash
# Portable across macOS bash 3.2 — uses sed instead of BASH_REMATCH (which is
# unreliable across subshells and old bash versions on macOS).
resolve_input() {
  local arg="$1"
  case "$arg" in
    http://*|https://*)
      # Rewrite github.com/<owner>/<repo>/blob/<ref>/<path> → raw.githubusercontent.com/<owner>/<repo>/<ref>/<path>
      local url
      url="$(printf '%s' "$arg" | sed -E 's#^https://github\.com/([^/]+)/([^/]+)/blob/(.+)$#https://raw.githubusercontent.com/\1/\2/\3#')"
      local tmp; tmp="$(mktemp -t claudemd-bench-XXXXXX.md)"
      if ! curl -fsSL "$url" -o "$tmp"; then
        # Fallback: gh CLI for private repos. Re-parse via sed.
        local gh_owner gh_repo gh_ref gh_path
        gh_owner="$(printf '%s' "$arg" | sed -E -n 's#^https://github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)$#\1#p')"
        gh_repo="$(printf '%s' "$arg" | sed -E -n 's#^https://github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)$#\2#p')"
        gh_ref="$(printf '%s' "$arg" | sed -E -n 's#^https://github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)$#\3#p')"
        gh_path="$(printf '%s' "$arg" | sed -E -n 's#^https://github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)$#\4#p')"
        if command -v gh >/dev/null && [ -n "$gh_owner" ] && [ -n "$gh_path" ]; then
          gh api "repos/$gh_owner/$gh_repo/contents/$gh_path?ref=$gh_ref" \
            --jq '.content' | base64 -d > "$tmp" || { echo "gh fetch failed: $arg" >&2; return 2; }
        else
          echo "fetch failed: $arg" >&2; return 2
        fi
      fi
      [ -s "$tmp" ] || { echo "fetched empty content from $arg" >&2; return 2; }
      # Sanity: reject HTML (likely a 404 page or rate-limit response).
      if head -c 200 "$tmp" | grep -qiE '<!doctype html|<html'; then
        echo "fetched HTML, not markdown, from $arg (check URL or auth)" >&2
        return 2
      fi
      printf '%s' "$tmp"
      ;;
    *)
      [ -f "$arg" ] || { echo "not found: $arg" >&2; return 2; }
      printf '%s' "$arg"
      ;;
  esac
}

A_PATH="$(resolve_input "$A_INPUT")" || exit 2
B_PATH="$(resolve_input "$B_INPUT")" || exit 2
```

After resolution, pass `A_PATH` and `B_PATH` to `ab-run.sh`. Record the **original** input strings (URL or path) in `report.md` so the user knows what was compared, not the temp filename.

## Workflow

### Step 1 — Resolve & validate inputs
- For each of `<A>`, `<B>`: if it starts with `http://` / `https://`, fetch via the `resolve_input` helper above into a temp file. Otherwise treat as local path.
- Both resolved files must exist and be non-empty markdown.
- If they're identical (`diff -q`), warn the user and ask if they want to proceed anyway (no signal expected).
- Confirm `claude`, `curl`, and `jq` are on PATH (and `gh` if private GitHub URLs are used).

### Step 2 — Qualitative (`qual` or `both`)

1. Read both CLAUDE.md files.
2. Read `references/rubric-qualitative.md`.
3. For each of the 12 PEEM dimensions, score A and B (0–10) **with rationale grounded in specific lines**. Do not invent strengths — cite quotes.
4. Produce a markdown scoreboard (table, weighted total, top-3 deltas).

This step is done inline by the calling Claude. No `claude -p` calls.

### Step 3 — Quantitative (`quant` or `both`)

1. Load task suite: `references/tasks.json` + any user `--tasks` file.
2. **Pre-flight isolation** (canonical: handled by `scripts/run-bench.sh`):
   - Backup `~/.claude/CLAUDE.md`, replace with empty content. Auto-restored on exit via bash trap.
   - Inner cells use `--setting-sources project` from `cwd=/tmp` (which has no project settings) to bypass user settings — language directive, plugins, hooks, MCP all disabled.
   - Set env `CLAUDEMDBENCH_PREPPED=yes` before invoking `ab-run.sh`.
   - **User confirmation required before swap.** `run-bench.sh` shows a warning and reads `yes` from stdin.
   - Why not `--bare`? It requires `ANTHROPIC_API_KEY` (disables OAuth/keychain). The swap-based path keeps OAuth working while achieving equivalent isolation.
3. For each `(task, claude_md, replicate)`:
   ```bash
   cd /tmp && claude -p "$task_prompt" \
     --append-system-prompt-file "$claude_md" \
     --setting-sources project \
     --output-format json \
     --max-budget-usd 0.30 \
     --model "$model" \
     --disallowedTools "Bash(git push:*) Bash(gh:*) Bash(curl:*) Bash(wget:*) Bash(rm -rf:*)" \
     > "$out_dir/cells/$task_id-$variant-$rep.json"
   ```
   - `--max-budget-usd` caps each run.
   - Disallowed tools prevent external side-effects even on rogue runs.
   - Use `scripts/ab-run.sh` for parallel orchestration (see `references/runner.md`).
3. For each run, extract: response text, tool uses, turn count, total cost. Score against the task's `expected_behaviors` and `anti_behaviors` (binary 0/1 per criterion). The scorer is the calling Claude — no extra API call.
4. Aggregate: per-task, per-category, per-CLAUDE.md totals. Compute deltas, p-values if `n ≥ 5`.

### Step 4 — Report

Write to `<skill_dir>/runs/<timestamp>/` (i.e., inside the skill, not the user's cwd):
- `report.md` — human-readable side-by-side, top deltas, verdict
- `scores.json` — machine-readable for trend tracking
- `cells/` — raw `claude -p` JSON outputs (replayable), one file per `(task, variant, replicate)`
- `qual.md` — qualitative-only output (if mode included it)

The `runs/` directory is gitignored (see `.gitignore` in the skill dir).

Show `report.md` to the user. Mention raw cells are saved for replay, and tell the user the absolute path of the run directory.

## Files

- `references/tasks.json` — built-in 10-task behavioral suite (covers CLAUDE.md's 5 principles)
- `references/rubric-qualitative.md` — PEEM/G-Eval 12-dimension rubric
- `references/runner.md` — exact `claude -p` invocation, JSON schema, scoring protocol
- `scripts/ab-run.sh` — bash orchestrator for parallel inner A/B runs
- `scripts/run-bench.sh` — outer end-to-end runner. Builds a self-contained user-message prompt and pipes to `claude -p`. **No system-prompt injection on the outer call** — all instructions live in the prompt body. Inner runs (spawned by ab-run.sh) still use `--append-system-prompt-file` to inject each CLAUDE.md being benchmarked.
- `examples/sample-report.md` — example output format

## Standalone invocation (no skill loader required)

```bash
~/src/andrej-karpathy-skills/skills/claudemd-bench/scripts/run-bench.sh \
  ~/.claude/CLAUDE.md \
  https://github.com/forrestchang/andrej-karpathy-skills/blob/main/CLAUDE.md \
  both 1 opus
```

This works without the skill being registered/loaded — the wrapper hands a fully-specified prompt to `claude -p`.

## Cost & safety

- Default `quant` run: ~10 tasks × 2 variants × 1 rep × ~$0.18 ≈ **$3.60** (opus, with cache).
- **What that dollar figure means depends on auth mode:**
  - With `ANTHROPIC_API_KEY` set → real spend, billed to your Anthropic API account.
  - On Claude Code OAuth (default) → API-equivalent usage, consumed against your subscription's rate-limit quota. Not directly billed in $.
  - `run-bench.sh` detects the mode and labels the pre-flight estimate accordingly.
- Hard cap per run: `--max-budget-usd 0.30` (enforced in both modes — Claude Code stops the cell if equivalent cost exceeds the cap).
- Side-effect protection: `--disallowedTools` blocks push/gh/curl/wget/rm -rf. Run from `/tmp` cwd.
- Never run without user confirmation if estimated cost > $3 OR `n × tasks > 30`.

### Isolation (Tier-2, swap-based)

- `run-bench.sh` backs up `~/.claude/CLAUDE.md` and truncates it for the duration of the run, restoring on exit (success/failure/Ctrl+C) via bash `trap`. **User must type `yes` to authorize.**
- Inner cells use `--setting-sources project` from `cwd=/tmp` — project settings are not present in /tmp, so this effectively loads no settings (no language directive, no plugins, no hooks, no MCP).
- This is functionally equivalent to `--bare` without requiring `ANTHROPIC_API_KEY`.
- **Recovery:** if killed by SIGKILL or power loss, the backup remains at `~/.claude/CLAUDE.md.benchbak.<pid>` — restore with `cp -p`. `run-bench.sh` warns about stale backups on next start.

## Limitations

- LLM-as-judge variance: behavioral scoring is binary (yes/no per criterion) to reduce noise, but edge cases exist. Default `n=1` gives directional signal only — use `n=3+` for confidence.
- Task suite is small (10) and biased toward CLAUDE.md's 5 principles. Add domain-specific tasks via `--tasks` for relevance to your real work.
- `claude -p` headless mode behaves slightly differently than interactive (no TTY prompts → may auto-decline some clarifications). Treat results as relative comparison, not absolute scores.
