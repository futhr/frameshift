# Physical Build Contract

**Status:** normative companion-platform contract; implementation open
**Owner:** Catalog & Compatibility; pure contracts in `packages/build-spec/`
**Milestone:** C, consumed by independent shopping lists in D and purchasing in F

## Profiles and evidence

**PB-01 — Exact facts.** Version component profiles for Paper, Photo, and Pixel:
display, controller, driver, frame, mat, carrier, mounting, power, connectors,
cables, storage, and required assembly items. Each fact has its unit, exact
manufacturer/part/revision scope, source reference and content digest, retrieval
date, evidence class, and applicable uncertainty/tolerance. Keep conflicting
facts and missing values explicit. Marketplace titles do not establish a part
revision or electrical specification.

Seed the current [candidate BOM](../hardware/bom.md) and manufacturer-based
[simulator](container-frame-simulator.md) facts: Waveshare 13.3-inch E6,
BOE MV270QHM-N40 preliminary P1, and Waveshare P3 64×64 modules. These are
simulation/prototype baselines. They do not qualify a combined assembly,
controller choice, supply chain, or purchasable route.

Separate immutable source facts from versioned evidence assessment and current
eligibility. Record evidence expiry, contradiction, quarantine, safety notices,
seller/integration capability and market/destination scope. A newer favorable
source cannot silently erase an earlier contradiction. Revocation can block a
route without rewriting a historical BuildSpec or order.

**PB-02 — Timing and power.** Source manufacturer-recommended refresh intervals,
minimum safe update spacing, waveform/full-refresh requirements, sleep behavior,
temperature range and power limits by exact profile. Preserve recommended and
mandatory limits as distinct fields. Use those recommendations for sensible
defaults under the [display-timing contract](display-timing.md); keep supported
customer overrides explicit. Unknown recommendations remain unknown. Longer
dwell is not evidence of meaningful energy savings for continuously powered
Photo or Pixel displays. Simulated behavior never becomes measured power data.

## Immutable BuildSpec

**PB-03 — Identity.** A BuildSpec pins its schema/compiler semantics, exact part
and profile revisions, quantities, canonical geometry/tolerances, mounting,
controller/electrical requirements, assembly intent, and compatibility inputs.
Define required fields, maximum sizes, permitted enums, schema migration, and
unsupported-version rejection before implementing consumers.

Use canonical units, bounded integers/fixed-point arithmetic, deterministic
ordering and serialization, and a versioned cryptographic digest. Set explicit
limits within JavaScript's safe integer range; refuse overflow and ambiguous
conversion. Equal pinned inputs must yield identical canonical bytes and hash
on both targets. Record compiler/rule identity with outputs so a semantic
change cannot reuse an old acceptance result accidentally.

Do not include mutable prices, availability, retrieval timestamps, current
market eligibility, or order state in physical identity. Preserve these as
separate versioned projections/records. Changes to selected parts, revisions,
geometry, or compatibility semantics produce a new specification. Recompiling
old pinned inputs cannot silently follow the latest profile revision.

**PB-04 — Constraint result.** Return `compatible`, `incompatible`, or `unknown`
with machine-readable constraint IDs, implicated part/revision IDs, source
references, relevant values/units, and clear explanations. Check:

- dimensions, tolerances, enclosure depth, clearances, stack-up and mat opening;
- connector pinout, electrical levels, controller/driver/panel interface;
- supply capacity, current limits, protection and documented power envelope;
- thermal evidence, mounting/load and strain relief;
- storage, firmware, artifact formats, protocol bindings and update behavior;
- quantities, required adapters, dependency cycles and missing assembly items.

Compatibility is conditional on modeled facts and scope. Missing required
facts, contradictions, and unqualified interfaces cannot pass through defaults.
Custom parts may appear in planning output with unknown results. Automated
purchasing requires the applicable compatibility, evidence and route gates;
an affirmative calculation alone does not certify physical safety.

**PB-05 — Existing product contracts.** Reuse protocol/profile identifiers and
existing bounded decisions without conflating physical configuration with
paired-device admission or exact render/transfer qualification. A shopping
list may provide non-secret installation hints. The installed host re-admits
the actual device and capabilities through its authenticated flow. New parts
using existing qualified contracts may be data additions; a new protocol,
electrical driver, artifact format, or executable capability needs code and
conformance evidence. A profile alone cannot make arbitrary hardware work.

## Deterministic implementation and formal verification

**PB-06 — Gleam boundary.** Implement reusable bounded physical decisions in
the existing pure Gleam package for BEAM and JavaScript. Normalize data at
explicit boundaries. The kernel owns deterministic decisions, not database
queries, source extraction, policy authority, I/O, clocks, randomness, or
inference. A browser supplies immediate feedback; the server recomputes every
accepted BuildSpec using pinned facts. Cross-runtime golden/generated fixtures
cover unit conversion, limits, ordering, refusals, and canonical output.

**PB-07 — Targeted ExMaude verification.** Use ExMaude for CI and asynchronous
catalog/rule admission, off the ordinary browser preview path. Frameshift owns
reviewed Maude modules and fixtures under `packages/build-spec/verification/`.
Check finite bounded composition properties, including:

1. Required interfaces/power/mounting constraints cannot be bypassed by an
   adapter chain or a circular dependency.
2. Missing, contradictory or quarantined required facts cannot yield admitted
   purchasing eligibility.
3. Part substitutions and changed constraints invalidate affected prior proof
   and quote eligibility rather than modifying accepted commitments.
4. Accepted part/revision identities remain immutable across new catalog or
   workflow generations.

Generate normalized facts and fixtures from shared schemas, but review formal
predicates independently from production decision code. Replay counterexamples
against the actual compiler and use deliberately broken-rule mutations to show
the verifier detects relevant faults. A duplicated implementation with the same
bug is not independent evidence. Formal results cover the model, assumptions,
and explored bounds; they do not prove supplier truth, unmodeled physics, or
certification.

Use the default Port backend and separate Maude OS processes in a small bounded
pool. Set CPU, memory, time, output and concurrency limits and prove termination
on overrun. Only reviewed modules and validated encoded data enter Maude.
Research documents/profile strings cannot supply executable source. Retrieve
witnesses/traces from the same worker session as the search that produced them.

**PB-08 — Result and invalidation contract.** The inspected ExMaude list-returning
search API does not establish exhaustion. Extend the generic upstream API with
typed completion evidence before admitting results:

| Outcome | Meaning and admission consequence |
| --- | --- |
| `counterexample` | A violation with replayable witness; reject the affected admission |
| `no_counterexample_within_bound` | No violation within recorded limits; cannot claim exhaustive verification; admit only where the invariant's reviewed policy explicitly accepts that bound |
| `exhausted_finite_model` | Search completed over the declared finite model; satisfies only the named modeled invariant |
| `inconclusive` | Timeout, truncation, malformed response, worker loss, unsupported semantics or missing completion evidence; cannot satisfy a required check |

Store fact/spec, model, invariant, tool/executable and rule versions/digests,
finite assumptions, bounds, search outcome, trace and replay result. Cache keys
include all semantic inputs and invalidate when any relevant input changes.
Current revocations are checked separately even on a proof-cache hit. Do not
treat an empty solution list as proof or collapse bounded/inconclusive outcomes.
ExMaude's generic result/session support belongs upstream; all Frameshift
models and admission policies stay here. Track the separate Maude executable's
license/distribution obligations for the exact deployed version.

## Required software evidence

**PB-09 — Acceptance.** C is complete only with reproducible fixtures for all
three classes and these checks:

- schema size/unit/overflow/version refusals and source-revision round trips;
- identical canonical bytes/hash across BEAM/JavaScript and reload/export;
- generated valid/invalid/unknown combinations and minimal typed explanations;
- independent formal predicates, mutation detection, trace replay, finite-bound
  and exhaustion distinction, timeout/truncation/worker-loss handling;
- proof invalidation after fact, rule, tool or quarantine changes;
- no silent accepted-spec mutation after candidate admission or substitution;
- browser/server disagreement refusal and profile-to-protocol mapping checks.

Physical measurements and external compliance evidence remain accurately
unqualified until recorded. They do not prevent implementing unknown/refusal
paths, complete simulators, or the independent planning journey.
