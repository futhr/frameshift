# Frameshift Documentation

Frameshift uses specification-driven development. Requirements describe the
complete product independently of current implementation maturity. Decisions,
research evidence, implementation status, and unresolved validation remain
separate so a partial component cannot silently redefine product scope.

The specifications are not an MVP or demo brief. A requirement remains in
force until an explicit decision changes it. Hardware vendors and revisions are
allowed early as concrete capability instances; they never become hard-coded
protocol branches.

## Decisions

- [Decision ledger](decisions/README.md)

## Architecture and protocol

- [Product definition and completion contract](product-definition.md)
- [System architecture](architecture/system.md)
- [Portable host core](architecture/host-core.md)
- [Host domain map](architecture/domain-map.md)
- [Host diagnostics contract](architecture/diagnostics.md)
- [Frame Protocol](architecture/frame-protocol.md)
- [Networked frame simulator and manufacturer baselines](architecture/container-frame-simulator.md)
- [Capability model](architecture/capabilities.md)
- [Display timing and pinned artwork loops](architecture/display-timing.md)
- [Content pipeline](architecture/content-pipeline.md)
- [Qualified render and transfer generations](architecture/qualified-generations.md)
- [Installation and interactive guide](architecture/install-and-guide.md)
- [Browser guide simulation](architecture/guide-simulation.md)
- [Implementation plan](architecture/implementation-plan.md)
- [Software verification map](architecture/verification.md)

## Host

- [macOS controller](host/macos.md)
- [Browser guide handoff](host/guide-handoff.md)
- [Linux and Raspberry Pi hosts](host/linux.md)
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
- [SQLite and Elixir boundary](research/sqlite-elixir-boundary.md)
- [Embedded persistence review](research/embedded-persistence.md)
- [Host diagnostics research](research/host-diagnostics.md)
- [AI image generation](research/ai-image-generation.md)
- [Protocol foundations](research/protocol-foundations.md)
- [Prior art and libraries](research/prior-art-and-libraries.md)
- [Display technologies](research/display-technologies.md)
- [Open questions](research/open-questions.md)

## Evidence vocabulary

- **Specified:** required by the complete product contract.
- **Research:** evidence for a direction is being investigated.
- **Candidate:** evidence suggests it may fit, but a required test is missing.
- **Validated:** the exact revision passed a named, recorded test.
- **Reference:** an interoperable implementation target, not a commercial SKU.
- **Prototype:** a physical/software build intended to invalidate assumptions.

These terms describe evidence, not smaller product editions. Nothing is
production-ready until the software release and each claimed hardware revision
have passed their named functional, security, lifecycle, mechanical, thermal,
safety, and recovery gates.
