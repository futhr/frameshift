# Final-Product Completion Plan

**Status:** required product work, ordered only by dependency and evidence

This plan decomposes the complete product definition. Builders can start with
Paper, Photo, Pixel, the Mac app, or a protocol implementation. The seams below
keep those choices interoperable. Track completion of all codeable requirements
and software tests separately from release administration, company agreements
and physical measurements. Those external gates constrain activation and claims;
they do not excuse unfinished software or become later software milestones.

## Companion platform milestone order

The full requirements, owners and acceptance criteria are in the
[canonical build-platform plan](build-platform.md) and its physical,
orchestration and commerce contracts. That plan supersedes the earlier build
branch proposal's assembled-product seller assumptions.

| Milestone | Required outcome | Dependency |
| --- | --- | --- |
| A | Aligned specifications and evidence map | Accepted product decisions |
| B | Monorepo/domain boundaries, Phoenix/Ash/phoenix-assets/Svelte 5 foundation, Refpath host seam and Beamlens diagnostics | A |
| C | Sourced profiles, immutable BuildSpec, Gleam compatibility and targeted ExMaude verification | A and package boundary |
| D | Complete visual configurator and printable independent shopping list, save/export, assembly and installation handoff | C and required B surface |
| E | Autonomous nontransactional research, model evaluation, admission and operational qualification | B/C; preparation may overlap D |
| F — FINAL | Optional dropshipping coordination: supplier/PSP adapters, checkout, percentage fees, purchasing, fulfillment, returns/refunds and care | D and E complete |

The shopping list cannot depend on an account, live checkout, guaranteed quote,
supplier purchasing API, or the final milestone. All transactional commerce
implementation belongs to F, including purchasing/refund/cancellation pack and
adapter work. Earlier Refpath integration supplies research and common runtime
qualification. Milestones have dependency/acceptance gates, not time estimates.

The host, protocol, receiver and simulator work below is the parallel independent
computer-product lane, not another milestone after F. Native frame operation
must remain independent of commercial server availability. Update the
[verification ledger](verification.md) with bounded evidence per completed slice.

## Shared contracts

These artifacts reduce rework across every track:

1. canonical master, recipe, artifact, frame-state, and playlist data models;
2. Frame Protocol v0.1 schemas and conformance fixtures;
3. a simulated frame with selectable capabilities and injected failures;
4. a versioned Frame Thing Model, Host Outbox Thing Model, namespaced
   vocabulary, binding profiles, and conformance claims;
5. golden source/preview/artifact fixtures for each display profile;
6. repository-wide build, format, test, and license checks; no project-owned
   Python code, with pinned upstream build tools isolated and recorded;
7. decision/evidence records for every dependency and exact hardware revision.

The simulator can be an Elixir application on macOS and need not imply Nerves
or Linux hardware inside a frame.

## Host track

### H1 — Library core

- OTP application and supervision tree;
- portable domain boundaries and platform adapter contracts from
  [Portable Host Core](host-core.md);
- content-addressed store and direct Exqlite/SQLite metadata migrations under
  D-010, with consistent backup, object manifest, restore checks, and FTS5
  search as specified in the [persistence review](../research/embedded-persistence.md);
- import, pin, recoverable remove, labels, and search;
- immutable recipe/variant relationships;
- single-writer transactions, replay receipts, atomic audit writes, and
  read-only paginated diagnostics through authenticated local IPC;
- named telemetry events, bounded persistent metric rollups, native macOS
  unified logging and Linux logging adapters, and a diagnostic CLI;
- test-only CLI or local harness.

**Exit:** crash and restart preserve committed masters; identical recipes reuse
cache; removal cannot collect referenced/pinned content; Mac and Linux/Pi host
contract tests preserve the same domain and protocol behavior. A failed update
is reconstructable from command through display confirmation or pending state
without opening the UI or exposing secrets. Metric and log storage bounds are
measured on both host platforms. Backup/restore reproduces protected references
and rejects corrupt or missing objects before activation.

### H1a — Shared decision kernel and guide

- extract only pure capability admission, profile selection, state labels,
  and simulation transitions into Gleam;
- compile the same source to Erlang for the host and JavaScript for the public
  guide on the pinned OTP 29/Elixir 1.20.4/Gleam 1.18.1 toolchain, with cross-target
  fixtures, integer bounds, and generated cases;
- turn the desktop HTML draft into the static interactive installation guide
  at `frameshift.wotex.io`; present simulated profiles and failures honestly;
- hand non-secret setup choices to the native app after installation, with
  pairing and delivery still performed by the installed host.

**Exit:** BEAM/JavaScript decisions agree for valid and adversarial inputs;
the guide works without an account or hosted code execution; no browser
simulation is described as physical display evidence. See
[installation and guide](install-and-guide.md).

### H2 — Deterministic renderer

- supervised Zig executable and framed protocol;
- crop/scale/color foundation;
- Paper palette/dither, Photo raster, and Pixel static-raster profiles as each
  selected hardware track supplies evidence;
- golden fixtures and target previews.

**Exit:** deterministic byte-for-byte results, bounded malformed inputs, clean
worker crash/timeout recovery, and no in-process native crash surface.

### H3 — Native shell

- SwiftUI `MenuBarExtra` window;
- menu-bar agent with no launch window or Dock entry, using the selected
  perspective-frame mark on a transparent Finder icon field, monochrome
  menu-bar icon, and compact branded dropdown header with an accessible Quit
  control;
- native translucent dropdown backdrop and a bounded scrolling artwork list;
- target selection, instruction/import, library search, result cards;
- regenerate, pin, remove, queue/send, and concise status;
- Keychain, Vision labels/feature prints, notifications, accessibility;
- Settings and `SMAppService` opt-in background lifecycle.

**Exit:** menu-bar acceptance scenarios pass with keyboard/VoiceOver and with no
AI provider configured.

### H4 — AI adapters

- provider contract and preflight;
- local MediaGenerationKit candidate;
- experimental Ollama adapter that proves a real generation before enabling;
- Draw Things+ cloud and optional Gemini API behind explicit cost/privacy
  disclosure;
- recipe/cache/provenance and cancellation.

**Exit:** local-only mode emits no provider traffic; no automatic cloud switch;
cached repeat avoids provider call; secrets remain in Keychain.

### H5 — Qualified render and transfer generations

- define versioned renderer and connector operation descriptors, a reusable
  qualification manifest, an asset-specific work manifest, and an immutable
  result binding exact wire bytes;
- attest the renderer build and canonical selected frame profile, then qualify
  candidate combinations against software fixtures and measured frame cohorts;
- persist candidate, evidence, admission, and active cohort selection under
  the single writer; preserve legacy pending work without retroactive claims;
- pin accepted render work and push/pull intents to exact work and qualification digests across
  restart, candidate activation, rollback, and reconciliation;
- add bounded diagnostic coverage and adversarial tests for incompatibility,
  exact replay, uncertain effects, duplicate transfer, and last-good retention.

**Exit:** a new job cannot use an incompatible or unadmitted combination;
accepted work and last-good bytes survive a cohort switch and restart; physical
display success still requires authoritative frame evidence. See
[qualified generations](qualified-generations.md).

## Protocol track

### P1 — Schemas and simulator

- Frame and Host Outbox Thing Models plus vendor-independent TD examples;
- extension-preserving bounded W3C TD/TM admission and deterministic Form
  selection;
- state, desired, playlist, outbox manifest/ack, and problem schemas;
- digest-addressed fake storage;
- a separate Docker-managed frame receiver for the default Paper, Photo, and
  Pixel manufacturer candidates, contacting the host over real mutual TLS;
- fault injection for slow refresh, sleeping contact, bad digest, full storage,
  power-loss checkpoints, and version skew.

### P2 — Security prototype

- physical pair-mode abstraction and QR/bootstrap flow;
- pinned server identity and mutual TLS;
- host Keychain/client identity;
- authorization, reset, redacted diagnostics;
- independent review before production claims.

### P3 — Conformance suite

- semantic, runtime, binding, live-transport, firmware, and hardware evidence
  profiles whose claims cannot substitute for one another;
- direct push and sleeping pull across advertised Forms rather than assumed
  vendor endpoints;
- idempotence/preconditions;
- parser and allocation bounds;
- atomic storage/state recovery;
- still-only negative cases.

**Exit:** all protocol compliance tests pass against the simulator and at least
one real selected hardware track.

## Hardware tracks

### Paper track

Qualify one exact small color e-paper/driver assembly, build a sleeping
controller spike, implement exact packing/refresh, then measure the
complete energy and depth cycle. A large-format Paper path is independent and
does not block the smaller reference.

### Photo track

Choose either donor or raw-panel prototype, verify exact panel/controller,
implement boot-to-retained-still behavior, then measure optical quality, power,
heat, depth, and mount/cable options. Do not design a custom high-resolution
controller before the prototype identifies the actual interface risk.

### Pixel track

Prove one exact module with a timed-parallel/DMA driver, mapping, refresh,
and hardware power limit. Scaling to the chosen module count is a recommended
risk-reduction step, not a requirement on how a contributor starts. Full-array
power and thermals remain a separate reference exit gate.

No track is required before another, and no contributor must build all three.

## Evidence and release gates

Development snapshots may contain only some components, but they are never a
different product scope. The verification ledger marks each bounded claim as
missing, partial, or proven and names its evidence profile.

A releasable software build requires the installed end-to-end flow, compatible
protocol bindings, authenticated lifecycle, migration/recovery, accessibility,
signing, hardened runtime, notarization, dependency/license inventory, and
security review appropriate to its claim.

## Distribution and platform gates

Mac distribution uses one signed, notarized DMG for direct download, Homebrew
Cask, and Sparkle updates. Ubuntu amd64/arm64 and Pi 5 Ubuntu Server arm64 use
target-specific packages authenticated by a signed release manifest or APT
repository and the same host contracts. A dedicated Nerves Pi 5 image is a
separately qualified bridge/appliance. The static public guide
links only to real, digest-verified release artifacts. See
[installation and guide](install-and-guide.md) and [Linux host](../host/linux.md).

The distribution work has this dependency order:

1. Freeze the release manifest, supported OS/CPU matrix, signing identities,
   package names, and external artifact channel without changing source-repo
   visibility.
2. Qualify SQLite/object backup and restore, native logging/metric ceilings,
   and the Mac signed/notarized installed lifecycle.
3. Prove the Gleam kernel on the pinned OTP 29 release and JavaScript target;
   build and accessibility-test the static guide against its exact fixtures.
4. Publish the release artifact only after direct Mac, Cask, and Sparkle paths
   pass the same artifact identity and upgrade tests and the product's
   applicable end-to-end and hardware claims have evidence; make guide
   download links manifest-driven.
5. Port the same core to Ubuntu amd64/arm64, then qualify Pi 5 Ubuntu storage,
   power, and service behavior; publish each package only after its own gates.
6. Build the separately signed Nerves Pi 5 appliance image and test firmware
   validation/revert, credential provisioning, persistent state, and logs.

Hardware tracks can proceed independently. A guide simulation or platform
package does not certify a frame assembly.

A released hardware profile additionally requires one exact assembly with a
reproducible build record, signed rollback-capable firmware, protocol
conformance, interrupted-update recovery, and measured electrical, power,
thermal, optical, depth, mounting, and service evidence.

Calling a hardware revision “reference” does not constitute consumer
certification or permission to conceal mains wiring. Commercialization still
requires the applicable independent regulatory, battery, EMC/radio, thermal,
mechanical, manufacturing, and safety work.
