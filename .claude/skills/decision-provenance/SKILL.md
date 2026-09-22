---
name: decision-provenance
description: Apply automatically when Frameshift work depends on why a host/frame boundary, protocol behavior, capability, runtime direction, display class, component candidate, or physical constraint exists, or may reverse that decision. Reconstruct the decision from current docs, evidence, implementation, and targeted Git history before changing it.
user-invocable: true
argument-hint: "[decision, file, or subsystem]"
---

# Decision provenance

1. Find the canonical current statement in `docs/` and every document that
   consumes it.
2. Search related research, open questions, code, tests, build records, and
   targeted Git history around the owning lines.
3. Separate:
   - the decision and its semantic owner;
   - alternatives considered;
   - evidence available at the time;
   - invariant or user outcome being protected;
   - chosen boundary and known trade-offs;
   - validation reached and validation still missing;
   - later changes that supersede part of the reasoning.
4. Distinguish intentional architecture from a convenient prototype detail and
   current requirements from stale prose.
5. If revising the decision, enumerate effects on the host, Frame Protocol,
   capabilities, all three reference frames, rendering pipeline, offline
   behavior, security, power, mechanics, documentation, migration/versioning,
   validation, and rollback. Mark non-applicable surfaces explicitly.
6. Update the canonical research or specification source before implementation.
   Do not preserve contradictory documents as if both were current.

Report exact file and line references. If history does not contain the reason,
say `reason not recorded` and treat any reconstruction as inference.
