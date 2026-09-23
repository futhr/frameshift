# Networked Frame Simulator

**Status:** specified software acceptance fixture; physical behavior remains unvalidated

## Purpose and evidence boundary

A frame receiver runs in a separate Linux container and contacts the real host
outbox over mutual TLS. The host and receiver share no process memory or
simulator state. The receiver verifies the host identity, manifest, exact asset
digest and `Content-Digest`, persists the asset and current reference, then
acknowledges the manifest revision. Repeated contact, process restart, and
one-shot faults must preserve the last confirmed image and host custody.

The container represents the protocol and persistence boundary. It cannot
prove a display waveform, LVDS timing, HUB75 signal integrity, power draw,
temperature, retained optical image, or a production credential store. Its
artifacts remain explicitly named software surrogates until exact panel wire
profiles and controller revisions pass bench qualification.

The receiver must also execute the complete cached still playlist on its own
clock, including across host disconnection and receiver restart. Paper
scenarios enforce the candidate's 180-second minimum and model a provisional
six-hour suggested dwell without claiming measured battery life. Photo and
Pixel scenarios test discrete framebuffer swaps and do not infer energy saving
from longer dwell. The [display timing contract](display-timing.md) defines
deadline, acknowledgement, and failure behavior.

The current container fixture exposes the timing profile and tests a locally
installed complete playlist with deterministic RTC ticks in separate receiver
processes. It rejects missing/corrupt assets, a short dwell, and a mismatched
revision; a failed update retains the previous current asset. Protocol-driven
installation through the host outbox, host-side pinned-artwork preparation, and
physical RTC qualification remain separate release gates.

## Default manufacturer baselines

These are the **default candidate fixtures** for simulator and first prototype
research, not validated reference assemblies or a purchase instruction. A
builder can choose a different exact model after recording its capability
profile and test evidence. Vendor values are inputs to scenarios, not measured
Frameshift results.

| Class | Default candidate | Published geometry and behavior | Receiver model |
| --- | --- | --- | --- |
| Paper | Waveshare 13.3-inch e-Paper HAT+ (E), E Ink Spectra 6 | 1600×1200, 270.40×202.80 mm active; vendor 19 s full refresh; SPI, bistable; panel manual gives 0–40 °C absolute operating maximum | Sleeping pull contact, verified inactive asset, refresh pending until modeled busy completion; current image survives receiver power-off. The development HAT is a bench tool, not a selected thin controller. |
| Photo | BOE MV270QHM-N40 preliminary panel revision P1 | 2560×1440, 596.736×335.664 mm active; four-pixel-per-clock LVDS and separate WLED backlight; nominal 60 Hz timing | Continuous-power sample-and-hold still; persistent desired/current metadata survives restart, but visible pixels require panel/backlight power. Exact compatible controller remains unselected. |
| Pixel | Six Waveshare RGB-Matrix-P3-64x64 modules in a 3×2 grid | 192×128 logical raster, 576×384 mm active; each module is 1/32 scan HUB75E, 5 V/4 A and at most 20 W, so six-module nameplate ceiling is 5 V/24 A, 120 W before control losses | Continuous bitplane scan of one static framebuffer, with atomic still swap and current-limited brightness as required behavior. Exact driver IC, MCU, and safe current clamp remain unselected. |

Sources: [Waveshare E6 product and quoted timing](https://www.waveshare.com/product/displays/e-paper/epaper-1/13.3inch-e-paper-hat-plus-e.htm), [Waveshare panel manual](https://files.waveshare.com/wiki/13.3inch%20e-Paper%20HAT%2B/13.3inch_e-Paper_%28E%29_user_manual.pdf), [BOE-authored preliminary panel specification, mirrored by Panelook](https://www.panelook.com/upload/202311/MV270QHM-N40_Rev.P1_20190125_202311014949.pdf), and [Waveshare P3 specification](https://www.waveshare.com/wiki/RGB-Matrix-P3-64x64).

The BOE file is preliminary and the actual panel/controller pair is unverified.
The Waveshare E6 manual lists 0–50 °C as a feature but 0–40 °C in absolute
maximum ratings; the simulator and first bench gate use the stricter range.
The Paper developer board's [ESP32-S3 variant](https://docs.waveshare.com/ESP32-S3-ePaper-13.3E6)
is a research candidate only: its published module/memory descriptions are
inconsistent, and whole-board sleep, mTLS, recovery, and final thickness are
unmeasured. No controller is selected for any class.

## Receiver contract

The default test lane uses Docker as the container lifecycle runner, with a
one-shot receiver process and a fresh temporary data directory per scenario.
The container must have no host repository mount and no Docker socket. The
host supplies an ephemeral frame certificate, key, expected host SPKI pin,
outbox port, class, and fault selector. Credentials are test-only and removed
with the temporary fixture. A persistent data mount permits a second process
to prove restart behavior.

Each contact must:

1. connect with TLS 1.3 and its frame certificate, verify the host SPKI before
   sending an HTTP request, and fail closed on any mismatch;
2. fetch the exact current outbox manifest; treat `204` as no work;
3. fetch only its manifest's digest-addressed asset, enforce byte and profile
   ceilings, and verify both the SHA-256 address and `Content-Digest`;
4. stage verified bytes durably before changing display state;
5. advance current only after modeled display completion; a failed or
   interrupted refresh keeps the prior current and leaves the host manifest
   pending;
6. send an exact revision acknowledgement and confirm the host's response.

At minimum the fault matrix covers missed contact, altered transfer, storage
full, failure before display completion, failure after durable download, stale
acknowledgement, and restart. Test time may be accelerated; vendor-quoted Paper
refresh time remains a labeled scenario parameter and is never presented as a
measured duration. Photo and Pixel lose visible output when power is removed,
although their last verified asset remains recoverable from storage. A read-only
inspection contact checks this class-specific visibility rule without changing
the host manifest; a mismatched artifact profile must also fail closed.

This lane augments the in-process `Frameshift.Simulator` semantic tests. The
networked lane must run in CI where a Docker-compatible daemon is available;
the ordinary unit gate remains usable without Docker. A physical acceptance
claim still requires an independently built frame and the measurements in the
[hardware validation plan](../hardware/validation-plan.md).
