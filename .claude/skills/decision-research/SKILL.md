---
name: decision-research
description: Apply automatically when a Frameshift architecture, protocol, host, hardware, sourcing, rendering, security, or frame decision depends on facts not established in the repository, or when revising an existing research conclusion. Prefer current primary sources, record dates and locators, separate evidence from interpretation, and write the result under docs/research/.
user-invocable: true
argument-hint: "[research question or topic]"
---

# Decision research

This is a documentation-only workflow. Write under `docs/research/` and update
`docs/research/open-questions.md` or `docs/README.md` when the new record changes
their inventory. Do not modify source code, freeze a specification, or present a
purchase as authorized.

## Method

1. State one decision-shaped question. Name the owner and the decision that the
   answer will inform.
2. Inventory related repository documents and Git history. Record which sources
   were screened closely and any material exclusions.
3. Prefer current primary sources:
   - standards, protocol specifications, and platform documentation;
   - manufacturer data sheets, mechanical drawings, integration manuals, and
     reference designs;
   - upstream runtime or library documentation and source;
   - peer-reviewed papers or reproducible technical reports.
4. Use resellers, marketplaces, forums, videos, and summaries only as secondary
   sourcing or field evidence. Never let one listing establish compatibility.
5. Record the publication or revision date and retrieval date. Cite a page,
   section, table, drawing, commit, or exact URL where possible.
6. Reconcile supporting, contradicting, superseded, and missing evidence.
   Distinguish vendor claims, repository interpretation, calculations, and
   physical measurements.
7. End with one result: **candidate**, **prototype-selected**, **validated**,
   **rejected**, or **deferred**. A validated result requires a linked test or
   build record from the exact tested configuration.
8. Name the falsifier and the next action. A candidate must say what measurement
   or inspection can reject it.

## Hardware and sourcing minimums

For an exact component, record the manufacturer part number and revision,
interface, electrical limits, active area and outline, thickness, connector
location, required controller or waveform/scan mode, environment limits,
supplier region, stock observation, price with currency and tax/shipping basis,
and retrieval date. Mark every missing field `unverified`.

For a calculated value, show inputs, units, formula, margin, and which inputs
remain vendor claims. Do not substitute a maximum rating for measured normal
operation.

## Document shape

Use a descriptive filename: `docs/research/<topic>.md`.

```markdown
# <Decision topic>

**Status:** in progress
**Updated:** YYYY-MM-DD

## Decision
<The decision this research informs.>

## Question
<One answerable question.>

## Repository context
<Current requirements, candidates, and dependent documents.>

## Evaluation criteria
<Required, preferred, and disqualifying conditions.>

## Evidence
### <Source or experiment>
<Claim, locator, date, and evidence tier.>

## Conflicts and uncertainty
<Contradictions, unknowns, and volatile observations.>

## Analysis
<Repository interpretation and calculations.>

## Result
**State:** candidate | prototype-selected | validated | rejected | deferred
<Reason, owner, scope, and falsifier.>

## Follow-up
<Concrete inspection, purchase decision, experiment, or specification update.>

## References
- <Primary source, locator, revision/publication date, retrieved YYYY-MM-DD>
```

Delete empty sections only when they genuinely do not apply. There is no fixed
length. Stop when the evidence can support the decision and expose its remaining
uncertainty.
