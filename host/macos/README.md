# Frameshift macOS application

This Swift package is the native menu-bar application. It owns SwiftUI
presentation, Apple framework integration, image decoding, secure handoff, and
application lifecycle. Durable library, recipe, outbox, render, and frame state
remain owned by the bundled Elixir core.

The packaged app has a Dock window with the same `ShellModel` and controls as
the menu-bar panel. The packaged app uses the selected white perspective-frame
mark on navy in Dock/Finder and its monochrome silhouette in the menu bar.
`scripts/build-macos-icons` generates the packaged `.icns` and menu-bar PNG
resources from the committed SVG sources.

`LocalCoreClient` communicates with the versioned bounded Unix-domain-socket
protocol using a fresh 256-bit per-launch token delivered through a one-use
user-only bootstrap file. Startup checks whether the socket accepts connections
before sending the first request, including when a stale socket file remains.
Imports use Image I/O to admit one still image, apply
its orientation, convert into canonical sRGB RGBA8, and write a user-only
temporary handoff. The core verifies the handoff digest and persists an
immutable master containing the exact original bytes and normalized pixels. The
handoff is removed after the terminal core response.

The bundled menu process also hosts a private, token-authenticated Keychain
broker for the core. Paired frames store opaque persistent identity references;
only the public certificate and bounded TLS signatures cross the broker
socket. Private-key bytes are never exported. This boundary is type-checked
and its core protocol is unit-tested, but a commissioned identity and live
mutual-TLS frame exchange are still required for end-to-end acceptance.

The packaged app embeds and supervises the production OTP release and Zig
renderer. It is deliberately usable without a generation provider. Frame
pairing and identity provisioning, Keychain-backed local/session identity,
exact target previews, live direct push interoperability, Vision metadata, Service Management
registration, Developer ID signing, hardened runtime, and notarization remain
tracked product gates.

The shell forwards sanitized core records to Apple unified logging. Read them
in Console.app or from Terminal with:

```sh
/usr/bin/log show --last 1h --info --style compact --predicate 'subsystem == "io.frameshift.app"'
```

The packaged `Contents/MacOS/frameshiftctl` reads health, local metric
rollups, and redacted audit pages without a Frameshift UI:

```sh
Frameshift.app/Contents/MacOS/frameshiftctl diagnostics health
Frameshift.app/Contents/MacOS/frameshiftctl diagnostics metrics --limit 50
Frameshift.app/Contents/MacOS/frameshiftctl diagnostics audit --limit 50
```

The read-only socket checks the kernel-reported peer UID. It uses a separate
authorization path from the one-use mutation token. The CLI needs the core
running; the current bundled core stops with the menu process. Background
service registration remains a separate product gate.

Build and test with the system Swift 6 toolchain:

```sh
../../scripts/check macos
```

The Swift Package test target exercises model identity, command encoding,
authoritative state reconciliation, and error redaction. The check executable
also exercises real Apple image decoding. The repository check passes the
toolchain's Swift Testing macro library explicitly when it is installed as
part of Command Line Tools, then builds and checks the packaged app.
The IPC probe performs a real instruction and image-import round trip against a
production core release. Neither check executable is copied into the app.

`swift run frameshift-menu` launches the Swift executable directly, but the
bundled core is available only in the packaged `.app`. The package script
creates an ad-hoc-signed local artifact; release signing and notarization require
external Apple credentials and services.
