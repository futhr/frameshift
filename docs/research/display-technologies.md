# Display Technology Comparison

**Research snapshot:** 2026-09-22

**Decision:** Paper, Photo, and Pixel are independent media. A builder may start
with any one of them and does not have to build the others.

The shared product is the still-image library, rendering pipeline, protocol,
and minimal host experience. The display technologies do not share a credible
electrical design or power claim.

## Decision table

| Property | Paper / color e-paper | Photo / matte LCD | Pixel / HUB75 RGB |
| --- | --- | --- | --- |
| Visual character | Reflective print-like surface | High-resolution luminous photograph | Coarse luminous pixel artwork |
| Image with electronics off | Yes | No | No; continuous scan is required |
| Practical battery-only wall use | Strongest candidate | Poor | Not credible at the proposed size |
| Continuous power while visible | No | Yes | Yes, with high peak current |
| Default simulator candidate | Waveshare 13.3-inch E6, 1600×1200 | BOE MV270QHM-N40 P1, 2560×1440 | Six Waveshare P3 modules, 192×128 logical |
| Primary risk | controller/waveform, refresh time, sourcing | panel-controller match, depth, heat, power | scan timing, signal integrity, power distribution, heat |
| “No visible cable” route | battery and deep sleep | concealed feed, powered mount, or routed cable | concealed high-capacity feed or routed cable |

“Passive” means the visible image survives with electronics unpowered. Only
the Paper path currently meets that definition. A hidden cable or powered mount
can improve the Photo and Pixel installation without making either passive.

## Paper: reflective color e-paper

Paper is the natural choice when cable-free installation, no emitted light, and
image retention matter most. The candidate panel surface can be extremely thin,
but driver board, battery, radio, flash, connectors, backing, and protection
still determine the installed depth.

The tradeoffs are slow full refresh, constrained palette and temperature range,
fragile glass/FPC construction, and uncertain large-format procurement. A
13.3-inch E Ink Spectra 6 development assembly is currently documented well
enough for a prototype; A2-like panels remain a sourcing and controller research
track. See [hardware platform research](hardware-platforms.md) and the
[Paper frame specification](../frames/paper-frame.md).

## Photo: matte LCD

Photo is the choice when photographic detail, predictable color, and large
commodity panels matter more than passive operation. The intended appearance
depends on restrained luminance, a matte or anti-glare front, calibration, a
physical mat, and a real frame—not just the LCD specification.

It needs continuous panel, timing-controller, and backlight power. A donor
monitor is one reversible prototype option; a builder may instead start with an
exact raw-panel/controller pair. Neither route is the required first build. The
reference cannot be named until the received panel revision, controller match,
depth, heat, and power path are measured. See the
[Photo frame specification](../frames/photo-frame.md).

## Pixel: HUB75 RGB matrix

Pixel is a separate artistic medium, not a low-cost Photo substitute. The host
must intentionally simplify, resample, palette-shape, and preview artwork for a
coarse logical raster. The frame repeatedly scans one static buffer because of
the panel electronics; that scan is not animation.

The difficult work is timed parallel output, module-revision mapping, level
translation, current distribution, brightness enforcement, electromagnetic
behavior, and heat. The controller is unselected. Frameshift is researching a
non-Raspberry DMA-capable MCU with Zig firmware; an STM32H7-class part is only a
feasibility candidate. See the [Pixel frame specification](../frames/pixel-frame.md).

## Prototype guidance

Prototype-first is a recommendation for reducing waste within the path a
builder chooses, not a repository gate or a cross-frame roadmap:

- Paper builders can measure a complete wake/download/refresh/sleep cycle and
  total stack depth before committing to a battery or custom PCB.
- Photo builders can measure a donor or raw-panel assembly before designing a
  final carrier and power mount.
- Pixel builders can characterize one module before committing to full-array
  power distribution, while still starting at full scale if that better serves
  their experiment.

Evidence from a smaller or rougher assembly does not validate a finished frame.
Every proposed reference still needs its own exact-revision, full-stack tests.

## Shared conclusion

Do not force the three media behind identical electronics. Standardize the
capability model, immutable artifact semantics, failure behavior, and host
experience. Let each display adapter and build record state the real geometry,
power class, refresh behavior, and validation evidence.
