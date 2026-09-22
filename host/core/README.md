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
- startup reconciliation for interrupted active/trash file moves.

Run the complete core check from this directory:

```sh
mise exec -- env -u MIX_HOME -u MIX_ARCHIVES mix check
```

The explicit environment cleanup avoids inheriting a stale developer-level Mix
installation. It does not affect the application runtime.
