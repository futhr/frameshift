# Host Diagnostics Contract

**Status:** normative software design; targets require platform qualification

This contract covers the local host and the separate companion-server extension
below. The local audit/SQLite writer and native OS log access remain authoritative
for frame operations. Server Ash domains and Refpath do not share those records.

## Companion server metrics and diagnostic access

The [build-platform contract](build-platform.md) requires first-class telemetry
with each implemented slice. Ash domains own domain transition/audit meaning;
Refpath owns runtime task/attempt/effect meaning. Emit measurements after the
corresponding durable fact, with explicit definitions preventing double counting
at both boundaries. Operational logs and metrics never establish an external
purchase, refund or physical display outcome.

Each versioned metric definition names its owner, trigger, count/gauge/histogram
type, unit, bounded dimensions, reset/coverage semantics, aggregation, retention,
sampling and resource budget. Use explicit duration units, currency for money,
and no aggregation across currencies without an attributed conversion. Record
queue age and absence of data separately from zero activity. Define alert
thresholds and service targets from measured baselines and product requirements
before production activation; a dashboard alone is not an operating contract.

| Family | Required measurements | Owner / first milestone |
| --- | --- | --- |
| Configuration | Compile/decision count by bounded outcome/reason, duration, stale-fact refusal and browser/server disagreement | Catalog & Compatibility / C |
| Verification | Queue depth/age, duration, bounds class, typed outcome, witness replay, cache hit/invalidation and resource refusal | Catalog verification / C |
| Independent journey | Successful/failed save/export/print preparation, latency and contract errors without recording private artwork or selected parts as labels | Web boundary / D |
| Research | Source freshness, candidate/admission/quarantine counts, eligible unattended completion denominator, manual interventions and pending exception age | Catalog + Refpath / E |
| Inference | Requests, input/output tokens, estimated/reserved/actual cost, retries, failures, abstentions, latency, model/task qualification results | Refpath provider boundary / E |
| Diagnostics | Investigation count/duration, tokens/cost, budget refusal, observation redaction failures, dropped telemetry and process/queue overhead | Beamlens host boundary / B/E |
| Purchasing | Confirmed/refused/unknown outcomes, unknown age, reconciliation, partial-order count, expired/revoked mandates and completion duration | Purchasing + Refpath / F |
| Money and care | Authorized/captured/refunded amounts, fee earnings/reversals, disputes, realized contribution, late parcels and case age | Payments & Fees / Fulfillment & Care / F |

Quality evaluation reports include false acceptance, coverage and calibration
with task/dataset version and uncertainty; production self-reported model
confidence is not a correctness measurement. Fixed allowlists bound model,
provider, operation, market and error labels. Customer/seller/order/frame IDs,
source URLs, prompts, full model digests, component IDs and arbitrary errors
belong only in authorized redacted trace/audit detail, never metric dimensions.

Export structured logs, metrics and traces through existing operational tools.
Use immutable domain audit for accepted terms, authority changes and confirmed
effects, with access and retention policies. Correlation links connect domain
commands to Refpath tasks/attempts/effects without creating a second effect
journal. Preserve native Console.app and `log` plus the local diagnostic CLI;
no custom log-reader UI is required for either product lane.

Beamlens is an explicit read-only server integration with one supervision owner,
bounded observations and operator authorization. Qualify generic skills and
Frameshift observations for compatibility, verifier/research queues and final-F
purchasing reconciliation. Its BAML provider configuration, resource ceilings
and inference spend are independently enforced and included in central usage
accounting. No diagnostic skill can mutate domain state or call purchasing tools.
Redact secrets, customer content and sensitive source material before inference.

Acceptance includes actor isolation, malicious/log-injected observations,
secret redaction, metric cardinality, sampling/coverage, provider timeout,
budget exhaustion, process failure and measured idle/load overhead. Normal
telemetry, alerts, logs and application actions must survive diagnostic failure.
Local Ollama incident reasoning requires its own evaluation; passing a simple
intent-routing evaluation does not qualify the diagnostic model.

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

For direct push and read-only reconciliation, the core records a random
128-bit attempt ID and hashed command correlation in an audit fact before
network I/O. It records the terminal attempt outcome afterward; a crash can
leave only the started fact and a pending intent. A confirmed display fact
carries the exact attempt ID that observed it. Native logs carry the same
allowlisted attempt ID, while the attempt-count metric uses only mode and
outcome dimensions. A transport timeout or lost response after the intent is
durable has an `unknown` attempt outcome: the request may have reached the
frame, so the host retains the pending intent and reconciles by read-only
observation. `failed` is reserved for a definite local or protocol refusal.
An unknown attempt never advances current display state and is counted
separately in audit, native logs, and the bounded attempt metric. A sleeping
pull contact spans separate manifest, asset, and
acknowledgement requests. Frame Protocol v0.1 has no contact ID echoed in the
acknowledgement, so revision and frame identity alone cannot attribute a
confirmation to one contact attempt. A versioned protocol change must carry
the host-issued random attempt ID from manifest to acknowledgement, reject an
unknown or mismatched ID, and keep an interrupted contact pending. Until that
round trip is implemented, pull attempts remain an explicit correlation gap.

Default diagnostic fields are enum outcome, stable operation name, safe error
code, revision, duration, byte count, and random correlation ID. No tokens,
private keys, artwork bytes, prompt text, raw source paths, full URLs, or raw
Thing Descriptions. Digest and device identifiers require an explicit
redaction policy for export. Diagnostic failures cannot change domain outcomes.

## Metric catalog

The catalog is version 2 when `unknown` is added to the direct-attempt outcome
dimension; historical version 1 rollups retain their stored labels. Each
metric has a documented owner, event, type, unit, allowed dimensions,
aggregation, retention, and coverage rule. The catalog definition is versioned.
Allowed dimensions are bounded enums such as `operation`, `outcome`, `delivery_mode`,
and `error_class`; unknown values map to `other`. Frame IDs, command IDs,
artwork digests, provider inputs, and network addresses are forbidden labels.

| Metric family | Measurement | Source of truth |
| --- | --- | --- |
| Command | completed/replayed/unknown count and completion duration | IPC admission and durable receipt |
| Qualification | candidate, admission, activation, cohort, work, and result decision counts by succeeded/refused outcome | Single SQLite writer after each qualification command |
| Render | duration, cache hit, timeout, worker restart | Rendering job lifecycle |
| Delivery | intent count, pending age, confirmation duration, retry/reconcile and unknown count | Durable Delivery state and frame confirmation |
| Outbox listener | started, stopped, and unavailable counts with bounded state labels | Supervised listener lifecycle; no frame identity in metric dimensions |
| Storage | transaction duration/busy result, object bytes, WAL bytes | SQLite owner and filesystem sampling |
| Runtime | core restart, process memory, queue depth, diagnostic drops | Supervisor and bounded samplers |

The implemented pull outbox exchange metrics count completed HTTP requests and
measure their server-side duration. They classify only `manifest`, `asset`,
`playlist`, `ack`, or `invalid` routes and bounded response outcomes. Partial
requests do
not emit a completed-exchange sample. These measurements do not imply that a
frame displayed an image; only authoritative acknowledgement advances display
state. Frame IDs, request paths, and asset digests never become metric labels.

The primary service indicator is the fraction of eligible updates confirmed
displayed within a target window. Report awake push and sleeping pull
separately; sleeping contact cadence is part of the denominator definition.
Also report an explicit unknown outcome rate and measurement coverage. Choose
numeric objectives only after measurements on the exact supported hardware
and workload. A queued or transport-accepted update is never counted as
displayed.

Named `:telemetry` events are the portable instrumentation boundary.
`Telemetry.Metrics` definitions require a real reporter. Handler work is
bounded and nonblocking: project only catalog-approved scalar measurements and
enum dimensions into a bounded message for a supervised collector. Raw event
metadata never enters its mailbox; the handler performs no SQL, network, or
log formatting in the caller. The collector
maintains fixed-size histograms and bounded enum dimensions, batches rollups
through the existing single writer, and reports its own dropped-event count.
Concurrent emitters reserve one of 10,000 queue slots atomically before
sending, and release it when the collector dequeues that event. A full queue
records a drop immediately. A pre-send mailbox-length observation is not a
capacity bound because multiple emitters can observe the same free slot.
The versioned diagnostic read exposes metric units, histogram upper bounds,
allowed dimensions, and collector reset time alongside each metric page.
`lossFreeSinceMs` is null after a known drop or while the collector is down;
`lastFlushedAtMs` identifies the most recent committed batch. A collector
restart resets in-memory loss accounting, so queries must not infer historical
completeness across that boundary.

The retention budget is minute buckets for 24 hours and hour buckets for 30
days. The writer must prune oldest rollups when their SQLite table and index
pages exceed 32 MiB, in addition to the 20,000-row cap. This active-page
budget excludes reusable free pages and the shared database WAL; physical file
size and long-running resource ceilings still require platform measurement.
The collector runs one maintenance pass after restart, even if no new samples
arrive, so an older oversized store converges to the current limits.
The health read reports active metric page bytes and the enforced page budget.
If the SQLite build cannot measure metric pages, health reports that gap and
metric writes fail without changing delivery state; coverage cannot claim a
loss-free interval after a failed flush.
Each query includes a coverage interval and reset marker so missing
observations cannot be represented as zero.

## Log and audit access

The macOS shell logs with Swift `Logger`. It supervises the bundled core and
drains its stdout/stderr pipes. A bounded parser and 512-record emission queue
forward only allowlisted, structured core records to Apple unified logging under subsystem
`io.frameshift.app`, with stable categories; arbitrary third-party output is
discarded. The shell counts records dropped when parsing or queue capacity is
exceeded. Pipe and bridge failure must not
block a command. A small rotating OTP file captures sanitized critical
failures when the bridge is unavailable. Console.app and `/usr/bin/log` are the
macOS log readers; the product does not build a logs UI. Apple controls
unified-log persistence, so it is not the audit store. Ubuntu sends sanitized
operational logs to journald for `journalctl`. The Nerves Pi appliance has no
journal and uses a bounded OTP circular disk log.

`frameshiftctl diagnostics health|metrics|audit` is a read-only client of the
versioned local IPC contract. Responses are size-limited and audit queries use
stable pagination and explicit retention metadata. A standalone client cannot
reuse the menu shell's in-memory bootstrap token. Its separate read-only
authentication must verify the Unix peer identity and private socket directory
on each platform. Mutation IPC retains its boot token. The CLI does not open
the database or read the Apple unified log store programmatically. Explicit
local export is redacted, bounded, and records its own audit fact.

Before the OTP fallback file handler starts, the core must inspect the final
diagnostics directory and any existing log file without following a symlink.
It must refuse a symlink or non-regular log target, require a private directory,
and restrict an existing regular log to owner-only access. A failed admission
must fail core startup rather than redirect sanitized diagnostic records into
an attacker-chosen file. This local path check does not replace installed
filesystem, ownership, or race-condition acceptance testing.

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
