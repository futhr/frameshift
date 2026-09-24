# Embedded Persistence Review

**Research date:** 2026-09-23
**Outcome:** SQLite remains the authoritative host metadata store on macOS,
Ubuntu, and Raspberry Pi 5 hosts. Artwork bytes stay in content-addressed files.

## Decision criteria

Delivery is a transaction ledger: asset references, replay receipts, monotonic
revisions, desired/current/previous-known-good state, and audit facts must
survive crash and restart together. The embedded store needs enforced unique
and foreign-key constraints, inspectable migrations, bounded local search,
online backup, and recovery tooling on each host target. A novel data model is
useful only if it improves those guarantees at a measurable cost.

| Engine | Fit for authoritative host state | Decision |
| --- | --- | --- |
| SQLite via Exqlite | Transactions, constraints, mature recovery/backup, FTS5, and embedded operation without a server fit the single-writer architecture. The NIF, filesystem, and exact packages still need target-specific release tests. | **Selected.** Keep one writer and direct SQL. |
| NodeDB Lite 0.1 | Embeddable Rust/Wasm with document, vector, graph, and full-text engines. Its published local SQL executor does not run JOIN, aggregates, or CTEs; Lite/Origin synchronization is a separate distributed consistency model. | Not selected; no NodeDB dependency in the host or guide. |
| CubDB | Pure Elixir, append-only key/value persistence with useful embedded ergonomics. Domain references and relational constraints would have to be implemented above the store. | Not selected; no second authority for host state. |
| Mnesia/DETS | Native OTP stores with useful Erlang semantics, but no advantage for the required SQL constraints, library search, and export/recovery workflow. | Do not replace the host ledger. |
| DuckDB | Strong local analytics engine. Frameshift needs small transactional mutations and protected references more than analytical scans. | No place in the command path. |

Ecto and Xqlite are boundary/driver choices, not alternative storage engines.
Do not add an ORM to achieve domain separation. Reopen the Exqlite choice only
for a measured packaging, crash, latency, or migration defect; preserve the
same SQLite invariants if the driver changes.

## Required storage contract

- One owner serializes immediate write transactions with foreign keys enabled,
  a finite busy timeout, WAL, and full synchronous commits on qualified local
  filesystems. Do not assume WAL is safe on a network filesystem.
- Keep digest bytes outside SQLite. Stage, hash, flush, rename, then commit
  references; reconcile orphan files after interruption. A database commit does
  not atomically commit an external file.
- Provide a supported backup/export command that takes a consistent SQLite
  snapshot and a digest manifest of referenced objects. Pin the snapshot's
  object set against collection until the copy is complete. Restore verifies
  `integrity_check`, `foreign_key_check`, object digests, and protected
  current/previous-known-good references before activation.
- Keep search indexes derived from authoritative rows and source files. Start
  with SQLite FTS5 for text after checking it is enabled in every target build.
  A search index can be rebuilt without changing delivery state.
- Qualify filesystem durability and corruption recovery on APFS, the selected
  Ubuntu filesystem, and Pi storage. Fault-inject power loss and full disk;
  record the exact storage medium and mount options.
- A frame MCU uses its own small flash journal/filesystem and two verified
  asset slots. It does not inherit the host SQLite decision.

Primary evidence: [SQLite backup API](https://www.sqlite.org/backup.html),
[SQLite WAL](https://www.sqlite.org/wal.html),
[SQLite FTS5](https://www.sqlite.org/fts5.html),
[SQLite PRAGMA checks](https://www.sqlite.org/pragma.html),
[NodeDB Lite support matrix](https://github.com/NodeDB-Lab/nodedb-lite/blob/main/docs/lite-support-matrix.md),
[CubDB source](https://github.com/lucaong/cubdb),
[Erlang tables and Mnesia](https://www.erlang.org/doc/system/tablesdatabases.html),
[Erlang DETS](https://www.erlang.org/docs/26/man/dets.html), and
[DuckDB design](https://duckdb.org/why_duckdb).
