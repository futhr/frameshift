# Software Stack Research

**Research date:** 2026-09-22

**Outcome:** use Elixir/OTP on the Mac, a thin SwiftUI shell, and isolated Zig
executables/firmware. Nerves is optional outside the physical frame, not its
default runtime. Do not use Membrane. Do not add Python.

## Recommended topology

```text
macOS menu-bar app (SwiftUI)
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
the Swift shell restart without interrupting queued work.

## Elixir/OTP host core

Elixir owns state machines, supervision, job cancellation, bounded concurrency,
frame coordination, and protocol semantics. The first implementation should be
an OTP release run as a per-user process. It should expose only a local Unix
domain socket to the Swift shell; it must not open a general LAN control port.

Candidate libraries must be pinned and revalidated when implementation starts:

| Need | Candidate | Use boundary |
| --- | --- | --- |
| WoT value/runtime | Pinned Wotex `wotex` and `wotex_runtime` packages | Bounded TD/TM admission, extension preservation, deterministic Form selection, typed requests/results, and explicit credential/transport ports. Frameshift retains state, policy, binary assets, and effect truth. |
| WoT HTTP mapping | Pinned `wotex_binding_http` plus a Frameshift-owned client | JSON Property/Action and SSE mapping only. It is not the binary artifact binding, TLS policy, HTTP server, or physical-effect proof. |
| HTTP client | `Req` | Disable automatic redirects and retries for frame writes; set absolute operation deadlines. |
| HTTP server for simulator/optional Nerves bridge | `Plug` + `Bandit` | Small explicit router; not a dependency of MCU firmware. |
| Metadata database | `Exqlite`/SQLite | Host only; single owning process and migrations. A native upstream dependency is acceptable, but custom native code remains Zig. |
| Host JSON | `Jason` or OTP-native equivalent available at implementation time | Bounded decode; reject duplicate/unknown required fields; preserve TD extensions. MCU parsing is a separate Zig selection. |
| Discovery | macOS Network framework/Bonjour through Swift; `mdns_lite` on Nerves | Advertise only the privacy-minimal introduction record. |

The Wotex packages were inspected in the sibling checkout at the immutable
revision recorded in [protocol foundations](protocol-foundations.md). They are
not published to Hex at that revision; a release dependency must pin every
selected package to the same commit and pass archive, license, and clean-
consumer qualification. A sibling path is development-only.

Req is convenient but enables redirect and retry steps by default. Frameshift
must construct a restricted request pipeline for mutations rather than inherit
those defaults. Elixir ports are the preferred boundary for the Zig raster
worker because an external process can be supervised and restarted without
loading native code into the BEAM. See the current [Req documentation](https://req.hexdocs.pm/),
[Bandit documentation](https://bandit.hexdocs.pm/readme.html), and
[Elixir Port documentation](https://elixir.hexdocs.pm/Port.html).

### Host persistence

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
`LSUIElement` for hiding the Dock icon. `SMAppService` is the supported control
surface for bundled login items and launch agents. Sources: [MenuBarExtra](https://developer.apple.com/documentation/SwiftUI/MenuBarExtra)
and [Service Management](https://developer.apple.com/documentation/servicemanagement/).

The Swift layer must not duplicate library, recipe, scheduling, or frame state.
It submits commands and subscribes to snapshots from the Elixir core.

## Zig boundary

Custom native code is Zig. Two distinct artifacts are anticipated:

1. `frameshift-raster`, a macOS executable that accepts a length-framed binary
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
