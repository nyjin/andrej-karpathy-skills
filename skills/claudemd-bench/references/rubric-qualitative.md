# Qualitative Rubric (PEEM / G-Eval inspired)

Score each CLAUDE.md on 12 dimensions, 0–10 each. Weighted total out of 100.

**Critical scoring rule:** every score must be grounded in **specific quoted lines** from the file. If you can't cite a line, you can't claim the strength/weakness exists. No vibes.

## Dimensions (weights in parentheses)

### A. Structural quality (30 pts)

1. **Specificity (10)** — Are guidelines concrete enough to act on?
   - 10: Every rule has an example, threshold, or decision criterion ("after 3 failed approaches", "scope/time/quality/reversibility").
   - 5: Mostly principles ("write good code") with some examples.
   - 0: Pure platitudes.

2. **Decidability (10)** — Can the model determine *when* a rule applies?
   - 10: Each rule has explicit triggers ("when editing existing code...", "for multi-step tasks...").
   - 5: Some rules have triggers, others are blanket statements.
   - 0: Rules without context — model must guess applicability.

3. **Conciseness (10)** — Token efficiency vs. coverage.
   - 10: Tight prose, no filler, every line carries weight.
   - 5: Some redundancy or padding.
   - 0: Bloated, repeats itself, multi-paragraph prose where bullets would do.

### B. Behavioral coverage (40 pts)

4. **Anti-assumption / clarification (8)** — Does it tell the model when to ask vs. proceed?
5. **Anti-sycophancy (8)** — Does it tell the model to push back, surface tradeoffs, not capitulate?
6. **Simplicity / anti-overengineering (8)** — Forbids speculative features, premature abstraction?
7. **Surgical scope (8)** — Forbids drive-by refactors, requires changes to trace to request?
8. **Stop conditions / persistence control (8)** — Defines when to pause and ask?

### C. Operational fitness (30 pts)

9. **Verifiability (10)** — Pushes the model toward measurable success criteria (tests, checks)?
10. **Format consistency (10)** — Headers, lists, code blocks used predictably; easy to parse mentally?
11. **Failure-mode awareness (10)** — Does it acknowledge specific LLM failure modes (hallucination, drift, sycophancy) or just give abstract principles?

### D. Risk / hidden cost (10 pts, can subtract)

12. **Side-effect cost (10)** — Penalize for content that could *backfire* in real use:
    - Conflicting instructions (-2 each)
    - Rules so strict they prevent reasonable autonomy (-2 each)
    - Outdated/wrong technical claims (-3 each)
    - Excessive verbosity that wastes context budget (-1 per ~100 surplus lines)

## Scoring procedure

1. Read both files top-to-bottom.
2. For each dimension, write:
   - `A: <score>` with one quoted line as evidence
   - `B: <score>` with one quoted line as evidence
   - `Δ: <A−B>` and one-line rationale
3. Sum weighted scores. Report:
   - **Total A vs B** out of 100
   - **Top 3 dimensions where A wins** (largest +Δ)
   - **Top 3 dimensions where B wins** (largest −Δ)
   - **Verdict**: which file is *probably* better, with a confidence note (qualitative scoring is directional — confirm with `quant` mode).

## Output template

```markdown
## Qualitative comparison: A vs B

| # | Dimension | A | B | Δ | Note |
|---|-----------|---|---|---|------|
| 1 | Specificity | 8 | 5 | +3 | A: "after 3 failed approaches"; B: "be persistent" |
| ... | | | | | |

**Total: A=82, B=64**

### A wins biggest on
1. Specificity (+3) — A names concrete thresholds; B uses abstract "be careful"
2. ...

### B wins biggest on
1. ...

### Verdict
A is the stronger guideline document, **driven primarily by specificity and stop-condition coverage**. Run `quant` to confirm this translates to behavioral differences.
```
