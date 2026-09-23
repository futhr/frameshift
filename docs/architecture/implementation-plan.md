# Final-Product Completion Plan

**Status:** required product work, ordered only by dependency and evidence

This plan decomposes the complete product definition. It does not define an
MVP, demo, or smaller shipping target. Builders can start with Paper, Photo,
Pixel, the Mac app, or a protocol implementation. The seams below keep those
choices interoperable. Work remains incomplete until the product completion
contract and the applicable release gates pass.

## Shared contracts

These artifacts reduce rework across every track:

1. canonical master, recipe, artifact, frame-state, and playlist data models;
2. Frame Protocol v0.1 schemas and conformance fixtures;
3. a simulated frame with selectable capabilities and injected failures;
4. a versioned Frame Thing Model, Host Outbox Thing Model, namespaced
   vocabulary, binding profiles, and conformance claims;
5. golden source/preview/artifact fixtures for each display profile;
6. repository-wide build, format, test, and license checks with no Python;
7. decision/evidence records for every dependency and exact hardware revision.

The simulator can be an Elixir application on macOS and need not imply Nerves
or Linux hardware inside a frame.

## Host track

### H1 — Library core

- OTP application and supervision tree;
- portable domain boundaries and platform adapter contracts from
  [Portable Host Core](host-core.md);
- content-addressed store and direct Exqlite/SQLite metadata migrations under
  D-010; measure Ecto as a candidate before changing the persistence boundary;
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
measured on both host platforms.

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

## Protocol track

### P1 — Schemas and simulator

- Frame and Host Outbox Thing Models plus vendor-independent TD examples;
- extension-preserving bounded W3C TD/TM admission and deterministic Form
  selection;
- state, desired, playlist, outbox manifest/ack, and problem schemas;
- digest-addressed fake storage;
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

Qualify one exact small color e-paper/driver assembly, build the Zig-oriented
sleeping controller spike, implement exact packing/refresh, then measure the
complete energy and depth cycle. A large-format Paper path is independent and
does not block the smaller reference.

### Photo track

Choose either donor or raw-panel prototype, verify exact panel/controller,
implement boot-to-retained-still behavior, then measure optical quality, power,
heat, depth, and mount/cable options. Do not design a custom high-resolution
controller before the prototype identifies the actual interface risk.

### Pixel track

Prove one exact module with a Zig timed-parallel/DMA driver, mapping, refresh,
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

A released hardware profile additionally requires one exact assembly with a
reproducible build record, signed rollback-capable firmware, protocol
conformance, interrupted-update recovery, and measured electrical, power,
thermal, optical, depth, mounting, and service evidence.

Calling a hardware revision “reference” does not constitute consumer
certification or permission to conceal mains wiring. Commercialization still
requires the applicable independent regulatory, battery, EMC/radio, thermal,
mechanical, manufacturing, and safety work.
