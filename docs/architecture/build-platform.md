# Visual Build Platform

**Status:** specification baseline; application implementation remains open
**Revision date:** 2026-09-25
**Scope:** companion website, physical configuration, instructions, research and optional external-service integration

This is the canonical successor to the original `origin/build` proposal at `7527cb3` and the 2026-09-24 baseline. The private visual plan is a presentation of these technical contracts, not an independent source of requirements. No implementation duration is specified. Company strategy, monetization and legal interpretations are outside this repository.

## Product and journey contract

Frameshift remains a complete local application with an independent visual build guide. Conjunct is the proposed generic physical-product engine; Frameshift retains its specific product semantics and consumes qualified producer contracts. See [Conjunct adoption](../research/conjunct-adoption.md). Thinness concerns the complete installed composition, with no arbitrary global display-size limit or rear-mounted Pi/mini-PC workaround.

**BP-01 — Independent configuration.** Provide the complete visual Paper, Photo and Pixel journey and printable exact shopping list before coordinated purchasing is implemented. Users can obtain a complete list without an account, payment integration, model provider or participating supplier API. Unsupported purchasing integrations do not exclude a component from exploration or planning output.

**BP-02 — Optional coordination.** The final milestone adds admitted external-service capabilities: provider handoff, quotes, purchasing and the relevant fulfillment/care paths. Selected capabilities, counterparties, terms and authority come from explicit approved inputs rather than a hardcoded company operating model. No mandatory assembler or single seller hierarchy is encoded. The [service integration contract](build-commerce.md) specifies implementation and evidence; the independent journey remains available.

**BP-03 — Local independence.** Library, artwork, generation choices, rendering, pairing, playlists and frame delivery continue without a shopping account or platform server. The website neither shares the local database nor gains frame-control authority from a configuration link. Physical qualification, source permissions and signed release evidence remain distinct from completion of codeable work.

## Visual configurator and shopping list

**BP-04 — Interaction.** Provide live proportions and artwork preview, frame, mat, finish, display, controller, power, mounting and assembly choices. Support comparison, fit inspection, custom parts and explained constraints. Use 2D or 3D where it helps; a 3D engine is not required for every page. Show dimensional, appearance, refresh, energy, assembly and sourced indicative-price consequences. A browser illustration is not measured colour or physical-fit proof.

Users can save locally, reload, duplicate, compare and export without signing in. Server-saving/sharing is an explicit optional operation with access and retention rules. Artwork stays in the browser unless the user requests an upload operation. Public share URLs contain no private artwork or customer details.

**BP-05 — Complete independent output.** Print and portable export contain exact BuildSpec identity/version, component/profile revisions, quantities, manufacturer/source links, dimensions, compatibility outcomes, unknowns, evidence dates, tools, assembly steps and installation/profile handoff. Printing remains usable without colour, clipping or missing multi-page content. Instructions cannot turn unqualified hardware into a safety claim.

Where indicative component prices are available, retain currency, observation date, inclusions/exclusions and stale/missing status. Label partial sums as partial. Missing price/stock cannot block a complete list. Binding amounts, live availability, taxes and reservations belong to final-stage provider integration. Required link/disclosure labels are supplied by the admitted policy, not inferred from the page template.

Keyboard, screen-reader, narrow-screen, loading, empty, invalid, offline/reconnect and source-unavailable paths are required. Selection, save/reload, import and export use the same compiler semantics. The offline guide is independent of checkout. Geometry/procedure references and explanatory documentation bind to exact revisions.

## Server and frontend architecture

**BP-06 — Selected stack.** Use Phoenix, Ash, AshPostgres, phoenix-assets and Svelte 5/SvelteKit. One Phoenix product host embeds the qualified runtime and reusable domain integrations; package boundaries do not require separate services.

- Ash owns explicit actions, validation, policies and server storage. Enforce actor/operator scope for browser, worker, administrative and pack entry points.
- Phoenix owns sessions, HTTP commands/queries, boundary validation and authenticated subscriptions. Frontend visibility is not authorization.
- SvelteKit owns browser views through phoenix-assets' Vite/manifest and generated `$phoenix/*` contracts. Expose Ash metadata deliberately; exclude secrets/internal fields and avoid a second schema generator.
- Pure physical contracts are independent of Phoenix, Ash and PostgreSQL. Qualified Gleam JavaScript output gives local feedback; accepted server records are recomputed against pinned inputs and current admission.
- Begin with commands, queries and scoped PubSub. Electric/Phoenix.Sync requires a demonstrated need. Asset serving alone is not proof of a qualified server-rendered Svelte application.
- Conjunct supplies generic physical/procedure/viewer semantics; Frameshift supplies its product profile and UI. Refpath retains generic application-generation, UI-graph, work and effect semantics. DocShell supplies versioned explanatory content. Rivure owns financial operations.

**BP-07 — Domain ownership.** These are consistency/API boundaries, not a process-per-resource plan.

| Domain | Owns | First milestone |
| --- | --- | --- |
| Catalog & Compatibility | Product profiles, permitted sources/evidence, compiled specs, current eligibility and quarantine | C |
| Access & Policy | Actors, authorization, external decision references, retention and audit access | B, extended F |
| Quotes & Mandates | Product/offer snapshots, accepted terms, consent and bounded authority references | F |
| Service Commitments | Coordination groups, independent provider commitments and physical acceptance | F |
| Financial Integration | Rivure command/result references and product-event mapping, not a competing ledger/provider engine | F |
| Fulfillment & Care | Parcels, production/QC evidence, cases, cancellation, returns and safety actions | F |

Packs call typed commands; they cannot write domain tables. Refpath owns schedules, attempts, runtime authority, effects and recovery. Rivure owns financial truth. A PostgreSQL transaction cannot make remote provider actions atomic. Preserve distinct domain, financial and execution identities and reconcile through supported interfaces.

## Monorepo boundaries and migration

**BP-08 — Target ownership.** Establish dependency checks before directory moves. The current paths and unpushed tree must be reconciled first. Intended product layout:

```text
apps/
  macos/                       # current host/macos
  core/                        # current host/core; direct Exqlite/SQLite writer
  build-platform/              # Phoenix/Ash and admitted producer integrations
    assets/                    # Svelte 5/SvelteKit through phoenix-assets
  guide/                       # independent guide and offline laboratory
packages/
  frameshift-domain/           # frame-specific profile/commands and verification
  decision-kernel/             # remaining product-specific Gleam BEAM/JS decisions
product/
  bundle/
  profiles/{paper,photo,pixel}/
  procedures/
  packaging/
  presentation/
  examples/                    # synthetic operator bindings
packs/frameshift/              # domain workflows, rubrics and evals
data/physical/                 # sourced immutable profile revisions
protocol/ renderer/ firmware/ simulator/ release/ docs/ scripts/
```

The earlier `packages/build-spec/` location remains a transitional physical-contract owner until the qualified extraction/migration completes. Move only generic semantics to Conjunct; preserve product-specific rules and evidence here. Do not create duplicate authoritative encoders. The existing artwork renderer is separate from the assembly viewer.

These are target paths, not directories claimed to exist. Preserve the local single-writer SQLite contract and server AshPostgres boundary. Neither application accesses the other's private modules/tables. Pure shared packages cannot import product hosts, frameworks or provider I/O.

Move one verified component with scripts, CI, assets, packaging, generated content and documentation. Preserve accepted IDs and define migrations when semantics change. Each application builds independently; CI rejects forbidden imports and stale generated contracts. No vendored producer fork or floating sibling worktree is an admitted dependency.

**BP-09 — Repository ownership.** Frame-specific workflows, profiles, formal models, fixtures, rubrics and evaluations stay here. Conjunct, Refpath, Wotex, Rivure, DocShell and other producer integrations use exact qualified revisions and supported exports. Generic improvements belong upstream and require consumer conformance before adoption.

Product bundle, physical BuildSpec, application generation and quote/commitment remain separate identities. Mutable offers, credentials, current provider health and customer data are not portable product/application artifacts. A producer's private or unreleased source is an explicit public-distribution gap, not permission to publish it or rebuild it locally.

## Operational architecture

**BP-10 — First-class observability.** Metrics, structured logs, immutable audit and bounded traces accompany each slice. Follow [diagnostics](diagnostics.md). macOS uses Console.app and `log`; no custom diagnostic UI is needed. The operated server uses the selected GreptimeDB/structured-observability path without ELK, with exact-version qualification. Heavy geometry and model workers have bounded resources and cannot starve domain/reconciliation work.

Include Beamlens for read-only authorized investigation of runtime health, queues, logs, storage, compatibility, research and stalled service work. Declare the production dependency and select one supervision owner; disable any duplicate automatic instance. An optional upstream development dependency is not a qualified production integration.

Configure its BAML registry explicitly. Apply bounded frequency, concurrency, context, time and centrally supplied execution budgets at that actual inference boundary. Intent-model qualification does not qualify diagnostics. Redact and scope observations. Diagnostics cannot mutate product, commitment or financial state. Failure/budget exhaustion leaves ordinary logging, metrics, alerts and commands available.

## Milestones and evidence

**BP-11 — Required order.** Complete the independent shopping-list journey before transactional integration begins. All purchasing/service transactions remain in **F, the final milestone**. Earlier runtime work is nontransactional research and qualification. Generic dependency work may proceed in parallel without bypassing this product journey.

| Milestone | Scope/dependencies | Required evidence |
| --- | --- | --- |
| A — Specifications | Reconcile accepted product decisions and Conjunct ownership | Canonical requirements, owner/API/evidence mapping and aligned docs |
| B — Boundaries and web foundation | After A; host, assets, authorization, runtime seam, diagnostics and verified moves | Independent builds, packaging preserved, generated-contract and single-supervisor checks |
| C — Physical model | After A and package boundary; sourced profiles, canonical BuildSpec, Gleam and targeted formal checks | Deterministic bytes/hash, cross-runtime fixtures, three-class coverage, unknown/refusal and counterexample replay |
| D — Visual builder and printable list | After C and relevant B surfaces | Complete selection/save/reload/export, correct instruction/geometry references, accessible print/offline/error paths, no account/purchasing dependency |
| E — Research and operational qualification | After B/C; may overlap D | Safe source admission/quarantine, exact producer/pack qualification, revocation/restart/reconciliation and provider-outage/resource tests; no purchase/payment writes |
| F — Optional service, purchasing and care — FINAL | After D and E | Full BC-01–BC-10 implementation and provider simulations/available sandboxes, no repeated effect under uncertain outcomes |

The independent computer-app lane continues alongside B–E under the [implementation plan](implementation-plan.md); it is not dependent on F. Hardware/source measurements, external permissions/admissions, credentials and release administration remain separate evidence gates, not excuses to omit implementable code or tests. Real effects stay disabled until the relevant profile is admitted.

## Requirement map

| Area | Canonical owner | Evidence |
| --- | --- | --- |
| Product, two journeys, host and boundaries | BP-01–BP-11 | Boundary, authorization, browser and export checks |
| Frame physical profile and deterministic decisions | [Physical contract](physical-build-contract.md), PB-01–PB-09 | Schema/identity/parity, property, mutation and invalidation tests |
| Product packs and runtime research seams | [Build orchestration](build-orchestration.md), BO-01–BO-08 | Producer conformance, source/effect faults and held-out evaluation |
| Optional commitments and care | [Service integration](build-commerce.md), BC-01–BC-10 | End-to-end and provider-failure evidence |
| Diagnostics | [Diagnostics](diagnostics.md), BP-10/BO-08 | Redaction, ceilings, cardinality, outage and overhead |
| Technical decisions and extraction | [Decision research](../research/build-platform-decisions.md), [Conjunct adoption](../research/conjunct-adoption.md) | Dated sources, explicit gaps, no claimed implementation from prose |
| Hardware/geometry leads | [Thin compositions](../research/thin-composition-evidence.md) | Exact source/revision and physical measurement gates |
| Implementation status | [Verification ledger](verification.md) | Missing evidence remains open |

Implementation changes update corresponding evidence rows. A specification commit closes neither implementation nor external validation gates.
