# Frameshift decision kernel

This pure Gleam package owns the bounded decisions shared by the Elixir host
and the static installation guide. Its one source tree builds for Erlang and
JavaScript. The Mix wrapper copies the production BEAM module into the host
dependency so the OTP release does not need Gleam installed at runtime.

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
