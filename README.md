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
- Zig for project-owned native transforms and embedded firmware.
- Nerves only for an optional external bridge, simulator, or evidence-backed
  powered prototype—not as default hardware inside a frame.
- Local-first image generation with explicit provider and cloud disclosure.
- No Python in application code, firmware, tooling, tests, examples, or project
  workflows.
- No Raspberry Pi hardware in Frameshift reference builds.

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
status, not the product scope or a release tier. Run every implemented format,
static-analysis, test, fuzz, and release-build gate with:

```sh
make check
```

On macOS, build the current ad-hoc-signed development bundle with its embedded
Elixir core and Zig renderer with:

```sh
./scripts/package-macos
```

The generated `.app` is for local inspection and automated installed-flow
checks. It is not Developer ID signed or notarized, and background service
registration is not yet implemented.

See the [software verification map](docs/architecture/verification.md) for the
requirement-to-test links and the evidence that remains open.

## License

License selection remains an open release gate. Until a license file is added,
the repository does not grant reuse rights beyond those provided by law.
