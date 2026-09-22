# Hardware Validation Plan

**Status:** procedure template

**Rule:** exact revisions pass tests; product families do not

Builders may choose any frame path and any sensible prototype scale. Run the
shared tests that apply plus the selected frame's tests. A failed test is useful
evidence and must not be softened into “basically works.”

## Evidence levels

| Level | Meaning | May support |
| --- | --- | --- |
| E0 | Marketplace/community claim only | Research lead |
| E1 | Primary data sheet/manual for exact named part | Candidate and safe bench limits |
| E2 | Exact received revision inspected and basic function reproduced | Prototype BOM |
| E3 | Frameshift test passed with logs/photos/measurements | Validated prototype claim |
| E4 | Multiple units/lots pass environmental and fault tests | Reference revision candidate |

No price, availability, compatibility, or power claim is timeless. Every source
record includes retrieval date and region.

## Build record layout

Store one directory per build when implementation begins:

```text
validation/<build-id>/
  README.md              purpose, exact revisions, deviations, result
  bom.md                 supplier links, order date, markings, licenses
  stackup.md             depth map, connector/cable/mount measurements
  power.csv              timestamped operating-state measurements
  thermal.csv            probe locations, ambient, temperatures
  test-results.md        test IDs, pass/fail, observations
  photos/                front, rear, markings, fixtures, failures
  firmware/              immutable build IDs and configuration only
```

Spreadsheet/CSV artifacts must be editable without a Python workflow.

## Shared tests

### H-001 — Incoming inspection

Record package damage, labels, PCB revision, panel markings, driver ICs,
connectors, visible defects, dimensions, and mass before power. Compare every
electrical limit with primary documentation. **Pass:** exact identity and safe
bench setup are known. **Fail:** conflicting/absent identity or physical damage.

### H-002 — Open-bench bring-up

Use a current-limited supply on a non-combustible fixture. Start below the
documented ceiling where the interface permits. Run vendor-safe static patterns,
then Frameshift artifacts. **Pass:** correct orientation, mapping, color order,
and stable operation without unexplained current or heat.

### H-003 — Artifact rejection

Send wrong digest, length, dimensions, profile, truncated bytes, and valid bytes
for another hardware revision. **Pass:** none reaches the display adapter and
current artwork remains intact.

### H-004 — Atomic state and power interruption

Interrupt power repeatedly during temporary write, digest verification, desired
metadata write, physical update, current metadata commit, garbage collection,
and firmware update. **Pass:** device boots, authenticates, and retains or
recovers a verified current/previous asset without claiming a failed update was
displayed.

Use at least 100 randomized interruptions before E3. Panel-specific electrical
limits may require a controlled interruption fixture rather than hand switching.

### H-005 — Network loss

Remove Wi-Fi/host at discovery, TLS, manifest, partial transfer, activation, and
ack stages. **Pass:** bounded backoff, no credential leak, no blanking, eventual
convergence after restoration.

### H-006 — Identity and authorization

Try unpaired discovery, wrong client certificate, replayed bootstrap secret,
pairing outside physical pair mode, revoked host, and factory reset. **Pass:**
only the physically authorized flow succeeds and secrets are absent from logs.

### H-007 — Stack depth

Measure a grid across the complete mounted assembly, not a single component.
Include rear cover deflection, connector exit, minimum cable bend, mount, and
fastener heads. **Pass:** the build meets its declared target with serviceable,
unstressed parts. The numeric target belongs to that build record.

### H-008 — Thermal soak

Place probes at controller, regulator/converter, panel driver, connector,
battery, wood/backing hot spot, and ambient. Run the worst valid still/brightness
until temperatures stabilize, then run fault/current-limit cases. **Pass:** all
parts remain within derated limits and touch/material temperatures are acceptable.

### H-009 — Recovery update

Install a valid signed update, reject invalid signature/version, interrupt an
update, and boot a deliberately unhealthy new slot. **Pass:** automatic or
physical recovery returns to known firmware without losing current art.

## Paper tests

### P-001 — Palette chart

Render solid patches, gradients, neutrals, skin-tone references, fine lines,
text only as a diagnostic, and multiple dither modes. Photograph under fixed
illuminant/exposure with a color reference. Record palette/profile revision.

### P-002 — Full energy cycle

Measure coulombs/energy for deep sleep, wake, Wi-Fi association, no-change
check, full transfer, refresh, ack, and return to sleep at low/room/high allowed
temperature. Repeat enough times for confidence intervals. Battery estimates
use this distribution plus measured quiescent current and self-discharge.

### P-003 — Retention

Remove all power after a successful refresh. Inspect at one hour, one day, one
week, and longer if practical. **Pass:** no controller power is required to
retain the intended image.

### P-004 — Fragility/service

Cycle backing removal and reassembly without bending panel/FPC beyond the
documented envelope. Inspect for pressure artifacts, glass damage, connector
creep, and mat contact.

## Photo tests

### F-001 — Boot-to-art

Cold boot and brownout recovery show the retained still without desktop,
cursor, console, input banner, logo, screensaver, or transient unrelated image.

### F-002 — Optical behavior

Measure/record luminance range, black appearance in ambient light, glare,
viewing angle, uniformity, color/profile behavior, and mat shadow. Compare any
surface treatment before irreversible lamination.

### F-003 — Continuous power

Measure on, restrained-brightness, blank-but-on, controller sleep, and hard-off
power. Verify scheduled off/on restores the retained still and does not require
the Mac.

### F-004 — Donor/raw revision

Document exact internal panel/controller and repeat basic tests on a second unit
before claiming the retail model is reproducible.

## Pixel tests

### X-001 — Mapping and timing

Use per-pixel, row/column, module-boundary, primary, and bitplane patterns.
Record logical-to-physical mapping, scan mode, driver initialization, minimum/
typical refresh, color depth, and clock. Test while network and flash are busy.

### X-002 — Flicker

Observe with multiple people and cameras/shutter speeds at supported brightness.
Record refresh and rolling-band behavior. Static content still requires
continuous scan without objectionable flicker.

### X-003 — Power envelope

Measure black, each full primary, 25/50/100% white, representative art, boot,
network load, and corrupt/all-white input with the hardware cap. Record voltage
at every panel and temperature at every branch connector.

### X-004 — Array scaling

Repeat timing, uniformity, power, and thermals on the intended complete module
count. A single-panel pass does not qualify a six-panel array.

## Result language

Use: “Exact assembly X passed test H-004 under conditions Y on date Z.” Avoid:
“this panel is reliable,” “runs cool,” “low power,” or “works with Frameshift”
without the test, conditions, and revision.
