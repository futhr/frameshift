# Hardware Platform Research

**Research date:** 2026-09-22

**Hard constraints:** the reference object is a thin picture frame, not a
computer enclosure, and Raspberry Pi hardware is excluded. No visible
cable is a high-priority industrial-design goal, not a pass/fail requirement.

## Power feasibility

“No cable,” “no visible cable,” and “passive” are different requirements.

| Frame | Image with electronics off | Battery-only practicality | Continuous input power | Honest classification |
| --- | --- | --- | --- | --- |
| Paper / e-paper | Yes | Strong candidate | Only while waking and refreshing | Cable-free, passive between changes |
| Photo / IPS | No; backlight and timing controller stop | Poor for wall art | Required whenever visible | Thin emissive, concealed power |
| Pixel / HUB75 | No; LEDs stop immediately | Impractical at A2-like size | Required whenever visible | Thin emissive, high-current concealed power |

The Paper frame can be truly cable-free with a battery. Photo and Pixel can
have **no visible cable** only when the installation supplies hidden power—an
in-wall low-voltage feed, a powered mounting rail/contact plate, or a cable
concealed by the wall/frame. Wireless power does not make them passive; it adds
conversion loss, alignment constraints, and heat.

If cable-free passive operation were ever made mandatory for every Frameshift
product, Photo and Pixel would need to be removed or reinterpreted with
bistable reflective technology. It is not currently mandatory.

## Mechanical budget

Component thickness alone is not installed depth. Each prototype record must
include panel, controller, connector height, cable exit and bend radius,
battery, converter, backing, mounting clearance, airflow, and wood rebate.

Initial targets are measurement hypotheses, not guarantees:

| Frame | Display-plane target | Local electronics pocket | PSU location |
| --- | --- | --- | --- |
| Paper | panel + support under 4 mm | under 10 mm in a localized rear pocket | thin battery in rear pocket |
| Photo | raw panel under 15 mm | under 12 mm beyond panel, placed behind mat/rebate | external or wall-contact supply |
| Pixel | module depth to be measured | controller under 8 mm; airflow separate | remote 24 V-class supply plus local conversion candidate |

The final outside depth follows measurement. A reference fails if it meets the
electronics target only with unsafe cable bends, exposed boards, trapped heat,
or a bulky box attached to the center of the backing.

## Paper candidate

### Display

The strongest currently documented prototype is Waveshare's 13.3-inch E Ink
Spectra 6 HAT+ (E):

- 1600×1200, E6 full color;
- 270.40×202.80 mm active area;
- 284.70×208.80×0.85 mm panel outline;
- 65.00×30.50 mm development driver board;
- SPI mode 0, 3.3/5 V;
- vendor-quoted 19 s full refresh and under 0.5 W typical panel refresh;
- 0–40 °C operation.

Source: [Waveshare manual](https://www.waveshare.com/wiki/13.3inch_e-Paper_HAT%2B_%28E%29_Manual).

The 0.85 mm panel supports a thin object, but the HAT is development hardware,
not a final mechanical answer. Its stacking headers, connectors, and cable
orientation must be replaced by a low-profile driver PCB only after the vendor
schematic and panel protocol are verified.

### Controller and energy strategy

The controller must be MCU-class and power-gated:

1. RTC/button wakes the controller.
2. Radio associates and authenticates.
3. The frame asks the paired host/outbox for its desired digest.
4. If unchanged, it records health and returns to deep sleep.
5. If changed, it downloads to an inactive flash slot, verifies digest and
   format, refreshes the panel, marks current, and sleeps.

An ESP32-S3-class chip demonstrates the relevant scale: Espressif documents
single-digit-microamp chip deep sleep with RTC memory configurations, although
module PSRAM, regulators, flash, battery monitor, and development-board LEDs can
raise whole-board sleep current dramatically. Source: [ESP32-S3 datasheet](https://documentation.espressif.com/esp32_s3_datasheet_en.pdf).

That is evidence for the power class, not a selected controller. Selection is
blocked on a Zig-compatible, reproducible, no-Python build plus Wi-Fi, mTLS,
secure identity, SPI throughput, and measured whole-board sleep current.

The panel-only refresh claim corresponds to less than 0.003 Wh at 0.5 W for
19 seconds, but it excludes controller, driver losses, radio association,
battery conversion, retries, and temperature effects. Battery life must be
calculated from measurements of the entire frame over a real wake/update/sleep
cycle. No months-of-life claim is allowed before that test.

### Large-format future

E Ink positions Spectra 6 for full-color retail/signage displays. A 28.5-inch
2160×3060 Sharp/Spectra-class panel is A2-like, but public controller,
procurement, waveform, temperature, and price evidence is insufficient for a
reference BOM. It stays a future sourcing track, not a prototype dependency.
Source: [E Ink Spectra 6](https://www.eink.com/brand/detail/Spectra6).

## Photo candidate

A raw 27-inch matte QHD panel gives A2-like wall presence but is not passive.
The BOE MV270QHM-N40 is useful geometry evidence: 2560×1440, 596.736×335.664 mm
active area, roughly 608.8×353.3×14.9 mm outline, anti-glare surface, WLED
backlight, and a multi-channel LVDS interface. The preliminary data sheet shows
separate panel and backlight/control requirements. Source: [mirrored MV270QHM-N40 preliminary data sheet](https://www.panelook.com/upload/202311/MV270QHM-N40_Rev.P1_20190125_202311014949.pdf).

It is not yet the purchase recommendation. Raw LCD part revisions and generic
controller boards are easy to mismatch. One lower-risk mechanical prototype
option is a documented, externally powered 27-inch matte QHD donor monitor
whose exact panel and controller are verified before de-casing. A builder can
instead start from a raw panel/controller pair when thinness and interface
bring-up are the questions they want to test. A Philips reference data sheet
reports about 23 W typical on-power for one QHD IPS model, which illustrates
why battery-only operation is not credible. Source:
[Philips 27-inch QHD product leaflet](https://www.documents.philips.com/assets/20230529/f326da3d6a284d2ba65eb01100f58d8a.pdf).

The long-term controller candidate is an ultra-thin embedded board capable of
holding a still framebuffer and driving the exact LVDS/eDP interface. It does
not need desktop compute. ESP32-P4 demonstrates that MCU-class parts now expose
MIPI DSI and can drive high-resolution panels, but current documented paths do
not prove compatibility with a 2560×1440 LVDS/eDP panel. Source:
[ESP32-P4 display interface data](https://documentation.espressif.com/esp32-p4_datasheet_en.html).

Until an exact panel/controller pair passes bring-up, the Photo frame is not
implementation-ready.

## Pixel candidate

Six Waveshare P3 64×64 HUB75E modules in a 3×2 physical grid produce a
576×384 mm active area and 192×128 logical pixels. Each module is specified as
192×192 mm, 1/32 scan, 5 V/4 A, and at most 20 W. The combined nameplate ceiling
is therefore 5 V/24 A or 120 W before controller and conversion losses. Source:
[Waveshare P3 64×64 specification](https://www.waveshare.com/wiki/RGB-Matrix-P3-64x64).

Art brightness should consume much less than all-white nameplate power, but PSU,
wiring, fusing, and thermal design must use measured worst cases plus margin.
Brightness is a safety/power setting with a hardware-enforced ceiling.

### Controller direction

The controller is deliberately unselected. The working direction is a
non-Raspberry MCU that can feed several synchronized parallel outputs from DMA
and timers while application code handles only infrequent still-image swaps.
An STM32H7-class part is a feasibility candidate because the family exposes
high-resolution timers, substantial DMA/display facilities, external-memory
interfaces, and cryptographic acceleration. Those capabilities do **not** prove
an exact HUB75 design, Zig support, Wi-Fi/TLS integration, or acceptable board
depth. Sources: [STM32H7 family](https://www.st.com/en/microcontrollers-microprocessors/stm32h7-series.html)
and [STM32H7 example catalogue](https://www.st.com/content/ccc/resource/technical/document/application_note/group0/6b/36/9b/ef/1d/91/4e/6b/DM00393275/files/DM00393275.pdf/jcr%3Acontent/translations/en.DM00393275.pdf).

An STM32 community driver demonstrates that two chained 64×64 HUB75E modules
can be driven from that MCU ecosystem, but it is C++/HAL, GPL-3.0, and not
Frameshift code. MicroZig demonstrates an active Zig embedded toolbox with some
STM32 support, while explicitly warning that its API is still in development.
Neither source establishes support for the exact H7 part or peripheral set
Frameshift needs. They are feasibility evidence and test-oracle material only.
Sources: [STM32 HUB75 driver](https://github.com/kostaman/HUB75) and
[MicroZig](https://github.com/ZigEmbeddedGroup/microzig).

A factory-programmed radio/network coprocessor is acceptable if its bounded
protocol, credential handling, firmware provenance, and recovery lifecycle are
documented. Whether the Pixel frame uses one integrated network MCU or a
display MCU plus such a coprocessor remains an open measurement-driven choice.
Three parallel chains of two modules are a candidate topology, not a frozen
requirement. This is the highest-risk hardware spike.

### Power placement

Do not route 24 A over a long 5 V wall cable. Candidate installation architecture
is a certified external higher-voltage DC supply, concealed low-voltage wiring,
and fused local conversion close to the panels. This reduces cable current but
moves converter heat into the frame, so it remains a hypothesis. An electrician
and local code review are required for concealed wiring; Frameshift will not
specify user-installed mains wiring.

## Controller selection gate

No MCU or module becomes reference hardware until it passes all of these:

- maximum assembled PCB height and connector/bend envelope;
- clean build from a pinned toolchain with no Python dependency;
- Wi-Fi association, reconnect, and local discovery behavior;
- TLS 1.3 or appropriate current TLS, mutual authentication, and key storage;
- two recoverable firmware slots or equivalent;
- two atomic asset slots plus current/previous metadata;
- measured idle, radio-on, transfer, refresh, and fault power;
- brownout and abrupt battery removal during every write phase;
- thermal test inside the actual wood/mat/backing stack;
- regulatory path for radio module, battery, charger, and external PSU.

## Prototype paths

Builders may choose any frame class; no universal build order is specified. A
recommended risk-reduction tactic is to use the smallest prototype that can
disprove the selected class's risky assumptions before buying premium hardware
or finishing an enclosure. It is not a participation requirement:

- **Paper:** a development mule that measures wake, transfer, refresh, sleep,
  and the complete battery/control-board depth.
- **Photo:** a donor-monitor or exact panel/controller mule that measures depth,
  heat, idle power, glare, and cable/mount options.
- **Pixel:** a one-module electrical mule that validates Zig timed-parallel/DMA,
  mapping, brightness, and power before a six-module power/mechanical build.

A software frame simulator and golden artifact set benefit every path but do
not block a builder from starting with the hardware they care about.
