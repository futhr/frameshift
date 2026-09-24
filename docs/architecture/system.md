# System Architecture

**Status:** normative product architecture; implementation evidence tracked separately
**Scope:** still images only

## Goal

Frameshift turns a source or generated master into persistent physical artwork
on displays with radically different color, power, and refresh behavior. The
host performs expensive work. A frame performs only secure transfer, validation,
retention, scheduling, and its exact display update.

The portable host core is specified in [Portable Host Core](host-core.md).
macOS is the first shell; Linux and Raspberry Pi-class Linux hosts reuse the
same core and frame semantics through platform adapters.
The public [installation guide](install-and-guide.md) is static and runs a
bounded browser simulation. It is outside the authenticated command path.
Ubuntu and Pi roles are defined in the [Linux host specification](../host/linux.md).
The [domain map](domain-map.md) assigns host transition ownership. The
[diagnostics contract](diagnostics.md) defines audit, logs, metrics, and
read-only access independently of the shell UI.
The [qualification contract](qualified-generations.md) binds new render and
transfer work to an admitted renderer/profile/connector combination while
accepted work and previous-known-good display references survive changes.

## Topology

```text
User
  |
  v
Host shell ───────────── platform UI / media / credential adapters
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

Public static guide ── Gleam/JavaScript decision simulation
                              |
                    non-secret native handoff
                              v
                         Host shell
```

## Component ownership

### Host shell

Owns presentation and platform APIs. On macOS the Swift shell provides the
menu-bar UI, file import, Vision, Keychain, native notifications, and optional
MediaGenerationKit. A Linux shell provides its own adapters. Neither owns
durable domain state.

### Elixir core

Owns the library, generation recipes, render jobs, provider selection, frame
registry, schedules, outboxes, synchronization, retries that are explicitly
safe, the audit trail, and bounded metric rollups. Its state survives the UI
process. Native operational logs remain readable through the host OS without
opening the menu-bar UI.

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
6. Provider credentials stay in the host's platform credential store and are
   released only to the explicitly selected provider transport.
7. A frame never fetches an arbitrary artwork URL supplied by another LAN peer.
8. No hidden redirect, retry, model download, provider switch, or cloud upload.
9. Still-image playlists switch discretely; there is no motion pipeline.
10. Mechanical depth and energy class constrain hardware selection.

## Failure model

| Failure | Required outcome |
| --- | --- |
| Host sleeps or quits | Frame continues showing current artwork. |
| Network disappears | Current artwork remains; pending work waits. |
| Upload interrupted | Inactive temporary bytes are discarded or resumed; current is untouched. |
| Digest mismatch | Candidate is rejected and never becomes desired/current. |
| Display refresh fails | Desired remains pending/failed; current remains last confirmed asset. |
| Power loss during refresh | On reboot, adapter-specific recovery runs; metadata never claims unconfirmed success. |
| Firmware update fails | Previous bootable firmware and current artwork remain recoverable. |
| AI provider fails | Existing masters/results remain; no automatic provider switch. |

## Security boundary

The paired host is trusted to create artwork for frames. The LAN is untrusted.
Discovery reveals minimal metadata; exploration and all mutations require a
paired identity. The frame verifies content size, type, digest, dimensions,
profile, and authorization before storage or activation.

## Non-goals

Frameshift is not a cloud photo service, smart display dashboard, signage
platform, social network, remote desktop, live canvas, video player, animation
system, audio device, or universal electronics board.
