# Conjunct source and integration readiness

**Inspected:** 2026-09-25. **Evidence:** local Git/source/specification inspection.
No producer runtime, CAD conversion, new hardware, external service or model
qualification is established by this source record.

## Source cohort

| Material | Exact inspected revision | Finding |
| --- | --- | --- |
| Frameshift implementation | Current working tree and [verification map](../architecture/verification.md) | Four app roots, shared packages, source catalog, telemetry and retained v1 physical checks |
| Conjunct producer | 0.2.0 working specification identified [below](#conjunct-02-working-specification) | Generic core, instruction and host contracts; no qualified runtime package |
| Other producers | Exact cohorts in the [producer table](#other-library-expectations) | Existing exports require a joined consumer map and profile-specific evidence |

The Conjunct corpus was read from a sibling checkout as source evidence. A
local path is not a package dependency or distribution channel. Repository
visibility and publication remain separate user/producer decisions.

## Conjunct 0.2 working specification

A local read on 2026-09-25 found Conjunct 0.2.0 working specification files,
including a contract audit and implementation matrix. Frameshift uses those
requirements through
[PC-01–PC-09](../architecture/producer-contracts.md). This is specification
alignment with a library being built; it does not require that library to have
already delivered its code. Producer implementation, adapter implementation and
joined conformance are separate obligations.

The snapshot selects wire/domain/number semantics, purpose-bound CheckReports,
occurrence counts, offline freshness,
retention, transforms, procedure execution, worker limits and restore closure.
P1 specifies Refpath durable scoped admission; P2 specifies ExMaude completion
and leased trace evidence. Both have owners, inputs/results and falsifying tests.
They can be implemented alongside Conjunct's deterministic core and viewer.
Actual schema/diagnostic fixtures are frozen with each slice before claiming
its producer or consumer conformance.

### Snapshot identity

These digests identify the exact working files read, not a released package.
The SHA-256 of the following
UTF-8 manifest (LF lines, final LF, sorted by path) is
`8e76dd1c29b35fb58845c6e6329b6537178fa6aed623b4b7bdf80ec9af506958`.

```text
e58b6f8197a9b19ad15838b5adec04ea3d1d8d4f58d59c82eef2f9a5ff364086  docs/README.md
fd6ee636737407b01102bd3d8abc15d0629bb5d9a6c5772bbb1d60b4873f5b9b  docs/plans/implementation.md
5b875d9cb4d8739482460902f7dac309642177cdc39fc63584427864b012e43a  docs/research/contract-audit.md
659ca48aea570ffd1ce0dbb978d41eee9632aee64d9d4139c06577e93c61f451  docs/research/ecosystem-handoff.md
ffc930cfc670311da0f7a1e50afa7944722c95b932d27d5faa2af0c712852994  docs/research/standards-and-prior-art.md
be2893db17c67289cccabb631689af70299d0102f3185793c4664b70e698622b  docs/specs/CJ.01-foundation.md
bbf4860853ba2ef156291ac749e885913dea572062541f1767963ac0fd6c6f36  docs/specs/CJ.02-product-graph.md
51d7869e8ac0ac74842b655b625dbe649c89a0044cabc9bf85752053237874f4  docs/specs/CJ.03-evidence-and-federation.md
320fea25577899529dfd47f2491544991b044c438e52771275f887b451629b79  docs/specs/CJ.04-geometry-and-instructions.md
b7fa38a0f145323192c987daa5507683b93dee11a677dcc64e5b3121fbc3224b  docs/specs/CJ.05-production-and-service-plans.md
c02efdbec741d99fa8e697742aa24096a7007659ccdc92598e60ba3f5ddf3475  docs/specs/CJ.06-adaptive-applications.md
8660758ff0dc9cbc15ae2ef851ba2a43c1ec4f691d7ecb542eda151bf47ad465  docs/specs/CJ.07-security-and-operations.md
bf176f3aa20cd6fbcabc68d5fe532123cb146bd1fe0a5efb52ace5cc30100d47  docs/specs/CJ.08-conformance-and-delivery.md
```

### Other-library expectations

The 0.2 contract audit reports the following source observations. This consumer
update read that audit; it did not rerun producer tests or turn observed commits
into new dependency pins. Recheck actual public exports when implementing the
consumer mapping. Existing installed pins retain their own earlier evidence.

| Producer / audit cohort | Observed surface | Required consumer work |
| --- | --- | --- |
| Refpath `4a8e128628cac28706b0479bd2eabd3b9d240236` | CapabilityManifest generation compile/verify, SolutionBundle/Resolver, HotReload, OperationExecutor, EffectLifecycle and UI graph | Reuse exports; implement P1 durable scoped head/CAS/fence/cold-start extension at RT.35 and prove the Conjunct join |
| ExMaude `73acecf087934e593d6bae231b0e1a4d2ddf60b4` | Search, parsed results and pool checkout exist | P2 adds typed termination and leased same-session evidence; generic pool machinery is not missing wholesale |
| DocShell `3a04f3523e330671c67d380b31b7d739d62f1b2b` | Collection creation/digest/load and site projection | Bind exact procedure/localization and host-authorized fields; portable output needs no live server |
| Rivure `0d23e8d07b9102d6d437e524073d8cc19328720c` | ExternalCommitment preview/invoice/finalize/cancel/refund and Connect operations | Qualify existing financial/account APIs if F resumes; Refpath delivers the financial command and Rivure owns PSP execution/retry |
| phoenix-assets `c76b626104e938d1c6601b73ed8c4d9d7aa4feb3` | Host type generation and preset integration | Keep one generated-contract owner and qualify typed scene/procedure components |

Wotex and Beamlens retain their existing Frameshift owners, dependency pins and
separate evidence. PC-07/PC-08 specifies the additional consumer behavior. No generality, device
control, financial or diagnostic capability is inferred from another profile.

## Product and producer direction

Adopt Conjunct's physical-product composition and procedural model. Frameshift
is the first modular reference product and integration proof of concept. Keep
its native app and device behavior product-owned; demonstrate generic contracts
with exact frame inputs and an independently useful composition/instruction view.
The proof-of-concept role defines what is being demonstrated, not an exemption
from the software checks or permission to claim physical validation.

The parts/shopping list is one output alongside visual instructions, evidence
and portable composition data. Transactional shop work is on hold. Optional
service capabilities have separate admission and producer gates. Payment
integration, a fee model or a seller topology does not define the composition
engine. Company decisions remain external inputs when an operation needs them.

The normative mapping is [CI-01–CI-08](../architecture/conjunct-integration.md).
Generic validation, normalization, composition, comparison, check aggregation,
catalog/parts projection and procedure/instruction semantics belong to
Conjunct. Frameshift supplies exact frame profiles, rules, content, a product UI,
authorized storage and the independent native artwork/device system. The
retained v1 compiler is replay and migration evidence, not a second workbench
engine. Refpath's operator generation is not required for independent
composition and instructions.

## Existing Frameshift implementation

The current tree includes the following bounded implementation. There is no
implemented checkout, payment ledger, supplier order or dropshipping flow.

| Implemented material | Retain or adapt |
| --- | --- |
| `workspace.json`, boundary checks and app moves | Retain actual `apps/core`, `apps/macos`, `apps/guide`, `apps/build-platform` paths and affected build/package evidence |
| Phoenix/Ash/phoenix-assets/Svelte foundation and exact Refpath seam | Retain product host, schema isolation, generated contracts and command boundary; qualify additional producer APIs separately |
| Immutable source/profile actions, audit, metadata/profile downloads and explicit seed import | Retain exact identity, source binding, actor policy and transaction behavior; map richer evidence concepts without rewriting historical rows |
| Fixed-bucket server metrics and alert fixtures | Retain bounded aggregation, labels, reset/coverage semantics and protected exposition; qualify destination/collector integration later |
| Physical arithmetic, graph/rectangle algorithms and independent oracles | Strong candidates for generic extraction with explicit input assumptions and a non-frame consumer |
| Profile/assembly/mapping/layout codecs and compilation context | Retain v1 imports and identities; define producer mapping and successor formats before switching |
| Frame geometry, electrical, thermal, mounting, signal and artifact checks | Retain tested behavior; split reusable calculations from mandatory frame-profile rules |
| Source candidates for Paper, Photo and Pixel | Retain source digests, conflicts, missing facts and actual evidence tier; wider leads remain research |
| Readiness and implementation records | Keep dated results in [decision research](build-platform-decisions.md); they do not prove Conjunct conformance |

The [verification ledger](../architecture/verification.md) records current
bounded package checks and remaining producer joins. Passing v1 tests does not
prove Conjunct conformance.

## Required Conjunct contracts

| Source | Adopted requirement | Remaining evidence |
| --- | --- | --- |
| CJ.01 | Small generic core plus named product profiles; no vendor or networking requirement for passive products | Actual exports and a passive consumer without Frameshift imports |
| CJ.02 | Distinct product, composition, procedure, assessment, execution and offer identities; typed constraints, semantic diffs and dependency invalidation | Exact wire/schema and v1 migration; whole-compiler report and qualification |
| CJ.03 | Source/proposal/claim/observation/assessment/admission separation; rights and signed federated pack closure | Importer, trust-root, loss/revocation and publication tests; source permissions |
| CJ.04 | Source geometry distinct from analysis/mesh; stable feature IDs; structured procedures and accessible visual/print/offline output | One permitted conversion pipeline and exact frame procedure, unknown/refusal fixtures |
| CJ.05 | Separate production, packaging, service and as-built views with typed capabilities | Deferred service producer integration; no inferred factory or supplier acceptance |
| CJ.06 | Existing Refpath generation/UI/effect owners; exact inputs, current authority, successor and restart behavior | Actual export map and two differently scoped operators from the same code |
| CJ.07 | Bounded parser/model workers, private asset protection, execution profiles and independent diagnostics | Isolation/restore/overload tests and exact operated-host qualification |
| CJ.08 | Independent formal predicates, counterexample replay, passive and connected consumers, no proof from an empty bounded search | Qualified ExMaude result/session API and product/producer conformance corpus |
| Frame hardware research | Complete installed thinness, geometry grades, panel/driver/controller hypotheses and source locators | No new E2–E4 evidence or acquired CAD; retain the [matrix](thin-composition-evidence.md) as research |

Conjunct's standards research is a mapping queue, not a mandate to add every
format or library. Its AAS/BOM, WoT, STEP/geometry and other interoperability leads
stay producer-owned. Select actual adapters from rights-permitted samples;
record version, native identifiers and conversion loss. No full CAD authoring,
ERP/MES replacement, generic rule-engine service or new solver is required merely
because it appears in the research queue.

## Compatibility and adoption risks

1. **Canonical bytes differ.** Current Frameshift codecs use bounded ASCII,
   specified field order and a final LF. CJ.02 now selects UTF-8/RFC 8785 and
   exact rational SI quantities under wire/profile revisions. That is
   a new wire contract, not a rename. Preserve old hashes and verify an explicit
   successor mapping, including duplicate-key, Unicode, numbers and overflow.
2. **Physical vocabularies differ.** The current `Instance` is a selected
   occurrence; a received serial/lot is a separate record. Frame class enums,
   raster/driver/retention obligations and Missing/Conflicting semantics cannot
   be promoted wholesale into a universal core or erased during conversion.
3. **Generic profiles must keep obligations.** A passive enclosure need not
   have a controller; a Frameshift display still must. A caller cannot select
   fewer checks to acquire compatibility. Required unknowns remain unknown.
4. **Contract readiness differs from integration readiness.** Conjunct 0.2
   defines the required behavior and producer extensions. Encoders, viewers,
   adapters and joined tests remain implementation work at their named owners.
   Refpath P1 and ExMaude P2 can progress alongside the independent core/viewer.
5. **Observability is a deployment join.** CJ.07 names GreptimeDB in the shared
   host direction and permits Prometheus/OpenTelemetry ingestion. Preserve the
   current exporter; qualify ingestion/auth/retention/outage separately. No
   database change follows from the word selected in a specification.
6. **Scope and evidence remain explicit.** No arbitrary diagonal ceiling means
   no product-policy ceiling. Current byte, pixel, axis, count and arithmetic
   limits still apply. A code migration cannot enlarge hardware capabilities.

## Producer delivery and frame-specific work

Start with the current exact frame fixtures and freeze the product profile's
required semantics. Map one existing generic algorithm/codec boundary to a real
Conjunct export; replay the same corpus before switching authority. Extend to a
source-bound frame procedure/view and the upstream passive enclosure/packaging
and connected-sensor consumers. A second product requiring frame imports fails
the generality gate. Add two operator profiles through actual Refpath exports
once the deterministic path is useful. Optional service work remains parked.

Native behavior, authenticated device custody, artwork rendering and protocol
state do not move into the engine. Their existing checks and release paths
remain separate. Physical model improvements must still account for all three
frame families, installed depth, electrical/thermal limits, connectors, power
modes and mounting; conversion cannot infer missing parameters.

## Specification readiness

Scope: the CI/PC consumer requirements and staged extraction plan against the
0.2 working specification. This does not admit a missing implementation or any
external effect. Producer coding work is distinct from an undecided contract.

| Check | Result and evidence |
| --- | --- |
| Ownership | PASS — CI-01/CI-04 and BP-07 assign generic producer and Frameshift product owners |
| Evidence state | PASS — exact draft/source cohorts and prior bounded test results are distinct |
| Repository truth | PASS — current paths and actual v1 types inspected; future packages are conditional |
| Boundaries | PASS — native state, physical composition, generation and finance retain distinct authority |
| Requirements | PASS — CI-02/CI-03 define identity, replay, refusal and migration requirements |
| Capability model | PASS — explicit product profile and supported producer exports; no vendor branching |
| Lifecycle | PASS — successor, current revocation, old work and rollback dispositions are required |
| Failure/offline | PASS — deterministic/native paths survive unavailable optional producers; no implied successful fallback |
| Security/privacy | PASS — scoped commands, pack rights, parser bounds and separate device authority |
| Physical completeness | PASS — CI-06/CI-07 retain complete depth, interfaces, tools and required observations |
| Dependencies/non-goals | PASS — missing APIs assigned upstream; service work deferred; no duplicate runtime or blanket CAD/ERP expansion |
| Acceptance evidence | PASS — explicit encoder/profile, frame, passive/sensor, viewer, operator and operations gates |
| Source quality | PASS — exact local producer files identified; hardware leads retain their unqualified status |
| Completion claims | PASS — this source record does not create implementation, conformance or hardware results |

Verdict: **READY** to implement the named producer obligations and consumer
fixtures. Freeze each slice's schema, diagnostics and export mapping together;
their implementation is part of that work. Switching an existing boundary or
claiming integrated conformance is **NOT READY** until the real export and its
replay/migration/consumer tests pass. This gate is per profile and does not halt
independent native, core or instruction work.
