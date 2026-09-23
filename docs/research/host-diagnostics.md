# Host Diagnostics Research

**Observed:** 2026-09-23
**State:** sourced design evidence; installed behavior requires qualification

## Existing implementation

The installed shell currently directs its bundled core's stdout and stderr to
the null device. The core configures console logging and contains almost no
operational instrumentation. SQLite has an `audit_entries` table but no
complete paginated read/export path or command correlation field. The local
mutation IPC uses a per-launch token held by the Swift shell; a standalone CLI
cannot reuse it. These are code observations, not release evidence.

## Platform and library findings

- Apple unified logging is available to native Mac code and is read with
  Console.app or the `log` command. Swift `Logger` supports subsystem/category
  classification and privacy controls. [Apple logging](https://developer.apple.com/documentation/os/logging/),
  [privacy controls](https://developer.apple.com/documentation/os/oslogprivacy).
- `OSLogStore.local()` programmatic access to the Mac's local store requires
  an admin account and the `com.apple.logging.local-store` entitlement. A
  normal app diagnostic reader cannot assume this path.
  [Apple OSLogStore](https://developer.apple.com/documentation/oslog/oslogstore/local%28%29).
- `OSSignposter` integrates short native intervals with Instruments. MetricKit
  provides daily OS performance reports on supported systems; neither is a
  portable, immediate view of cross-process frame delivery.
  [Apple signposts](https://developer.apple.com/documentation/os/recording-performance-data),
  [MetricKit](https://developer.apple.com/documentation/metrickit/metricmanager).
- Telemetry invokes handlers synchronously in the caller. Handlers must avoid
  blocking and may send data to a separate process. `Telemetry.Metrics` defines
  measurements; a reporter must actually aggregate them.
  [Telemetry](https://telemetry.hexdocs.pm/),
  [Telemetry.Metrics](https://telemetry-metrics.hexdocs.pm/Telemetry.Metrics.html).
- SQLite WAL has one writer, and `synchronous=FULL` syncs on each commit.
  Ecto SQLite3 defaults to a pool of five, deferred transactions, and
  `synchronous=NORMAL`. These defaults must be overridden if D-010 is later
  superseded. [SQLite WAL](https://www.sqlite.org/wal.html),
  [Ecto SQLite3](https://ecto-sqlite3.hexdocs.pm/Ecto.Adapters.SQLite3.html).
- User-centered service indicators should measure the fraction of outcomes
  that meet a defined experience, with separate latency and coverage measures.
  [Google SRE workbook](https://sre.google/workbook/implementing-slos/).

## Design inference and validation gaps

A signed long-lived Swift helper can translate structured core log records to
Apple unified logging while the core remains portable. This must be proven in
the bundled app, including helper crash, queue backpressure, code signing,
redaction, and quiet idle behavior. Apple does not promise fixed unified-log
retention, so audit must remain in the application store. A local metric
reporter needs bounded dimensions and a measured disk budget. A read-only CLI
needs separate peer authentication because the mutation token is private to
the shell; cross-platform peer-credential access and installed lifecycle need
an implementation spike. None of these design inferences validates a release.
