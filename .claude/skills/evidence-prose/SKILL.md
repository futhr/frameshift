---
name: evidence-prose
description: Apply automatically to Frameshift README, research, specifications, hardware notes, build records, comments, release notes, and summaries. Keep architecture, compatibility, sourcing, safety, physical, performance, and completion claims scoped to the evidence actually reached.
user-invocable: true
argument-hint: "[audit | rewrite] [file or text]"
---

# Evidence prose

Write the strongest claim the evidence supports, not the strongest claim that
would make the project sound settled.

## Evidence ladder

| Tier | Supports | Does not support by itself |
|---|---|---|
| Proposal | A direction worth evaluating | Feasibility or compatibility |
| Primary source | A manufacturer, standard, platform, or upstream claim | Whole-system behavior |
| Calculation | A result under stated inputs and margins | Real power, thermal, optical, or mechanical performance |
| Source inspection | Intended implementation behavior | Runtime behavior on the target |
| Automated test | Behavior covered by its fixture and environment | Hardware or cross-implementation behavior |
| Bench measurement | The recorded physical configuration under test conditions | Other revisions or environments |
| Prototype integration | The assembled prototype behavior that was exercised | Production readiness, safety certification, or long-term reliability |

## Rules

- Name the exact subject, revision, configuration, environment, date, and owner
  of a claim when they affect its truth.
- Separate quoted or paraphrased source claims from repository interpretation.
- Mark inference as inference. Show calculations with inputs, units, formula,
  margin, and source for each input.
- Use `candidate` for plausible but physically unverified components. Use
  `validated` only with a linked record for that exact configuration.
- Never convert `should work`, a successful compile, or individual compatible
  data-sheet values into a compatibility claim.
- Distinguish maximum rating, typical value, design budget, and measured value.
- Qualify volatile price, stock, operating-system, library, firmware, and vendor
  information with region, version, and observation or retrieval date.
- Verify every path, link, command, identifier, dimension, count, and example
  before citing it.
- Keep safety language bounded. Passing a prototype measurement is not product
  certification or evidence of unattended-use safety.
- Remove filler, marketing copy, generic AI phrasing, and repeated conclusions.

## Modes

- Default: write or edit under these rules.
- `audit`: report the quoted fragment, unsupported evidence jump, and a bounded
  replacement. Change nothing.
- `rewrite`: first identify evidence jumps, then revise while preserving facts,
  measurements, citations, identifiers, and code blocks.
