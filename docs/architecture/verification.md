# Software Verification Map

**Status:** implementation evidence ledger against the complete product

This map connects bounded requirements to executable checks. A passing row
demonstrates only the named behavior and evidence profile. It does not create a
smaller product tier or satisfy a broader end-to-end requirement. Simulator
results do not validate live transport, physical panels, controller
electronics, packaging, security review, or certification.

| Requirement | Owner | Automated evidence | Current state |
| --- | --- | --- | --- |
| Portable domain boundaries preserve delivery, content-reference, replay, and audit atomicity under one writer | Core | `Frameshift.Delivery.TransitionTest`, `Frameshift.Diagnostics.StoreTest`, library and diagnostic audit tests, existing outbox/direct-delivery crash and replay tests; Mac/Linux contract tests required | Pure Delivery decisions and the Diagnostics audit policy are extracted; persisted audit details are allowlisted; remaining context extraction and cross-platform qualification remain open |
| A failed update is traceable by command and attempt ID across durable audit, native logs, metrics, and authoritative display state | Core/shell | Diagnostic IPC and formatter tests; packaged command-to-display failure injection, redaction, restart, and correlation tests required | Command and delivery audit correlation, redacted reads, and named telemetry are implemented; complete attempt-level trace and independent-frame evidence remain open |
| Console.app and `/usr/bin/log` read core and shell operational logs without a Frameshift UI; health, metrics, and audit have a bounded read-only CLI | Core/shell | `Frameshift.LocalIPC.DiagnosticsServerTest` covers a stalled client, collector outage, and unsafe socket directory; `CoreLogBridgeTests` checks public field validation; `scripts/check-packaged-app` exercises all three installed CLI reads; bridge-failure and Linux tests required | A packaged Mac app showed native shell and core command logs; the bundled CLI read health, metrics, and audit over peer-authenticated IPC. Production signing, log backpressure, and long-running behavior remain open |
| Local metric catalog preserves units, bounded dimensions, restart coverage, and disk/resource ceilings | Core | `Frameshift.Diagnostics.CatalogTest`, `Frameshift.Diagnostics.MetricsTest`, and `Frameshift.LocalIPC.DiagnosticsServerTest` cover bounded labels, invalid rollups, catalog meaning, reset and loss status, collector and SQLite owner outages, and restart readback; long-running load and idle measurements on Mac and Linux required | Local reporter, rollups, bounded labels, versioned definitions, restart readback, and collector status are implemented; historical coverage and physical disk/resource ceilings remain unqualified |
| Immutable content-addressed masters, recipe identity, recoverable removal, protected references, and verified readback | Elixir core | `Frameshift.LibraryTest`, `Frameshift.LocalAPITest` | Implemented for the local durable library; App Sandbox bookmarks and retention UI remain open |
| Bounded control JSON, duplicate-key rejection, embedded schemas, and version skew rejection | Frame Protocol/core | `Frameshift.Protocol.JSONTest`, `Frameshift.Protocol.SchemaTest`, protocol fixtures | Implemented for v0.1 fixtures |
| Bounded W3C TD/TM admission, unknown-extension preservation, required-profile rejection, and deterministic advertised Form selection | Frame Protocol/core | `Frameshift.Protocol.ThingTest`, embedded Thing Models, Frame and Host Outbox TD fixtures | Implemented for the semantic admission/selection boundary; live bindings remain open |
| A selected finite JSON Property/Action Form executes through the pinned Wotex HTTP binding with exact credential audience, local-address admission, mutual TLS, no pooling/redirect/retry path, absolute deadline, and bounded response collection | Frame Protocol/core | `Frameshift.Transport.HTTPClientTest` with generated independent server/client certificate chains and a live loopback TLS socket; `Frameshift.Transport.KeychainBrokerTest` for callback framing | Finite client binding and Keychain broker code are present; their combined installed TLS path, SSE lifecycle, and production-device interoperability remain unverified |
| An awake push-capable frame receives an exact rendered artifact and desired-state request through its advertised binary/JSON Forms, strong ETag preconditions, bounded typed problems, explicit idempotent retry rules, and a final authoritative state read | Frame Protocol/core | `Frameshift.DirectSyncTest` across two route-independent TD variants; `Frameshift.Transport.HTTPClientTest` over live mutually authenticated, SPKI-pinned loopback TLS; `Frameshift.RenderPipelineTest` through the push-only queue command | Implemented through rendering and direct orchestration; the installed Keychain broker has not yet been exercised with an issued identity and independent live device |
| A paired frame record binds one admitted universal TD and capability instance to a pinned server SPKI fingerprint and opaque Keychain credential reference, survives restart, and supplies UI targets without vendor branching | Frame Protocol/core | `Frameshift.FrameRegistryTest`, `Frameshift.LibraryTest`, `Frameshift.LocalAPITest` | Implemented for post-pairing durable custody; Bonjour discovery, physical pair mode, certificate issuance/rotation, and Keychain writes remain open |
| A physical bootstrap record contains only a device ID, frame SPKI pin, and at least 16 secret bytes; the host checks the presented peer certificate before sending the secret and later matches the authenticated TD device ID | Pairing/core | `Frameshift.Pairing.BootstrapTest`, `Frameshift.Pairing.RequestTest`, `Frameshift.Pairing.WindowTest`, `Frameshift.Pairing.EndpointTest`, `Frameshift.Pairing.ClientTest`, `Frameshift.Pairing.StoreTest`, `Frameshift.Pairing.HTTP1Test`, `Frameshift.Pairing.TLSServerTest`, `Frameshift.SimulatorTest`, pairing schema fixtures | Bounded QR/request parsing, physical-window state, pinned host client, fail-closed simulator custody, and a live pre-pair TLS socket pass in software. QR capture, host certificate issuance, rollback-resistant firmware storage, and independent-frame verification remain open |
| Desired/current separation, verified storage, idempotence, still-only playlists, and power-loss recovery | Simulator | `Frameshift.SimulatorTest` | Implemented in software simulation |
| Sleeping contact keeps only the newest manifest and converges after missed/failed contact | Core/simulator | `Frameshift.OutboxTest` | Implemented in software simulation |
| A push-only command records its desired artifact before network I/O, exposes an unknown outcome in the menu, blocks a new intent while confirmation is pending, and advances current/previous-known-good only after authoritative display confirmation | Core/library/shell | `Frameshift.DirectDeliveryTest`, `Frameshift.DirectSyncTest`, `Frameshift.RenderPipelineTest`, `ShellModelTests` | A read-only “Check frame” command uses the advertised state Form and confirms matching display without replay; the broker is wired but pairing and independent-frame acceptance remain open |
| A pull request with a verified peer DER certificate resolves exactly one paired SPKI pin, parses one bounded HTTP/1.1 exchange, reads only that frame's current manifest and exact artifact, and clears the outbox only with a strict current-revision acknowledgement | Core/outbox | `Frameshift.Outbox.HTTP1Test`, `Frameshift.Outbox.EndpointTest`, `Frameshift.Outbox.TLSServerTest` | Framing, identity, HTTP semantics, and the supervised listener's live mutual-TLS handshake pass in software; installed Keychain/service wiring and a frame client remain open |
| Fixed-point crop, nearest/bilinear resize, alpha composition, caller-supplied palette, and deterministic dither | Zig renderer | Zig golden, boundary, malformed-input, and parser-fuzz tests | Implemented for generic RGB24 and indexed still profiles |
| Advertised capability structure—not vendor/model naming—selects a supported artifact profile and compiles a deterministic centered composition | Core/renderer | `Frameshift.RenderProfileTest`, `Frameshift.RenderPipelineTest` | Implemented for tightly packed uncompressed sRGB RGB24; exact indexed wire-code packing and measured Paper/Photo/Pixel profiles remain open |
| Native failure cannot terminate the BEAM; timeout or malformed response restarts a clean worker owner | Core/renderer | `Frameshift.RendererTest` | Implemented with an external Zig port |
| One supported still image is bounded, orientation-normalized, converted to sRGB straight-alpha RGBA8 with Apple Image I/O, handed off in a user-only file, digest-verified, and persisted with its exact original bytes | Swift shell/core | `frameshift-shell-checks`, `frameshift-ipc-probe`, `Frameshift.LocalAPITest`, `Frameshift.MasterPackageTest`, `scripts/check-packaged-app` | Implemented for the installed import path; file bookmarks/sandbox distribution and a larger format/orientation/color fixture corpus remain open |
| A durable normalized master is read back with object and package verification, rendered for a paired capability/profile, cached, queued to the sleeping outbox or dispatched to a push-only frame, and converges in-process | Core/renderer/simulator | `Frameshift.LibraryTest`, `Frameshift.RenderProfileTest`, `Frameshift.RenderPipelineTest`, `Frameshift.DirectDeliveryTest` | Implemented through the product queue command for compatible RGB24 targets; pairing and an installed Keychain-to-frame TLS acceptance test remain open |
| One explicitly selected generation provider preflights, times out, caches exact repeats, and persists no provider context | Core generation | `Frameshift.GenerationTest` | Implemented with fixture providers only |
| Production core configuration is relocatable, boots with an explicit renderer path, and serves the versioned local protocol | Elixir core/Swift shell | `scripts/check-core-release`, `frameshift-ipc-probe` | Implemented with a real Swift-to-release round trip |
| A fresh 256-bit challenge crosses a one-use user-only bootstrap file, authenticates every bounded local request with constant-time comparison, and binds each mutation ID to a durable canonical command hash and terminal outcome | Swift shell/core | `Frameshift.LocalIPC.TokenTest`, `Frameshift.LocalIPC.ServerTest`, `Frameshift.LibraryTest`, `frameshift-shell-checks`, `frameshift-ipc-probe`, `scripts/check-core-release`, `scripts/check-packaged-app` | Implemented for the protected-bootstrap and durable at-most-once replay profile; an interrupted claim returns an explicit unknown outcome and the shell refreshes authoritative state instead of repeating the mutation |
| Menu extra remains a snapshot/command client, launches the bundled OTP core and Zig worker, uses authoritative durable library/target state, and works with no generation provider | Swift shell/core | `Frameshift.LocalIPC.ServerTest`, `Frameshift.LocalAPITest`, `Frameshift.RenderPipelineTest`, `Frameshift.Transport.KeychainBrokerTest`, `frameshift-shell-checks`, `frameshift-ipc-probe`, `scripts/check-packaged-app` | The broker is launched with the bundled core; pairing UI, live Keychain-to-frame TLS verification, service registration, and signed distribution remain open |
| Repository-owned build and checks contain no Python; shell and workflow files pass pinned linters | Repository policy | `scripts/check policy`, CI workflow | Enforced for tracked and untracked source files |
| Elixir modules and test modules follow the required module documentation layout; public API docs and types build | Core/tooling | `scripts/check-elixir-docs`, Doctor, ExDoc warnings-as-errors, Dialyzer | Enforced with 100% module and type coverage in the current Doctor report; function docs cover 79.2% of the inspected surface |
| Generated protocol and renderer framing cases, Swift package behavior, and safety-optimized Zig code are checked | Core/shell/renderer | StreamData property tests, `swift test`, Zig Debug and ReleaseSafe tests | Added to the implemented software gate; real transport tests require permitted local sockets |

## Open evidence gates

The following remain open and must not be inferred from the automated rows:

- exact Paper, Photo, or Pixel hardware selection and measured render profiles;
- physical refresh completion, interrupted electrical update, power, thermal,
  depth, mounting, and optical measurements;
- pairing, mutual TLS, certificate rotation, authorization, and independent
  security review;
- sandbox-safe file bookmarks and UI acceptance of imported security-scoped
  references across app restarts;
- commissioned Keychain identities and live reference HTTPS TLS, SSE lifecycle, ExposedThing
  routing, and live interoperability with independent devices;
- real AI provider preflight, provenance, cost/privacy disclosure, cancellation,
  and local-only network isolation;
- VoiceOver/manual accessibility acceptance, Service Management background
  lifecycle, Developer ID signing, hardened runtime, and notarization;
- project license selection and third-party release notices.

## End-to-end acceptance path

The installed product is complete only when the same shipped app can execute
this entire path without simulator-only substitutes or manually seeded pairing
records:

1. Discover a frame, verify its bounded Wotex Thing Description and advertised
   Forms, commission it in physical pair mode, and persist its identity and
   credential in Keychain. Discovery and commissioning are not implemented;
   durable *post-pairing* record admission is implemented.
2. Import or generate an image, retain exact source bytes and a canonical
   master, select an advertised artifact profile, render it, and verify the
   content address. Import, storage, RGB24 rendering, and cache verification
   are implemented; real generation providers and indexed-profile wire output
   are not.
3. For an awake push-capable frame, resolve its Keychain credential at the
   transport boundary and run direct synchronization using its selected Forms.
   The queue command now renders and dispatches push-only targets through the
   reference synchronizer when a credential resolver is configured, recording
   a durable intent before network I/O. The menu process now provides a
   Keychain-backed signing socket and the core configures its resolver at
   launch. No commissioned identity or live installed TLS exchange has been
   verified, so shipped delivery to a physical push-only frame is unproven.
   An uncertain outcome remains visible as pending and blocks a new intent.
   “Check frame” reads its advertised state Form and commits only a matching
   displayed asset; installed credentials are still required to run it.
4. For a sleeping pull-capable frame, expose the latest per-frame outbox over
   an authenticated Host Outbox Thing, serve exact rendered bytes, accept the
   frame's verified acknowledgement, and update authoritative current state.
   Durable convergence and frame-scoped HTTP semantics are tested in-process.
   A supervised mutual-TLS listener passes a real-socket test. It is not yet started by the
   installed app from a Keychain-backed host identity, and the frame-side
   client is not implemented.
5. Survive restarts, credential rotation, network loss, interrupted refresh,
   and app upgrades without losing the previous known-good display. Software
   persistence and simulator fault cases cover part of this; physical fault
   injection, service lifecycle, signed distribution, and independent security
   review are still required.

These steps are acceptance gates for one final product, not optional product
tiers. Passing the tooling gate below does not close them.

Run all implemented software checks from the repository root:

```sh
make check
```

## Formal verification target

The strongest candidate for model checking is the frame delivery transition
system: a command can be claimed, bytes installed, desired state committed,
display interrupted, an acknowledgement delayed, and contact retried in
different orders. A model should assert that `currentAsset` advances only after
display confirmation, protected known-good bytes are never collected, outbox
revisions do not retreat, and replay cannot apply a mutation twice. These are
state and concurrency properties shared by the Elixir host and future Zig
frame agent; the verification language should describe the protocol rather
than mirror either implementation language.

[ExMaude](https://github.com/futhr/ex_maude) is a plausible Elixir-facing
Maude interface for state-space search. It requires a separate Maude binary
and a maintained second specification. The current StreamData properties and
simulator fault cases exercise concrete code, but they do not exhaustively
explore interleavings. A Maude model becomes valuable when both sides of the
delivery and acknowledgement state machine exist and can be checked against
the same transition traces. It is not a substitute for physical panel,
power-loss, or cryptographic interoperability evidence.
