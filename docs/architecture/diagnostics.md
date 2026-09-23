# Host Diagnostics Contract

**Status:** normative software design; targets require platform qualification

## Signals and privacy

Audit, logs, and metrics answer different questions. Audit records a durable
state change or terminal command disposition in the same transaction as that
change. Logs explain a causal sequence and may be sampled or dropped. Metrics
aggregate bounded measurements and never establish whether one frame actually
displayed an image. The authoritative delivery state is the source for that
claim.

Every admitted command gets a correlation ID. Each delivery attempt gets its
own attempt ID linked to the command. Persist IDs in receipts and relevant
audit/state rows; carry them in logs, never as metric labels. Record UTC event
time and monotonic process duration separately. End-to-end delivery duration
across sleep or restart uses persisted timestamps and records clock uncertainty.

Default diagnostic fields are enum outcome, stable operation name, safe error
code, revision, duration, byte count, and random correlation ID. No tokens,
private keys, artwork bytes, prompt text, raw source paths, full URLs, or raw
Thing Descriptions. Digest and device identifiers require an explicit
redaction policy for export. Diagnostic failures cannot change domain outcomes.

## Metric catalog

Each metric has a documented owner, event, type, unit, allowed dimensions,
aggregation, retention, and coverage rule. Names are versioned. Allowed
dimensions are bounded enums such as `operation`, `outcome`, `delivery_mode`,
and `error_class`; unknown values map to `other`. Frame IDs, command IDs,
artwork digests, provider inputs, and network addresses are forbidden labels.

| Metric family | Measurement | Source of truth |
| --- | --- | --- |
| Command | completed/replayed/unknown count and completion duration | IPC admission and durable receipt |
| Render | duration, cache hit, timeout, worker restart | Rendering job lifecycle |
| Delivery | intent count, pending age, confirmation duration, retry/reconcile and unknown count | Durable Delivery state and frame confirmation |
| Storage | transaction duration/busy result, object bytes, WAL bytes | SQLite owner and filesystem sampling |
| Runtime | core restart, process memory, queue depth, diagnostic drops | Supervisor and bounded samplers |

The primary service indicator is the fraction of eligible updates confirmed
displayed within a target window. Report awake push and sleeping pull
separately; sleeping contact cadence is part of the denominator definition.
Also report an explicit unknown outcome rate and measurement coverage. Choose
numeric objectives only after measurements on the exact supported hardware
and workload. A queued or transport-accepted update is never counted as
displayed.

Named `:telemetry` events are the portable instrumentation boundary.
`Telemetry.Metrics` definitions require a real reporter. Handler work is
constant and nonblocking: enqueue a bounded message to a supervised collector,
never perform SQL, network, or log formatting in the caller. The collector
maintains fixed-size histograms and bounded enum dimensions, batches rollups
through the existing single writer, and reports its own dropped-event count.
The proposed retention budget is minute buckets for 24 hours and hour buckets
for 30 days, with a 32 MiB local metric ceiling; implementation must measure
and enforce this bound. Each query includes a coverage interval and reset
marker so missing observations cannot be represented as zero.

## Log and audit access

The macOS shell logs with Swift `Logger`. It supervises the bundled core and
drains its stdout/stderr pipes. A bounded parser forwards only allowlisted,
structured core records to Apple unified logging under subsystem
`io.frameshift.app`, with stable categories; arbitrary third-party output is
discarded. The shell records dropped records. Pipe and bridge failure must not
block a command. A small rotating OTP file captures sanitized critical
failures when the bridge is unavailable. Console.app and `/usr/bin/log` are the
macOS log readers; the product does not build a logs UI. Apple controls
unified-log persistence, so it is not the audit store. Linux uses a journald
adapter or an equivalent bounded local sink with `journalctl` access.

`frameshiftctl diagnostics health|metrics|audit` is a read-only client of the
versioned local IPC contract. Responses are size-limited and audit queries use
stable pagination and explicit retention metadata. A standalone client cannot
reuse the menu shell's in-memory bootstrap token. Its separate read-only
authentication must verify the Unix peer identity and private socket directory
on each platform. Mutation IPC retains its boot token. The CLI does not open
the database or read the Apple unified log store programmatically. Explicit
local export is redacted, bounded, and records its own audit fact.

## Failure and acceptance cases

- Reconstruct a failed update from command ID through render, durable intent,
  network attempt, and frame-confirmed or pending state after core restart.
- Verify no secret or private content appears in Console, fallback logs,
  metrics, audit export, or error responses.
- Crash and restart the log bridge and metric collector during delivery;
  product state remains correct and diagnostics report loss/coverage.
- Prove the metric and fallback-log disk ceilings and idle CPU/wakeup budget on
  macOS and a supported Linux/Pi host.
- Verify the CLI rejects an unauthenticated or wrong-user peer, never permits
  mutations, and returns deterministic pagination under concurrent writes.

Primary upstream references: [Apple unified logging](https://developer.apple.com/documentation/os/logging/),
[OSLogStore local-store permissions](https://developer.apple.com/documentation/oslog/oslogstore/local%28%29),
[Telemetry handler semantics](https://telemetry.hexdocs.pm/),
[Telemetry.Metrics reporters](https://telemetry-metrics.hexdocs.pm/Telemetry.Metrics.html),
and [Google SRE service indicators](https://sre.google/workbook/implementing-slos/).
