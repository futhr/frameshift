# Host Diagnostics Research

**Observed:** 2026-09-23
**State:** sourced design evidence; installed behavior requires qualification

## Existing implementation

At the research baseline, the installed shell directed its bundled core's
stdout and stderr to the null device. The core configured console logging and
contained almost no operational instrumentation. SQLite had an `audit_entries`
table but no paginated read or command correlation field. The local mutation
IPC used a per-launch token held by the Swift shell; a standalone CLI could
not reuse it. These historical code observations are not release evidence.

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

A shell-owned Swift pipe bridge now translates allowlisted structured core
records to Apple unified logging while the core remains portable. A packaged
ad-hoc-signed app has shown command records through `/usr/bin/log`; unit checks
now reject unsafe public fields and the bridge bounds partial lines and record
batches. Process death, backpressure, signed distribution, and quiet idle
behavior still need qualification. Apple does not promise fixed unified-log retention, so audit
remains in the application store. The implemented local reporter bounds its
dimensions and row count; physical disk and idle costs still need measurement.
The installed Mac CLI uses a separate peer-authenticated socket because the
mutation token is private to the shell. Linux peer-credential behavior and
installed lifecycle still need qualification. These observations do not
validate a release.

On 2026-09-24, the local `elixir:1.20.4-otp-29-slim` arm64 Linux container
(multi-platform image index `sha256:3898ffe18d695e770239e4b342dc6b83136f52da0a37df2298083c03068cfd4e`)
reported `{:error, {:invalid, ...}}` for the named OTP `:peercred` option on a
connected Unix stream socket, while Linux native `{SOL_SOCKET, SO_PEERCRED}`
returned the 12-byte PID/UID/GID structure. This supports exercising the
adapter's native fallback in a container contract test. It does not establish
the permissions of an installed service or admission of another user's group
membership.
The pinned container contract subsequently read UID 0 for its root client and
UID 65534 for a `runuser` client over actual Unix stream sockets on arm64.
The amd64 image could not start OTP under the local Docker Desktop emulation
(`prim_tty` NIF startup failure); the native amd64 CI lane is required for
that architecture and remains unobserved here.
