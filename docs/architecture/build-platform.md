# Visual Build Platform

**Status:** accepted specification; application implementation remains open
**Decision date:** 2026-09-24
**Scope:** companion website, physical configuration, research, and optional purchasing

This is the canonical replacement for the proposal introduced on `origin/build`
at `7527cb3`. The current product decisions below supersede that proposal's
mandatory lead assembler and single assembled-product seller assumptions.
The private visual plan is a presentation of these specifications, not a
separate source of requirements. No implementation duration is specified.

## Product and journey contract

Frameshift is the computer application and its companion services. Customers
choose manufacturer-branded components and their own assembly route. Frameshift
does not stock, manufacture, or sell a mandatory Frameshift-branded assembled
frame. Future manufacturer licensing of the name requires a separate decision.

**BP-01 — Independent configuration.** The website must provide a complete,
visual Paper, Photo, and Pixel configuration journey and a printable exact
shopping list before coordinated purchasing is built. Customers can use the
list to buy from any selected store without a Frameshift account, coordination
fee, payment integration, or participating supplier API. Unsupported purchasing
integrations do not exclude a component from exploration or planning output.

**BP-02 — Optional coordination.** The final milestone adds supplier-direct
dropshipping and purchasing coordination for an explicitly disclosed percentage
fee. Each supplier's goods contract and identity remain visible. The independent
journey remains fully available. [Commerce](build-commerce.md) specifies the
complete final milestone, including fulfillment and care.

**BP-03 — Local independence.** Library, artwork, generation choices, rendering,
pairing, playlists, and frame delivery continue without a shopping account or
commercial server. The website neither shares the local database nor gains
frame-control authority from a configuration link. Hardware qualification and
signed release evidence remain separate from completion of codeable work.

## Visual configurator and shopping list

**BP-04 — Interaction.** Provide live proportions and artwork preview, frame,
mat, finish, display, controller, power, mounting, and assembly choices. Support
component comparison, fit inspection, custom parts, and immediately explained
constraints. Use 2D or 3D where it helps inspect the setup; a 3D engine is not a
prerequisite for every page. Show the consequences for dimensions, appearance,
refresh, energy use, assembly demands, and price. Preview fidelity must be
explicit: a browser illustration is not measured color or physical fit proof.

The customer can save locally, reload, duplicate, compare, and export a
configuration without signing in. A server-saved or shared configuration is an
explicit optional operation with access and retention rules. Artwork stays in
the browser unless the customer explicitly requests an operation that uploads
it. Do not put private artwork or customer details into public share URLs.

**BP-05 — Complete independent output.** Print and portable structured export
must contain the BuildSpec identity and version, exact component/profile
revisions, quantities, manufacturer and supplier links, dimensions, compatibility
results, unresolved facts, source/evidence dates, required tools, assembly steps,
and installation/profile handoff. Printing must remain usable without color,
without clipped tables, and across multiple pages. Unknowns stay visible.
Instructions cannot turn an unqualified assembly into a safety claim.

Maintain a visible cost summary. Sourced indicative prices carry currency,
observation date, included/excluded costs, and stale/missing status; a partial
sum is labelled partial. A complete list must be exportable when price or stock
is unavailable. Guaranteed availability, landed quotes, tax calculation, and
supplier reservations belong to the final purchasing milestone. Disclose
optional affiliate links and allow independent buying elsewhere.

Keyboard, screen-reader, narrow-screen, loading, empty, invalid, offline/reconnect,
and source-unavailable paths are part of the journey. Selection, reload, export,
and import must round-trip through the same compiler. The offline guide and
saved planning output remain usable independently of checkout.

## Server and frontend architecture

**BP-06 — Selected stack.** Use Phoenix, Ash, AshPostgres, phoenix-assets, and
Svelte 5/SvelteKit, consistent with the other platforms. One Phoenix application
hosts the commercial domains and embeds the qualified Refpath runtime.

- Ash domains/resources own explicit actions, validations, policies, and
  database access through AshPostgres. Require actor context and authorization
  for browser, worker, administrative, and pack entry points alike.
- Phoenix owns sessions, HTTP commands/queries, boundary validation, and
  authenticated subscriptions. Customer and supplier isolation is enforced on
  the server; frontend hiding is not authorization.
- SvelteKit owns browser routes and interactive views. Use phoenix-assets'
  Vite/manifest integration and generated `$phoenix/*` contracts, including
  deliberately exposed Ash metadata. Exclude secret/internal fields. Do not
  maintain a second handwritten schema generator.
- Pure physical contracts remain independent of Ash, PostgreSQL, and Phoenix.
  Gleam's JavaScript output provides local feedback; server actions recompute
  accepted specifications against pinned inputs and current admission policy.
- Begin with commands, queries, and scoped PubSub. Electric/Phoenix.Sync needs
  a demonstrated synchronization requirement and separate decision. Do not
  assume the asset integration provides a fully qualified server-rendered
  Svelte application merely because it can serve a manifest or HTML.
- Frameshift owns product UI and domain behavior. Generic asset tooling belongs
  in phoenix-assets; generic orchestration belongs in Refpath.

**BP-07 — Domain ownership.** These are consistency/API boundaries, not a
requirement for separate applications, services, or one process per resource.

| Domain | Owns | First required milestone |
| --- | --- | --- |
| Catalog & Compatibility | Components, profiles, sources, evidence, compiled specs, eligibility and quarantine | C |
| Access & Policy | Actors, authorization, admission policy, retention and audit access | B, extended in F |
| Quotes & Mandates | Offers, accepted quote snapshots, seller terms, fee basis, consent and authority limits | F |
| Purchasing | Purchase group and separate supplier commitments | F |
| Payments & Fees | PSP references, accounting entries, reversals, disputes and reconciliation | F |
| Fulfillment & Care | Parcels, cases, cancellation, returns and safety actions | F |

Packs call typed domain commands; models and packs cannot write domain tables.
Refpath owns schedules, task/attempt identity, runtime authority, effects, and
recovery through its public contracts. A PostgreSQL transaction cannot make a
remote supplier purchase atomic. Domain truth and runtime effect truth have
distinct owners and reconcile through durable command/effect identities.

## Monorepo boundaries and migration

**BP-08 — Target ownership.** Establish dependency checks before directory moves.
The intended layout is:

```text
apps/
  macos/                 # current host/macos
  core/                  # current host/core; direct Exqlite/SQLite writer
  build-platform/        # Phoenix + Ash + embedded Refpath
    assets/              # Svelte 5/SvelteKit through phoenix-assets
  guide/                 # installation guide and offline lab
packages/
  build-spec/            # pure physical contracts and compiler
    verification/        # Frameshift Maude models and fixtures
  decision-kernel/       # current host/decision_kernel; Gleam BEAM/JS
packs/frameshift/        # domain workflows, rubrics and evals
data/physical/           # sourced immutable profile revisions
protocol/ renderer/ firmware/ simulator/ release/ docs/ scripts/
```

These are target paths, not claims that directories already exist. Add packages
only for actual reuse or authority boundaries. Preserve the existing local
single-writer SQLite contract; AshPostgres is the server persistence choice.
Neither app imports the other's private modules or accesses its tables. Shared
packages cannot depend on either application, a UI framework, or provider I/O.

Move one verified component with its scripts, CI, assets, packaging, generated
content, and documentation. Preserve public contracts and accepted identities
during refactoring. CI rejects forbidden imports and stale generated contracts;
each application builds independently. Commit boundary rules, context extraction,
and path migration in reviewable slices using repository Git conventions.

**BP-09 — Repository ownership.** All Frameshift workflows, physical models,
fixtures, rubrics, and evaluations live in this repository. Refpath is an
external dependency at an exact admitted revision, not a vendored fork or home
for Frameshift packs. The runtime loads the qualified pack revision. Upstream
generic improvements must expose a tested public contract before adoption.

## Operational architecture

**BP-10 — First-class observability.** Metrics, structured logs, immutable domain
audit, and bounded traces are required with each slice. Follow the
[diagnostics contract](diagnostics.md) for the computer app and the server
extensions there. macOS uses Console.app and `log`; no custom log UI is required.
Use standard server observability tools for metrics, alerts, traces, and logs.

Include Beamlens for read-only server investigation of runtime health, queues,
logs, and database behavior, with Frameshift observations for compatibility,
verification, research, and, in F, stalled purchasing/reconciliation. Explicitly
declare the production dependency and choose one supervision owner. If the host
starts Beamlens, disable Refpath's automatic instance. Refpath's optional
development/test dependency does not provide a production host integration.

Configure Beamlens' BAML client registry explicitly. Its inference path is
separate from Refpath's usual provider calls: apply investigation frequency,
concurrency, token, time, and spend ceilings at that boundary and account for
usage centrally. Prefer a qualified local provider; intent-model qualification
does not qualify diagnostic reasoning. Restrict observations to bounded,
redacted queries and authorized operators. Diagnostics cannot change catalog,
purchase, or payment state. Dependency failure or budget exhaustion must leave
ordinary logs, telemetry, alerts, and application actions available. Qualify the
exact library, native dependencies, skills, and measured runtime overhead.

## Adaptive milestones and completion evidence

**BP-11 — Required order.** Dependency permits parallel preparation, but the
independent shopping-list journey must be complete before the dropshipping
milestone begins. All transactional commerce implementation is in **F, the final
milestone**. Earlier Refpath work is nontransactional research and qualification.
This ordering must appear consistently in specs, task plans, and presentations.

| Milestone | Scope and dependencies | Required completion evidence |
| --- | --- | --- |
| A — Specifications | Reconcile the branch proposal with all accepted decisions | Canonical contracts, owner/acceptance mapping, aligned existing docs and plan artifact |
| B — Boundaries and web foundation | After A; dependency rules, Phoenix/Ash shell, assets, actor policies, Refpath host seam, diagnostics; verified component moves | Independent builds, packaging preserved, generated-contract checks, authorization and single-supervisor tests |
| C — Physical model | After A and package boundary; sourced profiles, BuildSpec, Gleam compatibility and targeted ExMaude verification | Deterministic bytes/hash, cross-runtime fixtures, three-class coverage, unknown/refusal tests, proof outcome and counterexample replay tests |
| D — Visual builder and printable shopping list | After C and required B surface; complete independent customer journey | Selection/save/reload/export parity, useful printed output, explicit missing facts/prices, keyboard/accessibility/responsive/offline/error acceptance; no account or purchasing dependency |
| E — Autonomous research and operational qualification | After B/C; research packs, source admission, bounded model evaluation and operational recovery; preparation can overlap D | Scheduled safe admission/quarantine, exact pack/runtime qualification, revocation/restart/reconciliation, provider outage and budget tests; no purchase/payment writes |
| F — Optional dropshipping, purchasing and care — FINAL | Starts after D and E are complete; supplier and PSP integrations, checkout, fees, purchasing, fulfillment and complete care | Every requirement in the commerce contract implemented and tested against deterministic provider simulators and available selected-provider sandboxes; no repeated purchase under uncertain outcomes |

The independent computer-app lane continues alongside B–E under the
[implementation plan](implementation-plan.md). It is not a milestone after F
and cannot be made dependent on commerce. Hardware measurement, legal/company
agreements, and release administration are separately tracked activation/evidence
work, not additional software milestones or reasons to omit code and tests.
Real transactions remain disabled until their actual operating gates pass.

## Requirement and specification map

| Plan area | Canonical owner | Software evidence |
| --- | --- | --- |
| Product, visual choice, two journeys, Ash/frontend, repository boundaries | This document, BP-01–BP-11 | Boundary, authorization, browser and export checks |
| Physical profiles, BuildSpec, evidence, compatibility, Gleam and Maude | [Physical build contract](physical-build-contract.md), PB-01–PB-09 | Schema/identity/parity, property, mutation, trace and invalidation checks |
| Frameshift packs, Refpath seams, research, intent/models and evaluation | [Build orchestration](build-orchestration.md), BO-01–BO-08 | Runtime conformance, source admission, task/effect fault tests and held-out evals |
| Suppliers, legal roles, percentage fees, mandates, orders and care | [Build commerce](build-commerce.md), BC-01–BC-10 | Final-milestone end-to-end and provider fault evidence |
| Metrics, native/server logs and Beamlens | [Diagnostics](diagnostics.md), BP-10 and BO-08 | Redaction, budgets, cardinality, outage and overhead checks |
| Research, dependency gaps, model benchmarks and cost/role assumptions | [Decision research](../research/build-platform-decisions.md) | Dated sources; distinguishes published claims from project measurements |
| Current implementation status | [Verification ledger](verification.md) | Evidence remains missing until the named checks exist and pass |

New implementation commits must update the corresponding evidence rows. A spec
commit does not close an implementation or external validation gate.
