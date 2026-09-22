# System Architecture

**Status:** normative product architecture; implementation evidence tracked separately
**Scope:** still images only

## Goal

Frameshift turns a source or generated master into persistent physical artwork
on displays with radically different color, power, and refresh behavior. The
Mac performs expensive work. A frame performs only secure transfer, validation,
retention, scheduling, and its exact display update.

## Topology

```text
User
  |
  v
SwiftUI MenuBarExtra ─── Apple Vision / Core Image / Keychain
  | local authenticated IPC
  v
Elixir/OTP Core ─────── content-addressed library + metadata database
  |        |
  |        +── AI provider adapters (local first; explicit cloud)
  |
  +── supervised Zig raster worker
  |       crop / scale / quantize / dither / pack
  |
  +── WoT Consumer/ExposedThing + sleeping-frame outbox
             |
       advertised authenticated Forms
       HTTPS reference · qualified additional bindings
        _________|__________
       /         |          \
  Paper MCU   Photo MCU   Pixel MCU
  pull/wake   push/pull   push/pull + timed DMA
       \_________|__________/
          immutable asset slots
          desired/current state
```

## Component ownership

### Swift shell

Owns presentation and Apple-only APIs: the menu-bar icon/popover, drag/drop,
file import, Vision labels and similarity features, Keychain identity, native
notifications, and MediaGenerationKit. It does not own durable domain state.

### Elixir core

Owns the library, generation recipes, render jobs, provider selection, frame
registry, schedules, outboxes, synchronization, retries that are explicitly
safe, and the audit trail. Its state survives the UI process.

It also owns the Frameshift W3C WoT consumer/exposed-Thing policy: bounded TD
and Thing Model admission, deterministic Form selection, authorization,
transport ownership, canonical frame state, and effect reconciliation. A
binding result is protocol evidence, not proof that a panel refreshed.

### Zig raster worker

Owns deterministic project-specific image transforms. It is a supervised
executable, not an in-process NIF. One malformed image or native failure can
fail a job without taking down the Elixir runtime.

### Frame agent

Owns device identity, bounded protocol parsing, two-phase asset storage,
desired/current display state, still-image playlist timing, adapter sequencing,
health, and recoverable signed firmware updates. It is MCU-class reference
hardware; Frameshift reference builds contain no Raspberry Pi hardware.

Every frame presents the same semantic affordances through a Thing Description.
The agent may implement HTTPS directly, a qualified constrained-device binding,
or an authenticated gateway Form. Hardware and vendor identities select exact
artifact/display-adapter profiles, never a different host interaction model.

### Display adapter

Owns exact electrical and temporal behavior for one qualified panel revision.
It accepts only an artifact profile it advertised. It reports completion after
the physical update finishes, not when bytes merely entered a queue.

## Power classes and connectivity

### Sleeping bistable frame

Paper can turn the radio and controller off between update windows and retain
the image without power. Because it cannot receive a push while asleep, the
host keeps an outbox keyed by frame ID. On timer/button wake the frame
authenticates, asks for the desired digest, downloads only if changed,
refreshes, acknowledges, and sleeps.

### Continuously powered frame

Photo and Pixel require power while visible. They may advertise on the LAN and
accept host pushes, but also support pull so desired-state behavior is the same
across transports. Loss of the host or network never blanks current artwork.

## Core invariants

1. Every source master, AI result, and display artifact is immutable and
   content-addressed.
2. A frame never displays unverified or partially transferred bytes.
3. `desiredAsset` and `currentAsset` are different states.
4. `currentAsset` advances only after the display adapter reports success.
5. The last current and previous-known-good assets cannot be garbage-collected.
6. Provider credentials never leave the Mac.
7. A frame never fetches an arbitrary artwork URL supplied by another LAN peer.
8. No hidden redirect, retry, model download, provider switch, or cloud upload.
9. Still-image playlists switch discretely; there is no motion pipeline.
10. Mechanical depth and energy class constrain hardware selection.

## Failure model

| Failure | Required outcome |
| --- | --- |
| Mac sleeps or quits | Frame continues showing current artwork. |
| Network disappears | Current artwork remains; pending work waits. |
| Upload interrupted | Inactive temporary bytes are discarded or resumed; current is untouched. |
| Digest mismatch | Candidate is rejected and never becomes desired/current. |
| Display refresh fails | Desired remains pending/failed; current remains last confirmed asset. |
| Power loss during refresh | On reboot, adapter-specific recovery runs; metadata never claims unconfirmed success. |
| Firmware update fails | Previous bootable firmware and current artwork remain recoverable. |
| AI provider fails | Existing masters/results remain; no automatic provider switch. |

## Security boundary

The Mac is trusted to create artwork for paired frames. The LAN is untrusted.
Discovery reveals minimal metadata; exploration and all mutations require a
paired identity. The frame verifies content size, type, digest, dimensions,
profile, and authorization before storage or activation.

## Non-goals

Frameshift is not a cloud photo service, smart display dashboard, signage
platform, social network, remote desktop, live canvas, video player, animation
system, audio device, or universal electronics board.
