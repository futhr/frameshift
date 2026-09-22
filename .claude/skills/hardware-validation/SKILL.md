---
name: hardware-validation
description: Apply automatically when selecting, buying, assembling, or testing a Frameshift panel, controller, PSU, cable, surface treatment, enclosure, or complete frame. Resolve the exact revision, record the full configuration, define safe measurement boundaries, and distinguish sourced limits from measured results.
user-invocable: true
argument-hint: "[component, build, or validation question]"
---

# Hardware validation

This skill produces a sourcing comparison, validation plan, or build record. It
does not authorize a purchase and does not replace electrical, mechanical,
thermal, fire, or product-safety review.

## Before selection

1. Identify the requirement and the document that owns it.
2. Resolve the exact manufacturer part number, board or panel revision,
   firmware, connector, cable, controller, waveform or scan mode, and supplier.
3. Obtain primary data sheets, drawings, integration manuals, and controller
   compatibility records. Record revision and retrieval date.
4. Build a compatibility matrix. Treat blank fields as `unverified`, never as
   compatible.
5. Record price, currency, tax and shipping basis, supplier region, stock state,
   minimum order quantity, and observation date separately from technical fit.
6. State the disqualifiers and required pre-purchase checks.

## Configuration record

Record enough detail to reproduce the result:

- panel/module and controller part numbers and revisions;
- firmware, library, host, protocol, render settings, refresh/scan mode, and
  brightness;
- PSU model/rating, voltage at source and load, wiring gauge/length,
  distribution, fuse/protection, grounding, and connectors;
- panel arrangement, carrier, surface treatment, passe-partout, enclosure,
  ventilation, cable bends, mounting, and service clearances;
- instruments, their range/accuracy when material, sample interval, ambient
  conditions, warm-up time, artwork/test pattern, and test duration.

Do not expose serial numbers, network credentials, or private supplier account
data.

## Measurements

Choose the relevant measurements and define pass conditions before testing:

- active area, outline, assembled depth, connector and bend clearance, weight,
  mounting, access, and deflection;
- idle, typical artwork, transition, and worst-case current and power;
- supply voltage at the load, voltage drop, inrush, fuse behavior, and cable or
  connector heating;
- steady-state temperatures at named points and ambient temperature;
- refresh rate/time, flicker, scan artifacts, ghosting, dropped frames, and
  recovery from reset or power loss;
- brightness, contrast, color or palette error, viewing angle, glare, surface
  artifacts, and appearance under recorded lighting;
- network interruption, host sleep, corrupt or incomplete transfer, local
  persistence, and last-valid-artwork behavior.

Never exceed published absolute limits. Stop a test when a predeclared thermal,
electrical, mechanical, odor, smoke, instability, or instrument-limit threshold
is reached. Do not prescribe mains wiring or unattended-use safety conclusions
without competent review.

## Result states

- **Candidate**: source evidence warrants a prototype test.
- **Prototype-selected**: selected for a bounded build; compatibility remains
  conditional on the stated checks.
- **Validated**: the recorded configuration passed every stated condition.
- **Rejected**: a named disqualifier or failed condition rules it out.
- **Deferred**: a dependency, source, device, or safe test setup is unavailable.

Store external research in `docs/research/`. Put stable shared constraints in
`docs/hardware/` and update the owning frame document only after evidence
supports the change. Link raw logs, images, and scripts rather than manually
transcribing large result sets.
