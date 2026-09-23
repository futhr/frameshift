# Library Backup and Restore

**Status:** required host storage contract; software evidence is separate from
power-loss and target-filesystem qualification.

## Format

A version-one backup is one directory containing `metadata.sqlite`, an
`objects/sha256` tree, a `trash` tree, and a canonical `manifest.json`. The
manifest identifies the format version, exact database SHA-256, and every
SQLite `objects` row by digest, byte count, and active/trash placement. The
manifest contains no Keychain secret or transient IPC token. Its digest checks
detect corruption, not a malicious replacement of the whole backup.

## Creation

The library's single writer serializes the entire export against imports,
collection, pairing, outbox changes, and other mutations. It creates a private
sibling staging directory, runs SQLite `VACUUM INTO` for a consistent database
snapshot, then copies each object named by the authoritative snapshot. Source
and copied bytes must match their digest and size. It writes and syncs the
manifest last, verifies the complete staging directory, and publishes it with
one rename. An existing destination is never overwritten. Failed or interrupted
staging remains non-activatable and can be removed without touching the library.
SQLite documents `VACUUM INTO` as a consistent live backup and notes that
interrupted output may be corrupt: [VACUUM INTO](https://www.sqlite.org/lang_vacuum.html#vacuuminto).

## Restore

Restore runs with the destination library stopped and installs into an absent
data directory. It stages the backup on the destination filesystem, checks
the manifest, database and every named object digest and size, then runs
`PRAGMA integrity_check` and `PRAGMA foreign_key_check`. Protected current,
previous-known-good, queued, and playlist references must resolve to verified
objects. It rebuilds the derived FTS5 index because vacuuming may change
unkeyed rowids. Only then does it rename the staged directory into place.
Failures leave the destination absent and the source backup untouched. Restore
does not assert that a frame displayed a queued image or transfer Keychain
private keys to another Mac; a moved installation requires re-pairing.

APFS, supported Linux filesystems, Pi storage, full-disk behavior, and
power-interruption durability require target-specific qualification before a
release claim. This contract does not authorize repository visibility changes.
