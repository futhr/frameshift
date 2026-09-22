# Frameshift Documentation

Frameshift uses specification-driven development. Requirements, decisions,
research evidence, and unresolved validation are kept distinct so an attractive
component or community demo does not silently become architecture.

## Decisions

- [Decision ledger](decisions/README.md)

## Architecture and protocol

- [System architecture](architecture/system.md)
- [Frame Protocol](architecture/frame-protocol.md)
- [Capability model](architecture/capabilities.md)
- [Content pipeline](architecture/content-pipeline.md)
- [Implementation plan](architecture/implementation-plan.md)

## Host

- [macOS controller](host/macos.md)
- [Menu-bar interface](host/menu-bar-interface.md)

## Reference frames

- [Paper Frame — reflective e-paper](frames/paper-frame.md)
- [Photo Frame — matte IPS](frames/photo-frame.md)
- [Pixel Frame — HUB75 RGB matrix](frames/pixel-frame.md)

## Hardware

- [Hardware principles](hardware/principles.md)
- [Candidate BOM](hardware/bom.md)
- [Validation plan](hardware/validation-plan.md)

## Research

- [Hardware platforms and power feasibility](research/hardware-platforms.md)
- [Software stack](research/software-stack.md)
- [AI image generation](research/ai-image-generation.md)
- [Protocol foundations](research/protocol-foundations.md)
- [Prior art and libraries](research/prior-art-and-libraries.md)
- [Display technologies](research/display-technologies.md)
- [Open questions](research/open-questions.md)

## Status vocabulary

- **Research:** a direction is being investigated.
- **Candidate:** evidence suggests it may fit, but a required test is missing.
- **Validated:** the exact revision passed a named, recorded test.
- **Reference:** an interoperable implementation target, not a commercial SKU.
- **Prototype:** a physical/software build intended to invalidate assumptions.

Nothing is production-ready until its exact hardware revision, firmware,
mechanics, thermals, safety, and recovery behavior have been measured.
