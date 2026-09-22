# Frameshift core

This OTP application owns Frameshift's durable library and protocol state. It
does not own macOS presentation, Apple framework calls, raster transforms, or
frame electronics.

The current partial core implementation provides:

- embedded Frame Protocol v0.1 schema validation with no runtime schema fetch;
- an authenticated bounded Unix-socket command boundary whose fresh per-launch
  challenge is consumed from a one-use user-only bootstrap file;
- a single-owner SQLite library backed by immutable content-addressed files;
- canonical recipe identities and artifact cache relationships;
- master import, generated-variant lineage, labels, search, pinning, recoverable
  removal, and frame-reference protection;
- a durable paired-frame registry that retains the admitted universal Thing
  Description, capability instance, pinned server fingerprint, and opaque
  Keychain credential reference without storing private key material;
- startup reconciliation for interrupted active/trash file moves;
- durable per-frame sleeping outboxes with monotonic revisions, supersession,
  acknowledgement checks, and current/previous-known-good reference rotation;
- a supervised, single-job Zig renderer port with bounded framing, typed worker
  failures, explicit deadlines, diagnostic redaction, and restart-on-failure;
- a vendor-neutral profile compiler that selects advertised capability
  structure, creates a deterministic centered composition, and queues exact
  RGB24 output for sleeping pull targets;
- a versioned immutable master package that retains exact source bytes and
  canonical sRGB RGBA8, then binds durable masters to composition recipes,
  cached artifacts, outboxes, and simulator convergence;
- an explicit still-generation provider contract with preflight, deadline,
  canonical cache, provenance, and no retry or fallback;
- a persistent frame simulator with bounded storage, desired/current state,
  sleeping pull convergence, still playlists, redundant metadata records, and
  injected contact, transfer, display, storage, timing, and power-loss failures.

Run the complete core check from this directory:

```sh
mise exec -- env -u MIX_HOME -u MIX_ARCHIVES mix check
```

The explicit environment cleanup avoids inheriting a stale developer-level Mix
installation. It does not affect the application runtime.

Development and production startup supervise the worker at
`renderer/zig-out/bin/frameshift-raster` by default. Set
`FRAMESHIFT_RENDERER_PATH` to the bundled executable path when assembling a
release. Tests build and start the worker explicitly so a failed renderer build
or wire incompatibility fails the renderer integration tests directly.

Production releases require `FRAMESHIFT_RENDERER_PATH` at runtime rather than
capturing a build-machine path. The repository check assembles the OTP release,
starts it with isolated data, verifies a real Swift instruction/import round
trip, and terminates it cleanly. The packaging check embeds and supervises the
release and renderer inside the macOS app; Developer ID signing, hardened
runtime, notarization, and Service Management registration remain distribution
gates.
