# Shared Decision Kernel

**Status:** required cross-target host and guide contract; implementation
evidence is recorded separately.

## Toolchain and boundary

Pin Gleam 1.18.1 with the repository's Erlang/OTP 29 and Elixir 1.20.4
toolchain. Gleam's documented compatibility includes OTP 29 from 1.18 and
JavaScript runtimes implementing ECMAScript 2022. The same `.gleam` source
must compile to both targets. The package is a pure library with no externals,
filesystem, network, clock, randomness, secrets, or hardware access. The
Elixir host calls the Erlang build for selected production decisions; the
static guide calls the JavaScript build only to explain those decisions.

## First extraction

Move the rules for bounded artwork dwell selection and confirmation of direct
and pull display state into the kernel. The host remains responsible for
schema admission, persistence, synchronization, and authoritative frame
reads. The guide feeds only fixed examples or user-provided non-secret values
through the same functions. Inputs crossing from JSON must be integers within
the JavaScript safe range and the profile's practical dwell bound; invalid
input returns a typed refusal, never an implicit default. A queued transfer
cannot become displayed without a matching revision, request or manifest
identity, exact asset digest, and an authoritative displayed outcome.
Pull acknowledgements admit only the schema's `verified`, `unchanged`, and
`failed` storage values and `displayed`, `failed`, and `not-requested` refresh
values. A failed or skipped refresh remains pending; verified cached bytes may
be reported as `unchanged` without weakening the digest check.

Every decision has canonical fixtures covering valid, invalid, boundary, and
uncertain cases. Run those fixtures on both targets and compare results. The
host adapter must include a parity test against its former decision behavior
before deleting that behavior. Package the BEAM output with the OTP release;
do not rely on a developer's Gleam installation at runtime. The JS output is
versioned with the guide and cannot be treated as physical display evidence.

Later extractions may add profile choice and capability admission only after
their bounded input and qualified profile semantics are fixed. Exact render
bytes, credentials, and delivery effects stay outside the kernel.

Sources: [Gleam compatibility](https://gleam.run/documentation/compatibility-reference/),
[Gleam build targets](https://gleam.run/documentation/command-line-reference/),
and [Elixir/OTP compatibility](https://elixir.hexdocs.pm/main/compatibility-and-deprecations.html).
