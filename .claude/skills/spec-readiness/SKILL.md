---
name: spec-readiness
description: Apply automatically before implementing a Frameshift specification. Check the owning document against repository truth, research state, boundaries, capability and protocol seams, failure modes, security, physical constraints, dependencies, and executable acceptance evidence; report pass or fail with file:line repairs.
user-invocable: true
argument-hint: "[specification path]"
---

# Specification readiness

Read the target, its linked research, documents on both sides of each interface,
and any existing implementation. Review only unless the user asked for edits.

## Checks

1. **Ownership**: one canonical owner is named and the document is in the
   correct `docs/` subtree.
2. **Evidence state**: research, candidate, reference, prototype, and validated
   claims use the repository vocabulary accurately.
3. **Repository truth**: paths, commands, types, modules, devices, and existing
   behavior are real. Proposed names are marked as proposals.
4. **Boundaries**: host, protocol, frame agent, display adapter, and physical
   panel responsibilities do not leak into each other without a stated reason.
5. **Requirements**: normative statements are observable, internally
   consistent, and separate from candidates or examples.
6. **Capability model**: behavior follows advertised capabilities where
   possible. Vendor and model identifiers are restricted to genuine quirks.
7. **Lifecycle**: discovery, pairing, rendering, transfer, verification,
   commit, persistence, upgrade/versioning, and recovery are covered where
   relevant.
8. **Failure and offline behavior**: partial transfer, corrupt content, power
   loss, network loss, host sleep, retry, rollback, and last-valid-artwork
   behavior are explicit where relevant.
9. **Security and privacy**: trust boundaries, first-use pairing,
   authentication, authorization, secret storage, replay/downgrade concerns,
   and local artwork handling are addressed or explicitly deferred with an
   owner and closure condition.
10. **Physical completeness**: dimensions include panel, board, connector,
    cable bend, PSU, thermal, mounting, backing, and service clearance. Power
    claims distinguish maximum ratings, calculations, and measurements.
11. **Dependencies and non-goals**: hard predecessors, optional candidates,
    exclusions, and volatile external dependencies are named.
12. **Acceptance evidence**: each material claim maps to a specific inspection,
    test, interoperability check, or physical measurement with a pass condition
    and exact environment.
13. **Source quality**: non-obvious external claims have current primary-source
    locators and retrieval dates. Prices and availability include region,
    currency, and observation date.
14. **No fictional completion**: an unavailable device, credential, OS setup,
    or physical build is a remaining gate, not a simulated pass.

## Output

```text
Specification readiness: <path>

PASS | FAIL  1. Ownership — <evidence>
PASS | FAIL  2. Evidence state — <evidence>
...

Verdict: READY | NOT READY

Required repairs:
- path:line — <one concrete repair>
```

`READY` means an implementation agent can act without inventing ownership,
behavior, dependencies, hardware facts, or completion criteria. Any failed
check makes the verdict `NOT READY`.
