---
name: spec-authoring
description: Apply automatically when Frameshift needs a new or revised architecture, Frame Protocol, reference-frame, host, or hardware specification. Research repository truth first, write in the owning docs subtree, separate requirements from candidates, and define observable acceptance evidence without inventing implementation or validation.
user-invocable: true
argument-hint: "[document path or subject]"
---

# Specification authoring

## Ownership

| Subject | Canonical location |
|---|---|
| System boundaries, capabilities, content pipeline, Frame Protocol | `docs/architecture/` |
| Photo, paper, or pixel reference target | `docs/frames/` |
| macOS host behavior and packaging | `docs/host/` |
| Shared physical constraints and BOM policy | `docs/hardware/` |
| Evidence, comparisons, experiments, and open questions | `docs/research/` |

Do not create `docs/specs/`. Link every new top-level document from
`docs/README.md`.

## Method

1. Read the owning document, its consumers, related research, open questions,
   and relevant Git history.
2. List unresolved facts. Run `decision-research` before writing requirements
   that depend on facts absent from the repository.
3. Define the owner, boundary, inputs, outputs, invariants, failure behavior,
   security posture, offline behavior, and compatibility behavior that apply.
4. State requirements as observable behavior. Use BCP 14 keywords (`MUST`,
   `SHOULD`, `MAY`) only when the sentence is intentionally normative.
5. Label implementation directions and hardware selections as candidates until
   the required evidence exists. Do not hide an unresolved choice inside an
   example.
6. Define acceptance evidence at the correct tier. Source inspection, a unit
   test, protocol interoperation, a macOS lifecycle test, and a physical bench
   measurement prove different claims.
7. Preserve non-goals. Name excluded cloud, vendor, display, runtime, and
   real-time assumptions where a reader might otherwise infer them.
8. Apply `evidence-prose` and `unslop`, then run `spec-readiness`.

## Required content

Use the sections that fit the owner; merge them into an existing document when
it already has a clear structure.

```markdown
# <Title>

**Status:** research | draft | candidate | prototype | validated

## Purpose
<The problem and the canonical owner.>

## Scope
<Included behavior and explicit non-goals.>

## Requirements
<Numbered, observable normative requirements.>

## Interfaces and data
<Messages, capabilities, inputs, outputs, state, and version behavior.>

## Failure and recovery
<Partial transfer, power loss, network loss, invalid state, rollback, and retry.>

## Security and privacy
<Trust boundary, authentication, authorization, stored secrets, and local data.>

## Physical constraints
<Dimensions, power, thermals, connectors, mounting, and service access.>

## Acceptance evidence
| Claim | Evidence | Environment or fixture | Pass condition |
|---|---|---|---|
| <claim> | <test, inspection, or measurement> | <exact setup> | <observable threshold> |

## Dependencies and open decisions
<Hard predecessor, candidate input, owner, and closure condition.>

## Sources
- <Repository file or external primary source with locator and date>
```

Delete sections that provably do not apply. Do not leave placeholders, invented
module names, fictional dates, unverified dimensions, or generic acceptance
language such as "add tests".
