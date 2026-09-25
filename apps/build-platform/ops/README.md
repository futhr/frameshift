# Platform observability

The authenticated `/ops/metrics` endpoint exports server catalog v3. Its meaning,
coverage, reset and cardinality rules are in the
[diagnostics contract](../../../docs/architecture/diagnostics.md#server-catalog-v3-and-collection-limits).
The endpoint returns 503 when its collector is unavailable and 401 for an absent
or incorrect token. No diagnostic model is required to collect metrics.

`prometheus/prometheus.yml` is a same-host configuration. Install the metrics
token as a private file at the configured secret path and set the matching
`FRAMESHIFT_METRICS_TOKEN` for the app. For a remote scraper, configure its actual
HTTPS target and certificate trust explicitly; do not transmit the token over
an untrusted plaintext network. The server does not publish its metrics token
in generated browser contracts.

Configure Prometheus with `--storage.tsdb.retention.time=30d` and an explicit
`--storage.tsdb.retention.size` appropriate to the allocated volume; the smaller
limit wins. Configure an Alertmanager destination before operational activation.
Repository rules detect unavailable/stale collection, rejected observations and
repeated collector resets. They are collection health alerts. Application
latency/availability objectives require an admitted workload baseline.

Run `./scripts/check platform-observability` from the repository root to check
configuration, rule syntax, rule behavior and real exposition with the pinned
Prometheus tool, after compiling the app with the platform lane.
No live service or external notification is started by that lane.

The adopted Conjunct hosting direction uses GreptimeDB with compatible
Prometheus/OpenTelemetry ingestion. This directory currently qualifies the
Prometheus path only. Keep the bounded exporter; the receiver, authentication,
retention, log/trace pipeline and outage behavior need separate integration
evidence before switching the operated destination.

The reporter stores fixed buckets, not individual samples. Tests exercise
100,000 concurrent observations without scraping, malformed values, label
normalization, endpoint isolation and a collector outage/restart while HTTP
remains available. Prometheus retains historical observations; the app retains
only current aggregates. A reset or collection gap cannot establish zero work.
