# Frameshift macOS shell

This Swift package is the first native menu-bar shell slice. It owns SwiftUI
presentation and ephemeral UI state. Durable library, recipe, outbox, render,
and frame state remain owned by the Elixir core.

The executable currently runs against `PreviewCoreClient`, an in-memory actor
with three explicitly experimental preview targets. Manual import records only
preview metadata; it does not yet copy source bytes into the Elixir library.
Generation is visibly unavailable when no provider is configured. Pairing,
Keychain identities, Vision metadata, authenticated local IPC, background
launch, Developer ID signing, and notarization remain unimplemented gates.

Build and test with the system Swift 6 toolchain:

```sh
swift format lint --recursive --strict Sources Package.swift
swift run frameshift-shell-checks
../../scripts/package-macos
```

The check executable is used because the standalone Command Line Tools SDK in
the current development environment does not ship the XCTest or Swift Testing
runner plugins. It exits nonzero on failed client/model checks and does not ship
inside the eventual app bundle.

`swift run frameshift-menu` launches the executable directly for local UI work.
The packaging script creates an ad-hoc-signed research bundle at
`.build/artifacts/Frameshift.app` with `LSUIElement` enabled. It contains only
the preview Swift shell: the Elixir release and Zig worker are not embedded or
supervised yet. Developer ID signing, hardened runtime, notarization, and a
production bundle identifier remain distribution gates.
