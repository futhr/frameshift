# Open Research Questions

Resolved decisions live in the [decision ledger](../decisions/README.md). This
file contains only questions whose answers require a measurement, exact part,
security review, or explicit later product choice.

## Cross-cutting blockers

- Which MCU/module provides Wi-Fi, mutual TLS, secure identity, recoverable
  updates, adequate storage, and a reproducible Zig-oriented build with no
  Python dependency?
- What exact commissioning transport works across selected hardware: temporary
  USB, BLE, temporary access point, or a subset?
- Does the v0.1 QR/bootstrap/mTLS design pass independent security review?
- What are the exact depth, mass, thermal, and serviceability budgets after
  representative wood, mat, backing, mount, and cable bends are included?
- Which no-visible-cable mounting/power options are safe, legal, thin, and
  visually acceptable for powered frames?
- Which draft artifact media types and binary headers should be frozen for
  conformance fixtures?
- What repository license is compatible with the intended hardware, firmware,
  app, and LGPL dependencies?

## Software and host

- Can a notarized macOS bundle reliably supervise an Elixir release and Zig
  worker through login, upgrade, crash, sleep, and logout?
- Which SQLite/Elixir boundary gives the simplest durable single-owner store?
- What is the oldest supported macOS version for current Vision,
  MediaGenerationKit, MenuBarExtra, and ServiceManagement behavior?
- Does MediaGenerationKit's LGPL-3.0 distribution and model-license set fit the
  final project license and packaging?
- When, if ever, does current Ollama image generation become stable enough to
  enable by default?
- What default trash/cache quotas protect user work without unbounded storage?

## Frame Protocol

- How are client certificates rotated and revoked without losing a headless
  frame?
- Does v1.0 support multiple owners, or one owner plus delegated senders?
- Which TLS implementation and cipher/profile fit the selected MCU?
- Are large asset transfers always single-request, or is a resumable profile
  worth the flash/journal complexity?
- What wake/backoff policy gives a sleeping frame reasonable freshness without
  wasting battery when the Mac is unavailable?
- Which physical-interruption cases require the panel to be refreshed again,
  especially E6 color e-paper?

## Paper

- Select and qualify the exact thin controller and flash/power design.
- Reverse/verify the exact E6 palette packing and split-controller sequence from
  primary data and logic traces.
- Measure full-cycle energy and choose a battery/charging strategy, if desired.
- Determine acceptable refresh dwell and temperature limits from real art.
- Revalidate 28.5-inch/A2-like panel, controller, waveform, price, shipping,
  replacement, and minimum-order evidence.

## Photo

- Select one currently available donor monitor and record its exact internal
  panel/controller revisions.
- Select or design a thin controller that can retain one QHD still without a
  general-purpose Linux board.
- Compare donor versus raw-panel depth, heat, reliability, and replacement.
- Measure which matte/protective surface and luminance best read as art.
- Choose a concealed-power/mount option without making it a hard requirement
  for builders.

## Pixel

- Select and prove a non-Raspberry MCU with a Zig timed-parallel/DMA driver for
  the exact P3 module revision.
- Determine one versus three chain topology, bit depth, refresh, and signal
  integrity at 192×128.
- Measure representative indoor power and set a defensible hardware ceiling.
- Select external supply voltage, local conversion, fusing, connectors, and
  thermal path.
- Compare bare pixels, diffuser, textile, canvas, and passe-partout treatments.
