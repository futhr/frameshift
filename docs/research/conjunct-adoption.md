# Conjunct adoption and modular Frameshift structure

**Date:** 2026-09-25. **Status:** technical research and proposed extraction plan; no implementation or physical qualification claimed.
**Inspected Frameshift baseline:** `e60f207b0104ff08f765fca7f3d52839c7fe971e`.

## Scope and decision

Frameshift remains an independently useful digital-art-frame application and visual build guide. Conjunct supplies a generic physical-product composition specification and reference domain engine. Frameshift consumes it through an exact product profile/bundle; it does not become the universal engine or a disposable example.

This repository owns code, product structure, technical integration, physical evidence, documentation and tests. Company strategy, pricing choices, monetization, prospective commercial partnerships, operating-model economics and legal interpretation are outside this corpus. Optional service integration is an implementation contract, not a selected business model.

The initial Conjunct specification is at `futhr/conjunct/docs/`, CJ.01–CJ.08. It is a draft producer contract, not an installed SDK. Its current source location/visibility and eventual publication are producer decisions. Before using it, qualify exact exports and consumer tests; do not invent a local replacement for an unavailable generic producer.

## Product invariants to preserve

The defining physical constraint is the thinness of the complete installed composition. There is no arbitrary diagonal, format or universal size ceiling. A supported profile may declare actual measured limits; those are qualified capability bounds rather than a global product-size policy. A raw panel plus a rear-mounted Raspberry Pi/mini-PC bulge is not the concept.

Paper, Photo and Pixel are product families, not fixed vendor SKUs. Still-image generation/rendering remains on the host where specified. Photo and Pixel may require continuous scanning even when the artwork is static. Device firmware must implement the actual qualified interface, durable asset/state behavior, authentication and recovery; a profile cannot make arbitrary hardware work.

The native library, artwork, rendering, pairing, playlists and display operation remain usable without the web platform, a shopping account, Refpath model availability or a payment integration. A shared BuildSpec URL or manufacturer product pack grants no frame-control authority. Preserve the local single-writer SQLite boundary and existing device-admission flow.

The independent builder must save/reload/export locally, show exact component revisions and unknowns, and produce a complete printable shopping list and instructions. Unsupported stores or unavailable live stock do not prevent exploration or export. Optional external actions remain the final milestone, not a dependency for the guide.

## Ownership and dependency direction

| Owner | Responsibility consumed here |
| --- | --- |
| Conjunct | Generic component/composition identity, constraints, geometry/procedure/packaging semantics and reusable viewer/host seams |
| Frameshift | Thin-frame profiles, Paper/Photo/Pixel constraints, display/artwork behavior, frame procedures, product UI and qualification |
| Wotex | WoT descriptions, interaction and protocol bindings; no shopping or physical-BOM logic in the Frame Protocol |
| Refpath | Inference, research, capability/solution contracts, approved UI graphs, generations, attempts, effects and recovery |
| Rivure | Existing financial operations, provider accounts, fees, reversals and settlement references |
| DocShell | Versioned explanatory/documentation artifacts used by guide and interactive views |
| ExMaude | Generic bounded search/session/completion interface; Frameshift retains its own formal models |
| phoenix-assets | Shared asset and generated host-contract integration, not a parallel Frameshift schema generator |
| External policy owner | Scoped approved operational decisions; the product only validates and consumes their references |

Do not put private upstream research or corporate data into public fixtures. Do not access another application's private tables or copy its provider code. A generic producer defect is fixed upstream with a consumer reproduction. Actual producer availability is determined by exports and conformance, not by finding a specification file.

## Three distinct compositions

1. The **product bundle** pins Frameshift profile definitions, procedure templates, rule implementations, presentation and documentation.
2. A **physical composition/BuildSpec** pins exact chosen parts, revisions, quantities, placements, interfaces and physical semantics.
3. An **application generation** binds the approved product bundle to workflow/UI/runtime capabilities and operator authority through Refpath.

Offer, quote, order and current eligibility are separate mutable/versioned records. Changing the application layout must not rewrite an accepted BuildSpec. Changing a part requires a successor composition and affected instruction/qualification review. A new source assessment may revoke future use without modifying the historical physical identity.

Frameshift BuildSpec should become a named profile of Conjunct CompositionSpec. Establish an explicit identity/version migration before replacing any existing encoder. Do not reuse an old hash with different semantics, or add live prices, clock values or current policy to physical identity. Preserve `compatible`, `incompatible` and `unknown` outputs with exact source/rule references.

## Target repository structure

The existing root still contains `host/` and `guide/`. This target is not a claim that directories already exist:

```text
apps/
  macos/                       # current host/macos
  core/                        # current local core; SQLite ownership unchanged
  build-platform/              # Phoenix/Ash host and Svelte assets
  guide/                       # independent guide/offline laboratory
packages/
  frameshift-domain/           # product-specific commands and physical profile
  decision-kernel/             # remaining product-specific pure Gleam decisions
product/
  bundle/
  profiles/{paper,photo,pixel}/
  procedures/
  packaging/
  presentation/
  examples/                    # synthetic operator bindings only
packs/frameshift/               # domain research/workflows/rubrics/evals
data/physical/                 # permitted immutable source/profile revisions
protocol/ renderer/ firmware/ simulator/ release/ docs/ scripts/
```

Generic `packages/build-spec/` semantics are candidates for extraction into Conjunct, not wholesale relocation of all product decisions. Keep source/evidence ownership explicit during transition. Never leave two authoritative implementations of the same compiler or generated schema.

The current Zig artwork raster renderer and the new assembly/3D instruction viewer are different systems. Instruction animation does not introduce video or animation into the frame's still-image protocol. No new CAD viewer should be hidden under the artwork renderer simply because both draw pixels.

## Selected host integration

Keep Phoenix, Ash, AshPostgres, phoenix-assets and Svelte 5/SvelteKit as the existing selected reference stack. Do not revert to the earlier speculative Next.js/LiveView split. Ash commands enforce actor/operator scope and policy for all entry points. Browser feedback uses qualified pure Gleam/JavaScript decisions; accepted server records are recomputed from pinned inputs.

Conjunct's reusable viewer projects semantic part/feature/step IDs. Refpath's existing UI graph arranges approved viewer, inspector, explanation and task components. DocShell supplies exact-revision explanatory content. Geometry meaning, procedural meaning, documentation and application presentation do not become competing sources of truth.

Use commands, queries and scoped PubSub initially. Synchronization frameworks need a demonstrated requirement. Neither phoenix-assets nor a passing asset build proves a fully qualified Svelte server-rendering or authorization boundary.

## Product and operator bundles

An independent guide profile can run without transactional or AI capabilities. A technical component explorer, assembly intake or installation/care profile may expose additional admitted commands. They are capability combinations, not copied web applications and not a permanent seller/assembler hierarchy.

One operator need not have one source repository or one server. Its runtime scope owns private data, credentials, current offers and authority. Portable product bundles contain no customer data, bank instructions, production tokens or negotiated private terms. New executable operations follow source/build/qualification review; a model cannot invent and activate them in production.

## Extraction and migration plan

| Slice | Change | Proof required before proceeding |
| --- | --- | --- |
| 1 | Reconcile current and unpushed tree; map existing BuildSpec/Gleam ownership | Exact path/API map, source pins and retained tests |
| 2 | Define product profile and generic Conjunct wire semantics | Canonical identity, unknown/overflow/refusal and compatibility fixtures |
| 3 | Extract one generic compiler path without directory-wide churn | Old/new output parity and explicit migration for changed semantics |
| 4 | Use Conjunct geometry/procedure viewer with one exact frame fixture | Source-to-feature/step references, complete depth and accessible print/offline output |
| 5 | Run a passive non-frame consumer upstream | No Frame/Paper/Photo/Pixel imports in generic packages |
| 6 | Bind two operator surfaces through actual Refpath exports | Scoped admission, unavailable-capability refusal, restart/successor tests |
| 7 | Qualify optional service/financial producer integrations | Existing Rivure and Refpath identities, simulations, safe unknown-outcome reconciliation |

Do not freeze the native product while the generic engine evolves. Keep a usable narrower deterministic profile when an adaptive producer seam remains unavailable. No migration may silently discard user data, accepted specifications, test fixtures or release/package paths.

## Producer conformance obligations

Refpath: map SY.33, DF.35, DF.36, RT.35, RT.61/62, RT.68, RT.77 and applicable review/admission owners to actual exported APIs and shipped consumer suites. Do not create another registry, current-generation pointer or effect journal. Durable VM-restart admission and pending external effects need joined tests, not merely a hot-reload demonstration.

Rivure: current PM.11 already includes Accounts v1 Connect operations. Integrate those through the financial host boundary and extend only demonstrated generic gaps. Account capability, charge, transfer, payout, refund and commission are distinct records. Financial events do not prove supplier acceptance or completed physical work.

ExMaude: qualify typed counterexample, bounded-no-counterexample, finite-exhaustion and inconclusive outcomes. Empty output is not proof. Replay witnesses in the actual compiler and test deliberately corrupted rules. Heavy verification stays outside ordinary preview latency.

DocShell: bind collection/source revision and procedure explanation to stable product references. The host owns rendering/access. Generic artifact API gaps belong upstream; no need for a separate documentation data engine.

## Technical research carried forward

The [thin-composition evidence matrix](thin-composition-evidence.md) retains panel/module leads, full-stack architecture hypotheses and geometry gaps. The [decision research](build-platform-decisions.md) retains stack, producer pins and model-qualification boundaries. The [physical contract](../architecture/physical-build-contract.md) remains the current product-specific acceptance contract until an explicit compatible Conjunct profile migration is adopted.

No commercial demand, partner financing, country authorization or price is inferred from these technical results. No hardware measurements, live effects or runtime tests were executed by this documentation work.
