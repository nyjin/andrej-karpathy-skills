# Karpathy-Inspired Claude Code Guidelines (Enhanced)

An enhanced `CLAUDE.md` to improve Claude Code behavior, derived from [Andrej Karpathy's observations](https://x.com/karpathy/status/2015883857489522876) on LLM coding pitfalls.

Based on [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills), which nailed the core principles. This fork extends it with a few additions for my workflow.

## The Problems

From Andrej's post:

> "The models make wrong assumptions on your behalf and just run along with them without checking. They don't manage their confusion, don't seek clarifications, don't surface inconsistencies, don't present tradeoffs, don't push back when they should."

> "They really like to overcomplicate code and APIs, bloat abstractions, don't clean up dead code... implement a bloated construction over 1000 lines when 100 would do."

> "They still sometimes change/remove comments and code they don't sufficiently understand as side effects, even if orthogonal to the task."

> "It's so interesting to watch an agent relentlessly work at something. They never get tired, they never get demoralized, they just keep going..."

## The Seven Principles

| Principle | Karpathy Problem |
| --- | --- |
| **Think Before Coding** | Wrong assumptions, hidden confusion, missing tradeoffs, inconsistencies |
| **Be Direct, Not Sycophantic** | Too agreeable, don't push back |
| **Simplicity First** | Overcomplication, bloated abstractions, 1000 lines → 100 |
| **Surgical Changes** | Side-effect edits, touching code you shouldn't |
| **Goal-Driven Execution** | Leverage through tests-first, declarative goals |
| **Know When to Stop** | Blind persistence, spinning without progress |
| **Pre-Submit Review** | Unstated assumptions, missing tests |

Plus a **Task Sizing Guide** that scales effort to complexity (small/medium/large).

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Three sub-concerns, each with pattern-based triggers:

- **Assumptions** — If you're deciding something the user didn't specify, ask first.
- **Confusion management** — If the codebase contradicts the request, or code and comments disagree, stop and flag it.
- **Tradeoff format** — "Option A optimizes for [X] at the cost of [Y]. Option B does the reverse. Which matters more here?"

### 2. Be Direct, Not Sycophantic

**Honest feedback is more valuable than agreement.**

- Push back on flawed approaches before complying.
- Give real assessments, not reassurance.
- State your concern once, then respect the user's decision.

### 3. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

No unrequested features, no single-use abstractions, no passthrough wrappers. Includes a concrete list of common bloat patterns: factory classes for single implementations, config objects with one field, abstraction layers "for future extensibility," and try/catch around code that can't throw.

### 4. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

Don't improve, refactor, reformat, or rename anything outside the task. Match existing style. Report unrelated issues at the end — don't fix them silently.

### 5. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform vague tasks into test-first, verifiable goals with step-by-step plans. Strong criteria → loop independently. Weak criteria → clarify first.

### 6. Know When to Stop

**Persistence is strength. Blind persistence is waste.**

After 3 failed approaches, pause and escalate with a structured format showing what was tried, why it failed, and a suggested path forward.

### 7. Pre-Submit Review

Two checks before presenting work: assumptions stated, tests exist (or explained why not).

## Design Decisions

### Pattern-Based Triggers

LLMs don't reliably recognize their own uncertainty. Instead of "if uncertain, ask," this version uses externally checkable conditions like "if you're deciding something the user didn't specify" or "if the request has gaps or contradictions."

### Task Sizing Guide

Scales guideline rigor to task complexity using compound criteria (file count + concern count + line count). Small tasks skip the ceremony; large tasks require a full plan.

### Minimal Checklist

The pre-submit review has only 2 items. LLMs apply rules during generation, not via post-hoc checklists. Items that duplicate earlier sections were removed to save tokens.

## Install

**Option A: CLAUDE.md (recommended)**

New project:

```bash
curl -o CLAUDE.md https://raw.githubusercontent.com/nyjin/andrej-karpathy-skills/main/CLAUDE.md
```

Existing project (append):

```bash
echo "" >> CLAUDE.md
curl https://raw.githubusercontent.com/nyjin/andrej-karpathy-skills/main/CLAUDE.md >> CLAUDE.md
```

**Option B: Skills directory**

```bash
mkdir -p skills/karpathy-guidelines
curl -o skills/karpathy-guidelines/SKILL.md https://raw.githubusercontent.com/nyjin/andrej-karpathy-skills/main/skills/karpathy-guidelines/SKILL.md
```

## How to Know It's Working

- Diffs contain fewer unnecessary changes
- Fewer rewrites due to overcomplication
- Clarifying questions come before implementation, not after mistakes
- Pushback and tradeoff analysis before silent compliance
- Failed approaches are reported early, not after 20 minutes of spinning

## Customization

These guidelines are designed to be merged with project-specific instructions:

```markdown
## Project-Specific Guidelines

- Use TypeScript strict mode
- All API endpoints must have tests
- Follow the existing error handling patterns in `src/utils/errors.ts`
```

## Changelog

Changes from the upstream [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills):

- Added §2 "Be Direct, Not Sycophantic" — honest feedback over agreement
- Added §6 "Know When to Stop" — 3-attempt threshold with escalation format
- Added §7 "Pre-Submit Review" — 2-item self-check
- Added Task Sizing Guide — small/medium/large with compound criteria
- Added confusion management subsection to §1 — codebase contradictions, code/comment disagreements
- Added tradeoff response template to §1
- Added bloat pattern list to §3 — factory, config, wrapper, dead try/catch
- Added scope escalation rule — pause if scope grows mid-task
- Changed triggers from self-awareness ("if uncertain") to pattern-based ("if user didn't specify")

## License

MIT