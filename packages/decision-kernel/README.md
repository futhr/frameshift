# Frameshift decision kernel

This pure Gleam package owns the bounded decisions shared by the Elixir host
and the browser clients. Its one source tree builds for Erlang and
JavaScript. The Mix wrapper copies all production BEAM modules into the host
dependency so the OTP release does not need Gleam installed at runtime.
It excludes test modules and clears stale generated modules on each build.
The core check forces a Dialyzer PLT refresh when the generated BEAM's exports
change without a dependency version change.

From this directory:

```sh
mise exec -- gleam format --check src test
mise exec -- gleam build --target erlang --warnings-as-errors
mise exec -- gleam build --target javascript --warnings-as-errors
mise exec -- gleam test --target erlang
mise exec -- gleam test --target javascript
```

The contract and limits are in
[Shared Decision Kernel](../../docs/architecture/shared-decision-kernel.md).
The physical arithmetic module adds exact units, tolerance intervals,
grid/aperture/stack/load fit and voltage containment under the
[physical build contract](../../docs/architecture/physical-build-contract.md#bounded-physical-arithmetic-v1).
It returns unknown for missing or conflicting applicable facts and refuses
invalid inputs. It cannot establish profile provenance, complete assembly
compatibility, purchasing eligibility or hardware validation by itself.
