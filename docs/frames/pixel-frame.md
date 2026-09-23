# Pixel Frame — HUB75 Reference

**Status:** independent prototype path; controller spike required

Six Waveshare RGB-Matrix-P3-64x64 modules form the default manufacturer
candidate for the [networked simulator](../architecture/container-frame-simulator.md)
and six-panel prototype. Their exact PCB/driver IC revision, MCU, brightness
clamp, and full-array electrical behavior still require qualification.

## Purpose

Pixel treats coarse luminous pixels as the medium. A source becomes a deliberate
static graphic interpretation rather than a poor copy of a high-resolution
photograph. The frame has no animation or video mode.

## Candidate geometry

Six P3 64×64 modules at approximately 192×192 mm each, arranged 3×2, create an
active area near 576×384 mm and a logical raster of 192×128 pixels. This is
A2-like in presence, not ISO A2.

The dated module candidate is Waveshare RGB-Matrix-P3-64x64: 3 mm pitch,
1/32 scan, HUB75E, 5 V/4 A, at most 20 W per module, and at least 160° claimed
viewing angle. Source: [vendor specification](https://www.waveshare.com/wiki/RGB-Matrix-P3-64x64).

Driver-chip and PCB revisions matter even when the connector and marketing name
match. Record rear IC markings for every received batch.

## Controller direction

No controller has been selected. The reference direction is a non-Raspberry MCU
that can continuously emit HUB75 bitplanes through synchronized timers and DMA
without a Linux computer. Project-owned firmware is Zig. An STM32H7-class part
is a feasibility candidate because that family has timer, DMA, external-memory,
and cryptographic facilities; it is not a recommendation until an exact part
and toolchain pass the gates below. Candidate topology is three parallel chains
of two modules to protect refresh rate and color depth.

This is not yet validated. The spike must prove:

- exact MCU and board support in a pinned Zig/MicroZig toolchain with no Python;
- timed parallel output and DMA that remain stable under network/flash load;
- three parallel HUB75E outputs or a justified alternative;
- exact panel initialization and mapping;
- stable refresh above the measured flicker/camera target;
- double-buffered atomic still swap;
- hardware brightness/current clamp;
- network, TLS identity, flash slots, and signed recovery update;
- signal integrity through voltage translation selected for the exact MCU and
  panel levels.

ST's STM32H7 peripheral examples and the community STM32 HUB75 driver are
feasibility and timing references only. The latter is GPL-3.0 C++/HAL code and
is not approved for copying. MicroZig is still evolving and does not currently
prove the exact MCU, DMA, TLS, networking, and update combination Frameshift
needs. Sources: [STM32H7 examples](https://www.st.com/content/ccc/resource/technical/document/application_note/group0/6b/36/9b/ef/1d/91/4e/6b/DM00393275/files/DM00393275.pdf/jcr%3Acontent/translations/en.DM00393275.pdf),
[STM32 HUB75 research driver](https://github.com/kostaman/HUB75), and
[MicroZig](https://github.com/ZigEmbeddedGroup/microzig).

## Power

Six candidate panels have a combined documented ceiling of 5 V/24 A (120 W),
before controller and conversion losses. Indoor static art should run far below
full-white maximum, but the electrical system must survive a corrupt/all-white
frame at the enforced hardware ceiling.

The receiver keeps scanning a static buffer and swaps complete stills on a
user-selected local interval. A longer interval has no demonstrated power
benefit while the LEDs remain lit; brightness, current ceiling, and scheduled
off periods are the meaningful controls. The candidate advertises no
energy-based dwell suggestion. See
[display timing](../architecture/display-timing.md).

Required protections include:

- current-limited certified supply;
- branch fusing or protected distribution;
- wire, connector, copper, and ground paths rated for measured worst case;
- power injection that avoids brightness/color gradient;
- independent hardware brightness/current ceiling at boot and during faults;
- temperature monitoring/cutback if measurements justify it;
- guarded rear electronics and strain relief.

Zero visible cable is a mounting priority, but a battery is not credible at
this area/power. Long 5 V cable runs are also undesirable because of current and
voltage drop. Remote higher-voltage supply with local conversion is a candidate
only after converter loss, heat, depth, and code-compliant wiring are measured.

## Artifact profile

The host sends one exact static logical raster, likely packed RGB565 or another
advertised fixed profile. Module topology and serpentine mapping belong to the
display adapter; the host sees logical 192×128 geometry.

Host rendering owns composition, simplification, downsample, palette treatment,
dither/cluster cleanup, and target preview. Hardware applies final gamma and
brightness/current limits. The frame continuously refreshes the same still
because HUB75 electronics require scanning; that is not content animation.

## Prototype evidence

Start at any scale appropriate to the builder, but do not infer the six-panel
result from a single module without later full-array tests. Record:

- exact pixel mapping, driver IC, scan mode, channel order, and color artifacts;
- minimum/typical refresh and flicker under network/flash load;
- power for black, channel primaries, 25/50/100% white, representative art, and
  enforced maximum brightness;
- connector and distribution temperature over a multi-hour worst-case test;
- brightness uniformity across all modules and injection points;
- controller, level shifter, ribbon, power connector, and ventilation depth;
- recovery from controller crash, corrupt artifact, brownout, and update;
- confirmation that only static still swaps are accepted.
