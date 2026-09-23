# Host Domain Map

**Status:** normative software design; implementation evidence is separate

## Language and ownership

The host is a modular monolith. A context is a model and API boundary, not an
OTP process, a database connection, or a table namespace. The application
service coordinates contexts and adapters; the single SQLite owner executes
all durable mutations. The same model runs on macOS and Linux.

| Term | Meaning | Authority |
| --- | --- | --- |
| Master | Immutable source image and recorded provenance | Library |
| Recipe | Canonical inputs for generation or composition | Library identity; Generation or Rendering behavior |
| Artifact | Immutable rendered bytes for an exact profile and renderer revision | Library identity; Rendering production |
| Paired frame | Admitted identity, pinned server certificate, credential reference, and capabilities | Frames |
| Desired | Artifact the host intends a frame to show | Delivery |
| Confirmed displayed | Artifact reported by the frame after its display commit | Delivery |
| Previous known good | Last confirmed artifact retained during a replacement | Delivery |
| Intent | Durable instruction to push or expose an artifact before network I/O | Delivery |
| Receipt | Durable disposition of a local command ID and canonical command hash | Application boundary, stored by the single writer |
| Audit entry | Redacted, durable fact about a completed state transition | Diagnostics, committed with the transition |

Frame discovery and admission belong to Frames. Delivery owns every transition
between desired, pending, confirmed, and previous-known-good states. A Frames
query may show that state, but must not mutate or independently infer it. The
Library enforces reference protection for all artifacts in those states.

Paired-frame admission is idempotent for an identical canonical TD, credential
reference, and pinned server SPKI. It rejects an existing device ID with
changed custody or description and rejects a server SPKI already assigned to a
different device ID. Certificate rotation and TD refresh require separate
authenticated operations with their own transition and pending-delivery rules;
ordinary admission cannot perform either change implicitly.

## Atomicity and effects

1. A command is admitted, canonically identified, and claimed before effects.
   A pending claim is an unknown outcome after interruption, not permission to
   repeat an external effect.
2. A delivery intent, revision, desired reference, and audit fact commit in
   one immediate SQLite transaction before sending bytes or a WoT action.
3. A frame acknowledgement or authoritative state read may move `current` only
   if frame identity, revision, request ID, and artifact digest match. The
   previous known-good reference remains protected until this commit succeeds.
4. An external transfer is never inside a SQLite transaction. Failure or an
   ambiguous response leaves durable intent pending for reconciliation.
5. Content placement is stage, flush, rename, then database commit; startup
   reconciles orphaned files without collecting referenced bytes.
6. Audit writes share the mutation transaction. Logs and metrics are emitted
   after commit and cannot make a successful mutation fail.

Pure transition functions should accept domain values and return typed
decisions or errors. Persistence mappings, IPC JSON, Wotex bindings, Keychain,
Image I/O, and the Zig worker stay outside those functions. A port is introduced
for a real external or platform boundary, not for every table.

## Public operations

- Library: import, register recipe/artifact, pin, recover, search, and verified
  read.
- Frames: admit, list, resolve, and forget a paired frame.
- Delivery: request, inspect pending work, acknowledge, confirm, reconcile,
  and reject conflicting updates.
- Rendering: plan and execute a deterministic bounded job.
- Generation: preflight, execute or cancel a selected provider, and record
  provenance with explicit cloud consent.
- Diagnostics: query bounded health and metrics; page or export redacted audit.

Application services own workflows spanning these APIs. Read projections may
join context data through the single writer. Context APIs return typed outcomes
and do not expose a database connection or framework schema.

## Refactor order and proof

Extract Delivery transition rules first because they carry the most complex
cross-table invariant. Characterize existing push, pull, replay, interruption,
and collection behavior before changing their storage paths. Then extract
Library and Frames decisions, followed by Rendering and Generation. Keep the
existing single-writer transactions while modules move. Only change the
persistence technology after comparing the candidate against the same tests,
contention cases, crash checkpoints, packaged release, and resource baseline.

This follows the consistency-boundary meaning of aggregates in
[Eric Evans' DDD reference](https://www.domainlanguage.com/wp-content/uploads/2016/05/DDD_Reference_2015-03.pdf)
and SQLite's [one-writer WAL behavior](https://www.sqlite.org/wal.html).
