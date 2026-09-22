# Frameshift core

This OTP application owns Frameshift's durable library and protocol state. It
does not own macOS presentation, Apple framework calls, raster transforms, or
frame electronics.

The current research-preview slice provides:

- embedded Frame Protocol v0.1 schema validation with no runtime schema fetch;
- a single-owner SQLite library backed by immutable content-addressed files;
- canonical recipe identities and artifact cache relationships;
- master import, generated-variant lineage, labels, search, pinning, recoverable
  removal, and frame-reference protection;
- startup reconciliation for interrupted active/trash file moves;
- durable per-frame sleeping outboxes with monotonic revisions, supersession,
  acknowledgement checks, and current/previous-known-good reference rotation;
- a supervised, single-job Zig renderer port with bounded framing, typed worker
  failures, explicit deadlines, diagnostic redaction, and restart-on-failure;
- a canonical RGBA8 research pipeline that binds source digests to composition
  recipes, cached artifacts, outboxes, and simulator convergence;
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
