---
name: unslop
description: Cut AI tells from Frameshift's human-facing prose while preserving technical, physical, legal, sourcing, safety, product, and domain precision. Use when writing or editing README, docs, specifications, research, comments, commit messages, PR text, or summaries; also /unslop FILE.
user-invocable: true
argument-hint: "[file or text]"
---

# Unslop

Strip patterns that mark text as machine-written. Meaning stays; voice tightens.

## Banned words

delve, crucial, pivotal, testament, tapestry, landscape, interplay, intricate,
vibrant, underscore, enduring, additionally, leverage, robust, seamless,
comprehensive, holistic, foster, empower, journey, elevate, supercharge

Keep a banned word only when it is part of a verbatim title, quotation,
identifier, or external product name.

## Banned constructions

- "serves as", "stands as", or "acts as" when "is" has the same meaning;
- "not just X, but Y";
- forced groups of three where two concrete points are enough;
- empty gerund tails such as "ensuring reliability";
- hedge stacks such as "could potentially";
- "It's important to note", "Here's where it gets interesting", and "the
  kicker";
- vague authority such as "experts believe" or "many argue";
- filler: replace "in order to" with "to" and remove "the fact that" where
  grammar permits.

## Formatting and tone

- Use bold as a scan anchor, not decoration.
- Do not use decorative emoji.
- Prefer a period to an em-dash chain or colon splice.
- Remove "Great question", "Hope this helps", "Let's dive in", conclusion
  preambles, and recaps that repeat the answer.
- Start with the subject or outcome. Do not add a scene-setting paragraph about
  technology trends.

## Frameshift calibration

Write as an engineering research project, not a product launch. Use the status
vocabulary in `docs/README.md` exactly. Keep panel names, part numbers,
revisions, interfaces, units, measurements, evidence limits, code, commands,
paths, dates, currencies, and citations unchanged unless they are factually
wrong and the task includes correcting them.

Do not simplify uncertainty into certainty. `Evidence-prose` governs claim
strength and composes with this editing pass.

## Self-audit

Reread once and remove any sentence that sounds generated, markets an unproven
idea, repeats a prior conclusion, or uses abstraction where a concrete noun and
verb are available.

With a file argument, rewrite the file under these rules, preserve technical
claims and code blocks, and report the substantive edits in two or three lines.
