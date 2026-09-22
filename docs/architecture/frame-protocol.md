# Frame Protocol

**Status: draft research specification**

Frame Protocol is the stable seam between a FrameShift sender and a physical frame.

## Principles

1. Capability negotiation rather than model-name branching.
2. Local-network operation without required cloud infrastructure.
3. Content-addressable assets where practical.
4. Atomic updates: incomplete transfers never replace valid artwork.
5. Idempotent operations.
6. Authentication before accepting artwork/control commands.
7. Transport independence.

## Lifecycle

```text
discover -> pair -> capabilities -> render -> transfer -> verify -> commit
```

## Minimum capability model

A frame reports protocol version; pixel and physical dimensions; display technology; color model/palette; refresh characteristics; storage; local scheduling; animation/video/partial-refresh support; and power characteristics.

The schema must be extensible.

## Asset model

The host SHOULD send display-appropriate artifacts. Constrained devices should not perform expensive processing.

- IPS: negotiated raster/video formats.
- E-paper: pre-quantized/dithered raster matching the panel palette.
- HUB75: prepared RGB frames or compact negotiated representation.

## Candidate transport

The first prototype should investigate a small authenticated HTTP API over local Wi-Fi, with mDNS/DNS-SD discovery. This is deliberately easy to implement and inspect across Elixir, AtomVM, Nerves and native firmware.

These choices are candidates, not frozen requirements.

## Security

Frames must not accept unauthenticated LAN writes by default. First-use pairing and per-frame credentials/keys must be specified before the protocol is considered stable.
