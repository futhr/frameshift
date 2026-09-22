# FrameShift

![Status: Research](https://img.shields.io/badge/status-research-blue)
![Maturity: Experimental](https://img.shields.io/badge/maturity-experimental-orange)
![Stage: Prototype](https://img.shields.io/badge/stage-prototype-red)

> [!WARNING]
> **FrameShift is an experimental open-source research project and prototype.** It is not a finished product, production-ready appliance, or certified hardware design. Hardware selections, protocols, dimensions, power requirements, and software architecture are expected to change as physical prototypes are built and measured.

FrameShift explores thin, frameable digital art displays that behave more like passive artwork than computers.

The project separates **content and control** from **display technology**. One macOS application prepares and sends artwork to different frame classes, while each frame advertises capabilities instead of binding the host to a vendor product.

## Initial reference frames

| Target | Display | Purpose |
| --- | --- | --- |
| **Photo Frame** | large matte IPS / eDP | inexpensive photographic A2-class prototype |
| **Paper Frame** | reflective e-paper | paper-like premium/reference path |
| **Pixel Frame** | HUB75 RGB matrix | intentionally abstract, processed pixel artwork |

These are reference targets, not product SKUs.

## Architecture

```text
                       FrameShift for macOS
                              |
                   render / transform / schedule
                              |
                       Frame Protocol
                 ___________|___________
                /           |           \
          Photo Frame   Paper Frame   Pixel Frame
             IPS          e-paper        HUB75
```

The Mac is the control plane, not the frame's life support. Frames cache committed content and remain useful when the Mac sleeps or is offline.

AI-assisted processing is optional. It can create display-specific interpretations such as palette reduction and dithering for e-paper or graphical/pixelated transformations for RGB matrices.

## Principles

- Thin enough for a conventional wooden picture frame.
- No mandatory vendor cloud, account, subscription, or proprietary app.
- Display-agnostic protocol.
- Replaceable display/controller layers.
- Local-first and offline-tolerant.
- Capability negotiation rather than vendor/model coupling.
- Expensive image processing belongs primarily on the host.
- Wood, mat board/passe-partout and physical presentation are part of the design.
- Prototype cheaply before committing to premium large-format panels.

See [docs/README.md](docs/README.md) for the specification and research index.

## Project status

Exact components remain **research candidates until physically validated**. Prices are observations, not specifications, and must be rechecked before purchasing hardware.

## License

License selection is intentionally left open until the first implementation lands.
