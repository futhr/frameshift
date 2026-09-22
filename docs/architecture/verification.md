# Software Verification Map

**Status:** research-preview implementation evidence

This map connects implemented software requirements to executable checks. A
passing row demonstrates only the named software behavior. Simulator results do
not validate physical panels, controller electronics, transport security,
packaging, or certification.

| Requirement | Owner | Automated evidence | Current state |
| --- | --- | --- | --- |
| Immutable content-addressed masters, recipe identity, recoverable removal, and protected references | Elixir core | `Frameshift.LibraryTest` | Implemented for the research preview |
| Bounded control JSON, duplicate-key rejection, embedded schemas, and version skew rejection | Frame Protocol/core | `Frameshift.Protocol.JSONTest`, `Frameshift.Protocol.SchemaTest`, protocol fixtures | Implemented for v0.1 fixtures |
| Desired/current separation, verified storage, idempotence, still-only playlists, and power-loss recovery | Simulator | `Frameshift.SimulatorTest` | Implemented in software simulation |
| Sleeping contact keeps only the newest manifest and converges after missed/failed contact | Core/simulator | `Frameshift.OutboxTest` | Implemented in software simulation |
| Fixed-point crop, nearest/bilinear resize, alpha composition, caller-supplied palette, and deterministic dither | Zig renderer | Zig golden, boundary, malformed-input, and parser-fuzz tests | Implemented for experimental generic profiles |
| Native failure cannot terminate the BEAM; timeout or malformed response restarts a clean worker owner | Core/renderer | `Frameshift.RendererTest` | Implemented with an external Zig port |
| A verified canonical master renders once, reuses the artifact cache, queues, and converges on current state | Core/renderer/simulator | `Frameshift.RenderPipelineTest` | Implemented for canonical RGBA8 and the experimental RGB24 profile |
| One explicitly selected generation provider preflights, times out, caches exact repeats, and persists no provider context | Core generation | `Frameshift.GenerationTest` | Implemented with fixture providers only |
| Production core configuration is relocatable and boots with an explicit renderer path | Elixir core | `scripts/check-core-release` | Implemented as an isolated OTP release smoke check |
| Menu extra remains a snapshot/command client and works with no generation provider | Swift shell | `frameshift-shell-checks`, ad-hoc `.app` packaging check | Implemented with the preview client |
| Repository-owned build and checks contain no Python; shell and workflow files pass pinned linters | Repository policy | `scripts/check policy`, CI workflow | Enforced for tracked and untracked source files |

## Open evidence gates

The following remain open and must not be inferred from the automated rows:

- exact Paper, Photo, or Pixel hardware selection and measured render profiles;
- physical refresh completion, interrupted electrical update, power, thermal,
  depth, mounting, and optical measurements;
- pairing, mutual TLS, certificate rotation, authorization, and independent
  security review;
- authenticated Swift–Elixir local IPC, Keychain identities, and sandbox file
  handoff;
- real AI provider preflight, provenance, cost/privacy disclosure, cancellation,
  and local-only network isolation;
- VoiceOver/manual accessibility acceptance, background lifecycle, embedded
  core packaging, Developer ID signing, hardened runtime, and notarization;
- project license selection and third-party release notices.

Run all implemented software checks from the repository root:

```sh
make check
```
