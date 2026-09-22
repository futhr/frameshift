# Frameshift macOS application

This Swift package is the native menu-bar application. It owns SwiftUI
presentation, Apple framework integration, image decoding, secure handoff, and
application lifecycle. Durable library, recipe, outbox, render, and frame state
remain owned by the bundled Elixir core.

`LocalCoreClient` communicates with the versioned bounded Unix-domain-socket
protocol. Imports use Image I/O to admit one still image, apply its orientation,
convert into canonical sRGB RGBA8, and write a user-only temporary handoff. The
core verifies the handoff digest and persists an immutable master containing the
exact original bytes and normalized pixels. The handoff is removed after the
terminal core response.

The packaged app embeds and supervises the production OTP release and Zig
renderer. It is deliberately usable without a generation provider. Frame
pairing, Keychain-backed local/session and frame identities, exact target
previews, direct push transport, Vision metadata, Service Management
registration, Developer ID signing, hardened runtime, and notarization remain
tracked product gates.

Build and test with the system Swift 6 toolchain:

```sh
swift format lint --recursive --strict Sources Package.swift
swift run frameshift-shell-checks
../../scripts/package-macos
../../scripts/check-packaged-app .build/artifacts/Frameshift.app
```

The check executable exercises model behavior and real Apple image decoding.
The IPC probe performs a real instruction and image-import round trip against a
production core release. Neither check executable is copied into the app.

`swift run frameshift-menu` launches the Swift executable directly, but the
bundled core is available only in the packaged `.app`. The package script
creates an ad-hoc-signed local artifact; release signing and notarization require
external Apple credentials and services.
