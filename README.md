# Karpathy-Inspired Claude Code Guidelines (Enhanced)

English | [한글](README.ko.md)

An enhanced `CLAUDE.md` to improve Claude Code behavior, derived from [Andrej Karpathy's observations](https://x.com/karpathy/status/2015883857489522876) on LLM coding pitfalls.

This README walks through three layers:

1. **The problems** Karpathy identified
2. **How [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills)** addressed them with 4 principles
3. **How this fork improves further** with pattern-based triggers, two new principles, and aggressive pruning

## The Problems

From Andrej's post:

> "The models make wrong assumptions on your behalf and just run along with them without checking. They don't manage their confusion, don't seek clarifications, don't surface inconsistencies, don't present tradeoffs, don't push back when they should."

> "They are still a little too sycophantic."

> "They really like to overcomplicate code and APIs, bloat abstractions, don't clean up dead code... implement a bloated construction over 1000 lines when 100 would do."

> "They still sometimes change/remove comments and code they don't sufficiently understand as side effects, even if orthogonal to the task."

> "It's so interesting to watch an agent relentlessly work at something. They never get tired, they never get demoralized, they just keep going..."

Five distinct failure modes: **silent assumptions**, **sycophancy**, **bloat**, **side-effect edits**, and **blind tenacity**.

## How forrestchang's CLAUDE.md Addresses These

Upstream organizes the response into **4 principles**, each tied to one or more of Karpathy's problems:

| Upstream Principle | Karpathy Problem(s) Addressed |
| --- | --- |
| **§1 Think Before Coding** | Wrong assumptions, hidden confusion, missing tradeoffs, unstated push-back |
| **§2 Simplicity First** | Overcomplication, bloated abstractions, 1000-line constructions |
| **§3 Surgical Changes** | Side-effect edits to adjacent code, dead-code creation |
| **§4 Goal-Driven Execution** | Leverages Karpathy's "loop on success criteria" insight (test-first, declarative goals) |

The upstream version uses **self-awareness triggers** (e.g., *"if uncertain, ask"*, *"if multiple interpretations exist, present them"*) and adds a closing self-check (*"Would a senior engineer say this is overcomplicated?"*, *"If you write 200 lines and it could be 50, rewrite it"*).

What upstream **doesn't** address directly:

- **Sycophancy** — collapsed into a single line *"Push back when warranted"* inside §1, easily missed
- **Inconsistency between codebase and request** — not called out
- **Inconsistency between code and its own comments** — not called out
- **Blind tenacity** — Karpathy's tenacity observation (*"they just keep going..."*) has no corresponding rule; the model has no instruction to ever stop and escalate

## How This Fork Improves Further

Five focused changes on top of upstream, plus a `Foundations` block that anchors everything below.

| Change | Why |
| --- | --- |
| **Foundations section at the top** | Two non-negotiables surfaced before the numbered principles: *never decide silently* and *use judgment on trivialities, loop on strong criteria*. Anchors all five principles. |
| **Pattern-based triggers** | *"If uncertain, ask"* depends on self-awareness LLMs don't reliably have. Replaced with externally checkable conditions: *did the user specify this?*, *is the change risky (architecture / dependencies / schema / broad scope)?*, *do the inputs contradict?* |
| **Named tradeoff axes** | Vague *"surface tradeoffs"* → four explicit axes: **scope, time, quality, reversibility**. Reduces "what counts as a tradeoff" ambiguity. |
| **Push-back rule made explicit and bounded** | Upstream's single line *"Push back when warranted"* → *"User's approach has a flaw → push back **once**, then follow"*. Same intent, but bounded so it doesn't degrade into nagging. Directly targets the sycophancy problem. |
| **Inconsistency rule added to §1** | *"Codebase contradicts request, or code contradicts its own comments → ask before acting."* Not present in upstream. |
| **Comment preservation rule added to §3** | *"Don't edit, rephrase, or remove existing comments unless the task requires it."* Direct response to Karpathy's *"they still sometimes change/remove comments..."* observation. Not present in upstream. |
| **§5 Know When to Stop (new)** | Karpathy's tenacity observation cuts both ways. 3-attempt threshold + structured escalation format converts blind retry into a checkpoint. |
| **Self-check ceremony pruned** | Removed *"would a senior engineer say overcomplicated?"*, *"if 200 lines could be 50, rewrite"*, and similar. LLMs apply rules during generation, not via post-hoc introspection — those lines were costing tokens without changing behavior. |

## The Five Principles

### Foundations

- **Core:** Never decide silently — ask before acting, or surface assumptions in your response.
- **Autonomy:** Use judgment on trivialities (note the call in your report); loop independently when success criteria are strong.

### 1. Think Before Coding

Don't assume. Don't hide confusion. Surface to the user when:

- **Risky** (architecture, dependencies, schema, broad scope) → ask first; otherwise "Assumed X — change if not"
- **Tradeoff axis hit** (scope, time, quality, reversibility) → name them, let the user choose
- **User's approach has a flaw** → push back once, then follow
- **Inconsistency** (codebase vs. request, code vs. comments) → ask before acting

### 2. Simplicity First

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.

### 3. Surgical Changes

Touch only what you must — every changed line must trace to the user's request; otherwise revert. Match existing style even if you'd do it differently. Don't refactor, reformat, rename, or rewrite comments outside the task. Remove only the imports/variables/functions *your* changes orphaned. Report unrelated issues (pre-existing dead code, etc.) at the end of your response — don't fix them silently.

### 4. Goal-Driven Execution

Define success criteria. Loop until verified. Transform vague tasks into verifiable goals — usually test-first:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step or multi-decision requests, propose a plan with per-step verification before executing.

### 5. Know When to Stop

Persistence is strength. Blind persistence is waste.

- After 3 failed approaches (or silent retries with minor variations), pause. Summarize failures. Ask for direction.
- If a fix cascades into new failures, step back and reconsider — don't keep patching.

The escalation format makes this concrete: list each attempt, why it failed, and a best-guess path forward — then wait.

## Design Decisions

### Pattern-based triggers over self-awareness

LLMs don't reliably recognize their own uncertainty. *"If uncertain, ask"* tends to collapse into *"feel confident, proceed silently."* This version replaces self-introspection with **externally checkable conditions** — *did the user specify this?*, *does this touch architecture / schema / dependencies?*, *do the inputs contradict?* These are easier to apply consistently mid-generation.

### Bounded push-back instead of standalone sycophancy rule

Pushing back on a flawed approach is a special case of *"don't hide confusion"* — the flaw *is* the confusion to surface. Keeping it as a §1 sub-bullet (rather than a standalone principle) plus the *"once, then follow"* boundary prevents the rule from degrading into either silent compliance or repeated nagging.

### Why §5 exists

Karpathy: *"They never get tired, they never get demoralized, they just keep going..."* That tenacity is real leverage, but it also produces 30 minutes of silent retries on a doomed approach. A 3-attempt threshold plus a structured escalation format converts that energy into a checkpoint instead of a slot machine.

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

Changes from upstream [forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills):

- Added **Foundations** section — explicit Core + Autonomy rules above the principles
- Added **§5 Know When to Stop** — 3-attempt threshold with escalation format
- Added **inconsistency handling** to §1 — codebase vs. request, code vs. comments
- Added **named tradeoff axes** — scope, time, quality, reversibility
- Added **comment preservation rule** to §3 — don't edit, rephrase, or remove existing comments outside the task
- Made **push-back rule explicit and bounded** in §1 — once, then follow
- Switched **triggers from self-awareness to pattern-based** — externally checkable conditions
- **Pruned** self-check ceremony (*"senior engineer overcomplicated?"*, *"200 lines → 50"*) — no measurable behavioral effect

## License

MIT
