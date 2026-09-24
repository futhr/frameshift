# Frameshift

![Product scope: Complete specification](https://img.shields.io/badge/product%20scope-complete%20specification-blue)
![Implementation: In progress](https://img.shields.io/badge/implementation-in%20progress-orange)
![Release evidence: Incomplete](https://img.shields.io/badge/release%20evidence-incomplete-red)

> [!WARNING]
> **Frameshift is not yet a finished or certified product.** The specifications
> define the complete intended product; implementation and evidence ledgers
> state what is currently proven. Unfinished implementation must never be used
> to silently reduce the product specification.

Frameshift is a system for thin digital art frames that behave as much like
framed artwork as their display technology permits. A native macOS menu-bar app
imports or generates a still image, renders exact artifacts for a frame, and
then gets out of the way.

The companion website adds a visual component configurator, revision-specific
instructions and a complete printable shopping list for independent use.
Optional external-service and purchasing integration remains the **final build
milestone**. The product is planned as a consumer of Conjunct's generic physical
composition contracts while retaining its own frame profiles, native software
and device behavior. See the [platform specification](docs/architecture/build-platform.md)
and [Conjunct adoption plan](docs/research/conjunct-adoption.md).

This repository contains product code, structural specifications and technical
evidence. It does not define company monetization, partner deals or legal
operating-model strategy. External policy and financial capabilities enter
through explicit qualified integration contracts.

## Reference media

| Target | Display | Power truth |
| --- | --- | --- |
| **Paper Frame** | reflective full-color e-paper | Can be cable-free and passive between updates where the complete design supports it |
| **Photo Frame** | matte IPS/LVDS/eDP and other explicitly qualified panel interfaces | Needs continuous power while visible |
| **Pixel Frame** | low-resolution HUB75 RGB matrix | Needs continuous, potentially high-current power |

These are interoperable reference classes, not a closed list of product SKUs
or allowed diagonals. Any vendor or custom frame can participate when it
truthfully describes its capabilities and implements a qualified protocol
binding. The complete installed composition must be thin; the panel alone is
not the measurement. There is no arbitrary global size limit.

Zero visible cable is a priority during hardware and mounting research, not a
hard requirement. For emissive frames it requires a powered mount, concealed
supply or carefully routed cable; it does not mean the display uses no power.

## Architecture

```text
                   Frameshift for macOS
          SwiftUI shell + Elixir core + Zig renderer
                              |
                still-image Frame Protocol
                  _________|_________
                 /         |         \
             Paper       Photo      Pixel
           sleeping MCU  qualified  timed scan
                         scanout    controller
```

The Mac retains source masters, AI recipes and rendered derivatives. Frames
retain verified still assets and their last known-good image. A sleeping frame
can wake and pull pending work; powered frames can also receive pushes.

There is no video, animation, motion, audio or streaming path in the frame
artwork protocol. A slideshow is a timed sequence of cached still images.
Visual assembly instructions in the companion guide are a separate renderer.

## Stack direction

- Elixir/OTP for the macOS orchestration core.
- Phoenix + Ash/AshPostgres and phoenix-assets + Svelte 5/SvelteKit for the
  companion web platform; qualified Refpath loads product-owned packs.
- Conjunct for generic physical-composition and instruction contracts; exact
  producer exports and consumer tests must pass before adoption.
- Shared pure Gleam decisions, targeted ExMaude verification and bounded
  read-only Beamlens diagnostics. Models are optional and qualified per task;
  they do not decide compatibility or grant external-action authority.
- Rivure for optional financial integration and DocShell for portable
  explanatory artifacts; no duplicate provider engine or documentation model.
- Swift/SwiftUI for the native menu-bar shell and Apple frameworks.
- Zig for the isolated raster worker. Select MCU/scanout firmware tooling from
  exact interface, update, power, memory and protocol evidence.
- Ubuntu amd64/arm64 hosts and a Raspberry Pi 5 Ubuntu host reuse the core;
  a dedicated Nerves Pi 5 appliance is a separate host release target.
- Local-first image generation with explicit provider and cloud disclosure.
- No project-owned Python application or firmware code. Pinned upstream
  toolchains may use Python inside isolated reproducible builds.
- No Raspberry Pi hardware inside Frameshift reference frame builds. The
  separate host targets above do not authorize a rear-mounted Pi workaround.

## Installation direction

The first public guide is planned for `frameshift.wotex.io`. It will lead from
frame choice through a browser simulation that runs locally after loading to a
signed Mac download or Homebrew Cask, with separate Ubuntu and Pi-host
instructions. The browser simulation cannot pair a physical frame; installed
native software performs pairing and delivery. See the
[installation and guide contract](docs/architecture/install-and-guide.md) and
[Linux host specification](docs/host/linux.md). No public download is available
until signing, packaging, licensing and installed-release gates pass.

## Principles

- Prototype risky assumptions where useful; the complete intended product is
  not reduced to the currently easiest prototype.
- Panel, controller, power, cable bends, battery, backing, thermals and mounting
  all count toward installed depth and physical qualification.
- Local frame operation and the independent list require no vendor cloud
  account or subscription. Optional external operations have separate scoped
  authorization and producer contracts.
- Still-image-only, capability-driven device protocol.
- Source masters and generated results are immutable and cached.
- Interrupted transfers never replace valid artwork.
- Cloud AI never happens as a silent fallback.
- Unknown facts remain visible; simulation and attractive geometry are not
  proof of measured compatibility or certification.

See [docs/README.md](docs/README.md) for specifications, evidence and open gates.

## Development

The current partial implementation includes an Elixir library/simulator core,
an isolated Zig raster worker and a SwiftUI shell. This is implementation
status, not a release tier. Run the default format, static-analysis, test, fuzz
and release-build gate with:

```sh
make check
```

The Docker-backed live receiver and Linux peer-credential checks are separate
CI lanes. Run `./scripts/check container` and `./scripts/check linux-ipc` with a
Docker-compatible daemon.

The core's `mix check` covers compilation, formatting, strict Credo, Doctor,
ExDoc, coverage, Dialyzer and dependency audits. Swift Package tests and Zig
Debug/ReleaseSafe test builds are part of the repository gate. Run `make index`
for the local Dexter index and `mix bench` from `host/core/` to regenerate
Markdown performance reports.

On macOS, build the current ad-hoc-signed development bundle with its embedded
Elixir core and Zig renderer:

```sh
./scripts/package-macos
```

The generated `.app` is for local inspection and automated installed-flow
checks. It is not Developer ID signed or notarized, and Launch at Login has not
passed installed lifecycle acceptance. Planned directory moves do not change
these current commands until the verified migration is committed.

See the [verification map](docs/architecture/verification.md) for test links and
missing evidence. Documentation changes do not mean tests were run.

## License

License selection remains an open release gate. Until a license file is added,
the repository does not grant reuse rights beyond those provided by law.
