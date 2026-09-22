# Software Verification Map

**Status:** implementation evidence ledger against the complete product

This map connects bounded requirements to executable checks. A passing row
demonstrates only the named behavior and evidence profile. It does not create a
smaller product tier or satisfy a broader end-to-end requirement. Simulator
results do not validate live transport, physical panels, controller
electronics, packaging, security review, or certification.

| Requirement | Owner | Automated evidence | Current state |
| --- | --- | --- | --- |
| Immutable content-addressed masters, recipe identity, recoverable removal, protected references, and verified readback | Elixir core | `Frameshift.LibraryTest`, `Frameshift.LocalAPITest` | Implemented for the local durable library; App Sandbox bookmarks and retention UI remain open |
| Bounded control JSON, duplicate-key rejection, embedded schemas, and version skew rejection | Frame Protocol/core | `Frameshift.Protocol.JSONTest`, `Frameshift.Protocol.SchemaTest`, protocol fixtures | Implemented for v0.1 fixtures |
| Bounded W3C TD/TM admission, unknown-extension preservation, required-profile rejection, and deterministic advertised Form selection | Frame Protocol/core | `Frameshift.Protocol.ThingTest`, embedded Thing Models, Frame and Host Outbox TD fixtures | Implemented for the semantic admission/selection boundary; live bindings remain open |
| A paired frame record binds one admitted universal TD and capability instance to a pinned server SPKI fingerprint and opaque Keychain credential reference, survives restart, and supplies UI targets without vendor branching | Frame Protocol/core | `Frameshift.FrameRegistryTest`, `Frameshift.LibraryTest`, `Frameshift.LocalAPITest` | Implemented for post-pairing durable custody; Bonjour discovery, physical pair mode, certificate issuance/rotation, and Keychain writes remain open |
| Desired/current separation, verified storage, idempotence, still-only playlists, and power-loss recovery | Simulator | `Frameshift.SimulatorTest` | Implemented in software simulation |
| Sleeping contact keeps only the newest manifest and converges after missed/failed contact | Core/simulator | `Frameshift.OutboxTest` | Implemented in software simulation |
| Fixed-point crop, nearest/bilinear resize, alpha composition, caller-supplied palette, and deterministic dither | Zig renderer | Zig golden, boundary, malformed-input, and parser-fuzz tests | Implemented for generic RGB24 and indexed still profiles |
| Advertised capability structure—not vendor/model naming—selects a supported artifact profile and compiles a deterministic centered composition | Core/renderer | `Frameshift.RenderProfileTest`, `Frameshift.RenderPipelineTest` | Implemented for tightly packed uncompressed sRGB RGB24; exact indexed wire-code packing and measured Paper/Photo/Pixel profiles remain open |
| Native failure cannot terminate the BEAM; timeout or malformed response restarts a clean worker owner | Core/renderer | `Frameshift.RendererTest` | Implemented with an external Zig port |
| One supported still image is bounded, orientation-normalized, converted to sRGB straight-alpha RGBA8 with Apple Image I/O, handed off in a user-only file, digest-verified, and persisted with its exact original bytes | Swift shell/core | `frameshift-shell-checks`, `frameshift-ipc-probe`, `Frameshift.LocalAPITest`, `Frameshift.MasterPackageTest`, `scripts/check-packaged-app` | Implemented for the installed import path; file bookmarks/sandbox distribution and a larger format/orientation/color fixture corpus remain open |
| A durable normalized master is read back with object and package verification, rendered for a paired capability/profile, cached, queued to the sleeping outbox, and converges in-process | Core/renderer/simulator | `Frameshift.LibraryTest`, `Frameshift.RenderProfileTest`, `Frameshift.RenderPipelineTest` | Implemented through the product queue command for compatible RGB24 pull targets; installed pairing and real authenticated frame transport remain open |
| One explicitly selected generation provider preflights, times out, caches exact repeats, and persists no provider context | Core generation | `Frameshift.GenerationTest` | Implemented with fixture providers only |
| Production core configuration is relocatable, boots with an explicit renderer path, and serves the versioned local protocol | Elixir core/Swift shell | `scripts/check-core-release`, `frameshift-ipc-probe` | Implemented with a real Swift-to-release round trip |
| A fresh 256-bit challenge crosses a one-use user-only bootstrap file and authenticates every bounded local request with constant-time comparison | Swift shell/core | `Frameshift.LocalIPC.TokenTest`, `Frameshift.LocalIPC.ServerTest`, `frameshift-ipc-probe`, `scripts/check-core-release`, `scripts/check-packaged-app` | Implemented for the per-launch protected-bootstrap profile; durable command receipts/replay suppression across core restarts remain open |
| Menu extra remains a snapshot/command client, launches the bundled OTP core and Zig worker, uses authoritative durable library/target state, and works with no generation provider | Swift shell/core | `Frameshift.LocalIPC.ServerTest`, `Frameshift.LocalAPITest`, `Frameshift.RenderPipelineTest`, `frameshift-shell-checks`, `frameshift-ipc-probe`, `scripts/check-packaged-app` | Implemented for import/instruction/pin/remove/target selection and render/queue to compatible pull targets; pairing UI, direct transport, service registration, and signed distribution remain open |
| Repository-owned build and checks contain no Python; shell and workflow files pass pinned linters | Repository policy | `scripts/check policy`, CI workflow | Enforced for tracked and untracked source files |

## Open evidence gates

The following remain open and must not be inferred from the automated rows:

- exact Paper, Photo, or Pixel hardware selection and measured render profiles;
- physical refresh completion, interrupted electrical update, power, thermal,
  depth, mounting, and optical measurements;
- pairing, mutual TLS, certificate rotation, authorization, and independent
  security review;
- sandbox-safe file bookmarks and command replay receipts across core restarts;
- reference HTTPS transport, ExposedThing routing, and live semantic
  interoperability over mutually authenticated TLS;
- real AI provider preflight, provenance, cost/privacy disclosure, cancellation,
  and local-only network isolation;
- VoiceOver/manual accessibility acceptance, Service Management background
  lifecycle, Developer ID signing, hardened runtime, and notarization;
- project license selection and third-party release notices.

Run all implemented software checks from the repository root:

```sh
make check
```
