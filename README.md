# Frameshift

![Product scope: Complete specification](https://img.shields.io/badge/product%20scope-complete%20specification-blue)
![Implementation: In progress](https://img.shields.io/badge/implementation-in%20progress-orange)
![Release evidence: Incomplete](https://img.shields.io/badge/release%20evidence-incomplete-red)

> [!WARNING]
> **Frameshift is not yet a finished or certified product.** The specifications
> define the complete intended product; the implementation and evidence ledgers
> state what is currently proven. Unfinished implementation must never be used
> to silently reduce the product specification.

Frameshift is a system for thin digital art frames that behave as much like
framed artwork as their display technology permits. A native macOS menu-bar app
imports or generates a still image, renders exact artifacts for a frame, and
then gets out of the way.

## Reference media

| Target | Display | Power truth |
| --- | --- | --- |
| **Paper Frame** | reflective full-color e-paper | Can be cable-free and passive between updates |
| **Photo Frame** | large matte IPS/LVDS/eDP | Needs continuous power while visible |
| **Pixel Frame** | low-resolution HUB75 RGB matrix | Needs continuous, potentially high-current power |

These are interoperable reference classes, not a closed list of product SKUs.
Any vendor or custom frame can participate when it truthfully describes its
capabilities and implements a compatible protocol binding. Thinness is
mandatory. Zero
visible cable is a priority during hardware and mounting research, not a hard
requirement. For emissive frames it requires a powered mount, concealed supply,
or carefully routed cable; it does not mean the display uses no power.

## Architecture

```text
                   Frameshift for macOS
          SwiftUI shell + Elixir core + Zig renderer
                              |
                still-image Frame Protocol
                  _________|_________
                 /         |         \
             Paper       Photo      Pixel
           sleeping MCU  thin MCU   timed-DMA MCU
```

The Mac retains source masters, AI recipes, and rendered derivatives. Frames
retain verified still assets and their last known-good image. A sleeping frame
can wake and pull pending work; powered frames can also receive pushes.

There is no video, animation, motion, audio, or streaming path. A slideshow is
only a timed sequence of cached still images.

## Stack direction

- Elixir/OTP for the macOS orchestration core.
- Swift/SwiftUI only for the native menu-bar shell and Apple frameworks.
- Zig for the existing isolated raster worker. Select MCU firmware tooling
  from exact controller, update, power, and protocol evidence.
- Ubuntu amd64/arm64 hosts and a Raspberry Pi 5 Ubuntu host reuse the core;
  a dedicated Nerves Pi 5 appliance is a separate release target.
- Local-first image generation with explicit provider and cloud disclosure.
- No project-owned Python application or firmware code. Pinned upstream
  toolchains may use Python inside isolated reproducible builds.
- No Raspberry Pi hardware in Frameshift reference builds.

## Installation direction

The first public guide is planned for `frameshift.wotex.io`. It will lead from
frame choice through a browser simulation that runs locally after loading to a
signed Mac download or Homebrew Cask, with separate Ubuntu and Pi
instructions. The browser simulation cannot pair a physical frame; installed
native software performs pairing and
delivery. See the [installation and guide contract](docs/architecture/install-and-guide.md)
and [Linux host specification](docs/host/linux.md). No public download is
available until signing, packaging, licensing, and installed release gates pass.

## Principles

- A recommended tactic is to prototype the chosen frame class's risky
  assumptions cheaply before premium hardware or a finished enclosure; it is
  not a required sequence.
- The complete installed object must remain picture-frame thin.
- No mandatory vendor cloud, account, subscription, or proprietary app.
- Still-image-only, capability-driven protocol.
- Source masters and generated results are immutable and cached.
- Interrupted transfers never replace valid artwork.
- Cloud AI never happens as a silent fallback.
- Power, thermals, cable bends, controller boards, battery, and mounting count
  as part of the frame—not as details to solve later.

See [docs/README.md](docs/README.md) for specifications, evidence, and open
validation gates.

## Development

The current partial implementation includes an Elixir library/simulator core,
an isolated Zig raster worker, and a SwiftUI shell. This is implementation
status, not the product scope or a release tier. Run the default format,
static-analysis, test, fuzz, and release-build gate with:

```sh
make check
```

The Docker-backed live receiver and Linux peer-credential checks are separate
lanes in CI. Run them locally with `./scripts/check container` and
`./scripts/check linux-ipc` when a Docker-compatible daemon is available.

The core's `mix check` configuration covers compilation, formatting, strict
Credo, Doctor, ExDoc, coverage, Dialyzer, and dependency audits. Swift Package
tests and the Zig Debug and ReleaseSafe test builds are part of the repository
gate. Run `make index` for the local Dexter code index, and run `mix bench` from
`host/core/` to regenerate Markdown performance reports.

On macOS, build the current ad-hoc-signed development bundle with its embedded
Elixir core and Zig renderer with:

```sh
./scripts/package-macos
```

The generated `.app` is for local inspection and automated installed-flow
checks. It is not Developer ID signed or notarized, and background service
registration through Launch at Login has not passed installed lifecycle
acceptance.

See the [software verification map](docs/architecture/verification.md) for the
requirement-to-test links and the evidence that remains open.

## License

License selection remains an open release gate. Until a license file is added,
the repository does not grant reuse rights beyond those provided by law.
