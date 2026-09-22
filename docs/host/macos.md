# macOS Host

**Status:** draft implementation specification

## Role

Frameshift for macOS is the control plane for all frame classes. It owns the
art library, local labels/search, AI generation recipes, deterministic target
rendering, frame identities, outboxes, still-image playlists, synchronization,
and the audit trail.

The Mac is not a frame's life support. Once a still asset is current, quitting
Frameshift, sleeping the Mac, or losing the network does not blank it.

## Process architecture

```text
Frameshift.app
  SwiftUI MenuBarExtra
  Apple framework bridge
       |
       | local authenticated length-framed IPC
       v
  FrameshiftCore (Elixir/OTP per-user process)
       |-- metadata store
       |-- content-addressed files
       |-- job/outbox supervisors
       |-- Frame Protocol client/server
       `-- frameshift-raster (supervised Zig executable)
```

### Swift application

The native shell owns `MenuBarExtra`, app lifecycle, accessibility, file and
photo selection, drag/drop, Keychain, Vision, Core Image/Image I/O, Bonjour,
notifications, and MediaGenerationKit. It presents snapshots received from the
core and sends commands; it does not create a second source of truth.

### Elixir core

The core is a conventional supervised OTP release. Each long-running job has
one owner, one deadline, bounded input, explicit cancellation, and one terminal
result. Queues are bounded. Provider and frame failures are typed data, not
crashes or prose parsed from logs.

The core owns network policy. Its HTTP client disables automatic mutation
redirects and hidden retries. Frame credentials are fetched from the Swift
Keychain bridge only at the transport boundary and immediately discarded after
request construction.

### Zig raster worker

The worker receives no provider or frame credentials. It processes bounded
canonical image buffers and returns deterministic target bytes. The core
monitors the port, kills it at deadline, and restarts after failure. A worker
crash fails one render job without terminating the library or UI.

## Local IPC

The shell and core communicate over a per-user Unix domain socket in an app-
owned directory. The socket has user-only permissions. Each launch exchanges a
random session challenge stored in Keychain or inherited through a protected
bootstrap channel; connecting to the path alone is insufficient.

Messages are length-prefixed and versioned. Maximum message size is fixed
before allocation. Commands carry a unique ID and receive progress snapshots
plus exactly one terminal response. Reconnection obtains a fresh full snapshot
and does not replay completed UI commands blindly.

The message schema includes no raw private key material. Large image bytes move
through app-owned files/file descriptors rather than base64 JSON.

## Persistence

```text
Application Support/Frameshift/
  metadata.sqlite
  objects/sha256/ab/cdef...
  previews/sha256/...
  work/<job-id>/
  trash/<date>/...
```

Exact filesystem placement uses Apple-provided application-support URLs rather
than hard-coded paths. The metadata database stores object relationships and
state; artwork bytes remain content-addressed files. Temporary work is never
treated as committed content.

Important records are:

- master image and provenance;
- generated variant and parent;
- generation recipe;
- composition/render recipe;
- target artifact and exact capability/profile revision;
- frame identity, certificate reference, friendly local name, and last state;
- desired/current/outbox state;
- playlist and item dwell;
- user labels, Vision labels, confidence/revision, and feature print reference;
- pin/removal/collection state;
- operation audit entries with redacted error data.

Database migrations are transactional and reversible where practical. Startup
reconciles temporary/orphan files without deleting anything referenced, pinned,
queued, current, previous-known-good, or inside the trash retention window.

## Background operation

The first distribution target is a directly downloaded, signed, notarized Mac
app. App Store constraints are a separate research gate.

Use Apple's `SMAppService` to register a bundled per-user login item or launch
agent only after the user enables background synchronization. The app must show
registration state and provide a working disable path. It never installs a root
daemon. Apple describes `SMAppService` as the supported interface for bundled
login items and launch agents: [Service Management documentation](https://developer.apple.com/documentation/servicemanagement/).

The background process wakes only for pending jobs, frame contact, or scheduled
outbox availability. It does not poll powered frames aggressively. Sleeping
frames control their own contact interval; the host reports “waiting for next
contact,” not “offline.”

## Discovery and pairing

The Swift layer uses Bonjour/Network framework to browse the minimal DNS-SD
records. Full metadata appears only after certificate authentication. Pairing
shows the device fingerprint or QR confirmation, requires the frame's physical
pair mode, stores host credentials in Keychain, and records a friendly name
only on the Mac unless the user explicitly writes it to the frame.

USB commissioning is allowed for initial Wi-Fi and identity setup. A cable used
during commissioning is not an installed power architecture.

## AI integration

Provider selection and fallback policy live in Settings, not in the compact
popover. Local execution is preferred. The effective provider, exact model,
download/storage requirement, license, destination, and cost class are visible
before first use.

The host never treats a consumer ChatGPT or Gemini subscription as API access.
It never automates provider websites. Manual image import is always supported.
See [AI image generation research](../research/ai-image-generation.md).

## Labeling and search

Apple Vision performs default on-device classification and image feature-print
generation. Machine labels retain confidence and Vision revision. User labels
are never overwritten. Search combines literal title/label terms, frame/profile
filters, pinned state, and optional local visual similarity.

Cloud labeling is a separate explicit opt-in and is disabled by default.

## Security and privacy

- Keychain stores provider tokens and frame client identities.
- Prompt text and source images remain local unless the selected job explicitly
  names a cloud provider.
- Logs contain digests and typed operation IDs, not artwork bytes, prompts,
  tokens, bootstrap secrets, Wi-Fi credentials, or private filesystem paths.
- Imported metadata is parsed as untrusted input.
- Frames can access only rendered outbox artifacts addressed to their identity,
  not the general host library.
- Deleting a library item is recoverable until trash retention expires.

## Packaging gates

1. clean installation and removal on a fresh supported macOS account;
2. notarization and hardened-runtime validation;
3. shell/core version skew produces a clear upgrade error;
4. crash/relaunch tests for shell, core, raster worker, and generation provider;
5. idle energy-impact measurement with no pending work;
6. Keychain denial/lock behavior;
7. migration and rollback with a copy of real metadata;
8. no undeclared network requests during local-only operation;
9. repository build and test workflow contains no Python dependency.
