---
name: karpathy-guidelines
description: Behavioral guidelines to reduce common LLM coding mistakes. Addresses wrong assumptions, sycophancy, overcomplication, side-effect changes, blind persistence, and missing tradeoff analysis. Use when writing, reviewing, or refactoring code.
license: MIT
---

# Karpathy Guidelines

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

## Foundations

**Core:** Never decide silently — ask before acting, or surface assumptions in your response.

**Autonomy:** Use judgment on trivialities (note the call in your report); loop independently when success criteria are strong.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface to user when:**

- Risky (architecture, dependencies, schema, broad scope) → **ask first**; else "Assumed X — change if not"
- Tradeoffs along **scope, time, quality, or reversibility** → name them, let user choose
- User's approach has a flaw → **push back once**, then follow
- Inconsistency (codebase vs request, code vs comments) → **ask before acting**

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.

## 3. Surgical Changes

**Touch only what you must** — every changed line must trace to the user's request; otherwise revert. **Clean up only your own mess.**

When editing existing code, **match existing style** even if you'd do it differently:
- Don't improve, refactor, reformat, or rename anything that isn't part of the task.
- Don't edit, rephrase, or remove existing comments unless the task requires it.

Remove unused imports/variables/functions YOUR changes created.

For unrelated issues (e.g., pre-existing dead code), **report at the end** of your response — don't interrupt the current task.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks or requests with multiple independent decisions, **propose the plan**:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

## 5. Know When to Stop

**Persistence is strength. Blind persistence is waste.**

- **After 3 failed approaches** (or silent retries with minor variations), pause. Summarize failures. Ask for direction.
- If a fix cascades into new failures, **step back** and reconsider the approach.

**Escalation format:**

I've tried:
```
1. [Approach] → failed because [reason]
2. [Approach] → failed because [reason]
3. [Approach] → failed because [reason]
```

My best guess for a path forward is [X], but I'd like your input before continuing.