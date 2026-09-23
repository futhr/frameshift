# Software Stack Research

**Research date:** 2026-09-22

**Outcome:** use a portable Elixir/OTP host core, a thin SwiftUI shell on macOS,
and isolated Zig executables/firmware. Linux and Raspberry Pi-class Linux hosts
use platform adapters around the same core. Nerves is optional for Linux-based
roles, not the MCU frame's default runtime. Do not use Membrane or Python.

## Recommended topology

```text
macOS menu-bar app (SwiftUI; first host shell)
  | Apple APIs: MenuBarExtra, Vision, Core Image, Keychain, ServiceManagement
  | local authenticated IPC
  v
Frameshift Core (Elixir/OTP release)
  | library, recipes, jobs, frame registry, discovery, protocol client
  | supervised executable port
  +--> Frameshift Raster (Zig)
  |      crop, scale, palette mapping, dithering, pixel transforms
  |
  +--> AI provider adapters
         local MediaGenerationKit / local Ollama / optional cloud APIs

LAN: W3C WoT TD/TM + advertised authenticated Forms
     reference HTTPS binding; qualified constrained bindings may coexist
  v
Thin Frame Agent (MCU-class; Zig reference direction)
  | verified asset store, desired/current state, playlist, health
  +--> Photo adapter
  +--> Paper adapter
  +--> Pixel timed-parallel/DMA adapter
```

This is one product with explicit process boundaries, not a collection of
microservices. The boundaries isolate native crashes, protect secrets, and let
the platform shell restart without interrupting queued work.
On Linux, a native shell and platform adapters replace Apple-only facilities;
the core, renderer wire contract, and frame protocol remain shared.

## Elixir/OTP host core

Elixir owns state machines, supervision, job cancellation, bounded concurrency,
frame coordination, and protocol semantics. The first implementation is an OTP
release run as a per-user process. It exposes a local Unix domain socket to the
Mac shell. Linux hosts retain the authenticated local boundary; the host must
not open a general LAN control port.

Selected libraries and bounded candidates are tracked independently:

| Need | Candidate | Use boundary |
| --- | --- | --- |
| WoT value/runtime | Wotex `wotex` and `wotex_runtime`, both pinned to `e6aa01a69ea35447afa989d5dea061618d20b3cf` | Bounded TD/TM admission, extension preservation, deterministic Form selection, typed requests/results, and explicit credential/transport ports. Frameshift retains state, policy, binary assets, and effect truth. |
| WoT HTTP mapping | Pinned `wotex_binding_http` plus a Frameshift-owned client | JSON Property/Action and SSE mapping only. It is not the binary artifact binding, TLS policy, HTTP server, or physical-effect proof. |
| HTTP client | `Mint` one-shot connections | Keep client certificates and keys inside one caller-owned callback; resolve and authorize every destination, disable pooling/proxies/redirects/retries, pin the frame SPKI, and enforce an absolute operation deadline plus incremental response bounds. |
| HTTP server for simulator/optional Nerves bridge | `Plug` + `Bandit` | Small explicit router; not a dependency of MCU firmware. |
| Metadata database | Direct Exqlite/SQLite under D-010; Ecto + `ecto_sqlite3` remains a measured candidate | Host only; one writer, durable transactions, database-enforced invariants, and content-store reconciliation. An Ecto adoption must explicitly supersede D-010; see the [portable host core](../architecture/host-core.md). |
| Host JSON | `Jason` or OTP-native equivalent available at implementation time | Bounded decode; reject duplicate/unknown required fields; preserve TD extensions. MCU parsing is a separate Zig selection. |
| Discovery | macOS Network framework/Bonjour through Swift; `mdns_lite` on Nerves | Advertise only the privacy-minimal introduction record. |

The selected Wotex packages are fetched from their upstream Git repository at
the immutable revision recorded in [protocol foundations](protocol-foundations.md).
The lockfile records the same full commit for all three packages; the sibling
checkout is not a build input. Their Apache-2.0 files and Wotex's bundled W3C
schema notice were inspected at that revision. Repository-wide third-party
notice assembly remains a separate distribution gate.

Req remains suitable for ordinary non-secret HTTP, but its normal Finch path
pools connection configuration. Passing a client certificate or private key in
those options would retain the credential beyond Wotex's immediate callback.
The reference frame client therefore uses processless Mint directly and closes
each connection before returning. Elixir ports are the preferred boundary for
the Zig raster worker because an external process can be supervised and
restarted without loading native code into the BEAM. See the current [Mint documentation](https://hexdocs.pm/mint/),
[Bandit documentation](https://bandit.hexdocs.pm/readme.html), and
[Elixir Port documentation](https://elixir.hexdocs.pm/Port.html).

### Host persistence

The normative domain boundaries, persistence choice, platform ports, and
qualification gates are in [Portable Host Core](../architecture/host-core.md).

The database stores metadata, never the only copy of artwork bytes. Masters and
derivatives live in a content-addressed directory. Database rows point to
digests and record provenance. Every write follows this order:

1. stream bytes to a temporary file while hashing;
2. validate declared type, decoded dimensions, and limits;
3. flush and atomically rename to the digest path;
4. commit the metadata transaction;
5. enqueue derivative work.

Startup reconciliation removes abandoned temporary files after a grace period
and records orphaned digest files for later adoption or collection. It never
deletes pinned, referenced, current, or previous-known-good content.

## Thin frame runtime

The frame runtime has the same explicit ownership model as an OTP design, but
must fit an MCU power and depth envelope:

```text
FrameAgent
  Network
  Identity
  AssetStore
  ProtocolServer
  DesiredState
  DisplaySupervisor
    DisplayAdapter
  PlaylistScheduler
  Health
```

An adapter fault must not corrupt the asset store or networking. `DesiredState`
serializes display changes so two host requests cannot drive hardware
concurrently. The adapter reports prepared, refreshing, displayed, or failed;
only displayed advances `currentAsset`.

Zig is the reference direction for project-owned firmware. Exact networking
silicon is deliberately not selected: the choice must demonstrate Wi-Fi,
mutual TLS, secure key storage, atomic flash slots, and a build that respects
the no-Python rule. A factory-programmed network coprocessor is acceptable if
its protocol and update lifecycle are documented.

The Paper frame cannot remain available on the LAN while asleep. It wakes on a
timer or button, checks the host outbox for a committed still, refreshes if
needed, then powers down its radio and display rails. The protocol therefore
supports host push for continuously powered frames and authenticated pull for
sleeping frames.

### Where Nerves still fits

Nerves remains attractive for an optional always-powered home bridge, a frame
simulator, protocol conformance target, or powered display prototype whose
controller must run Linux. It supplies OTP supervision and update semantics the
MCU design should emulate. It does not override the frame's mechanical and
energy constraints, and no reference BOM may quietly add a Linux SBC.

Nerves 1.15 documents custom systems for hardware outside its prebuilt targets;
that proves extensibility, not mechanical or power suitability for a frame.
VintageNet provides persisted Wi-Fi/network state and `mdns_lite` provides
small Nerves-oriented mDNS advertisement/discovery. They are candidates for the
optional bridge or simulator, not dependencies of Zig MCU firmware. Sources:
[Nerves custom systems](https://nerves.hexdocs.pm/customizing-systems.html),
[VintageNet](https://hexdocs.pm/vintage_net/VintageNet.html), and
[`mdns_lite`](https://hexdocs.pm/mdns_lite/).

### Firmware updates

Firmware updates must be signed and atomic before remote update is enabled.
The frame needs two firmware slots or an equivalent recoverable scheme.
Nerves/NervesHub may serve as a behavioral reference for an optional bridge,
but the MCU implementation must continue to display the last valid image during
update, reboot, failed download, or unavailable update service.

## Swift/SwiftUI boundary

Swift owns only what is genuinely native to macOS:

- `MenuBarExtra` and the popover-like window;
- file pickers, drag/drop, pasteboard, notifications, and accessibility;
- Keychain/Secure Enclave credentials;
- Bonjour browsing and Network framework connections when advantageous;
- Vision classification and feature prints;
- Core Image/Image I/O decode and preview;
- MediaGenerationKit integration;
- `SMAppService` lifecycle registration.

Apple documents `MenuBarExtra` window style for data-rich menu extras and
`LSUIElement` for hiding the Dock icon. The packaged app uses a menu-bar agent
with the selected artwork retained as its Finder icon. `SMAppService` is the
supported control surface for bundled login items and launch agents. Sources: [MenuBarExtra](https://developer.apple.com/documentation/SwiftUI/MenuBarExtra)
and [Service Management](https://developer.apple.com/documentation/servicemanagement/).

The Swift layer must not duplicate library, recipe, scheduling, or frame state.
It submits commands and subscribes to snapshots from the Elixir core.

## Zig boundary

Custom native code is Zig. Two distinct artifacts are anticipated:

1. `frameshift-raster`, a host-platform executable that accepts a length-framed binary
   protocol on stdin/stdout and never receives credentials;
2. frame firmware, including a non-Raspberry timed-parallel/DMA Pixel
   controller if a validation spike proves its Zig toolchain, networking,
   refresh, and update path dependable.

The raster protocol carries a versioned job header plus paths or file
descriptors to canonical decoded buffers. It emits progress and one terminal
result. The Elixir owner enforces maximum dimensions, output size, wall-clock
deadline, and process memory limits where the OS permits. A crash fails one job
and restarts the port.

Zig is not a reason to rewrite high-quality system facilities. SQLite, image
codecs supplied by Apple, and vendor kernel drivers can remain upstream native
dependencies when their license and attack surface are reviewed. Frameshift's
own native logic stays Zig.

## Explicit exclusions

- **Membrane:** no role because Frameshift has no video, audio, animation, or
  streaming pipeline.
- **AtomVM as an assumed frame runtime:** it demonstrates that Elixir semantics
  and deep sleep can coexist on ESP32-class MCUs, but the normal ESP-IDF
  toolchain conflicts with the repository's no-Python build rule. It remains
  research until a compliant, reproducible toolchain is demonstrated.
- **A browser/Electron shell:** unnecessary for a tiny menu-bar utility and
  weaker access to the desired native lifecycle and Vision APIs.
- **In-process NIFs for custom raster work:** a memory error can crash the BEAM;
  an executable port is the safer first boundary.
- **Python:** prohibited throughout the project stack and tooling.

## Qualification gates

The stack is release-qualified only after these gates:

1. bundle and notarize a Swift menu app with a per-user Elixir release;
2. survive core and raster-worker crashes without losing a queued job;
3. measure idle RSS and wakeups on the oldest supported Mac;
4. retain a frame asset across abrupt power loss and complete a signed firmware
   rollback on the selected MCU;
5. drive one exact display revision for whichever hardware track is being
   implemented; each other adapter qualifies independently when its track is
   chosen;
6. prove the selected Zig MCU toolchain and Wi-Fi/TLS path before naming any
   controller reference hardware, plus sleep current for Paper or refresh under
   load for Pixel when those tracks are chosen.
