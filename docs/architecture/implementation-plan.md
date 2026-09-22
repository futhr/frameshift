# Implementation Plan

**Status:** recommended work breakdown, not a mandatory build order

Builders can start with Paper, Photo, Pixel, the Mac app, or a protocol
implementation. The seams below keep those choices interoperable. A track
becomes a reference only after its own exit criteria pass.

## Shared contracts

These artifacts reduce rework across every track:

1. canonical master, recipe, artifact, frame-state, and playlist data models;
2. Frame Protocol v0.1 schemas and conformance fixtures;
3. a simulated frame with selectable capabilities and injected failures;
4. golden source/preview/artifact fixtures for each display profile;
5. repository-wide build, format, test, and license checks with no Python;
6. decision/evidence records for every dependency and exact hardware revision.

The simulator can be an Elixir application on macOS and need not imply Nerves
or Linux hardware inside a frame.

## Host track

### H1 — Library core

- OTP application and supervision tree;
- content-addressed store and metadata migrations;
- import, pin, recoverable remove, labels, and search;
- immutable recipe/variant relationships;
- test-only CLI or local harness.

**Exit:** crash and restart preserve committed masters; identical recipes reuse
cache; removal cannot collect referenced/pinned content.

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

- constrained TD example;
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

- direct push and sleeping pull;
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

## Release maturity

### Research preview

Simulator, recipes, renderer experiments, and UI can change incompatibly. No
hardware purchase recommendation.

### Prototype release

At least one exact hardware assembly has a reproducible build record, signed
firmware, protocol conformance, and validation results. It remains experimental.

### Reference release

The exact revision has E3/E4 evidence, documented replacements/deviations,
security review, recovery update, accessible host UX, and a frozen compatible
protocol/profile version.

“Reference” does not mean consumer certification or permission to conceal mains
wiring. Production/commercialization needs independent regulatory, battery,
EMC/radio, thermal, mechanical, and manufacturing work.
