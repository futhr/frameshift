# Frameshift Documentation

Frameshift uses specification-driven development. Requirements describe the
complete product independently of implementation maturity. Decisions, research,
implementation status and physical validation remain separate.

This corpus contains code/architecture, product structure, technical research
and evidence. Company strategy, monetization, prospective commercial terms and
legal interpretation belong outside the product repository. Technical service
contracts consume approved external policy and financial interfaces; they do
not select a business model.

Requirements remain in force until an explicit decision changes them. Vendors
and revisions are concrete capability instances, never hard-coded protocol
branches. Complete installed thinness matters; there is no arbitrary global
display-size limit.

## Decisions

- [Decision ledger](decisions/README.md)

## Architecture and protocol

- [Product definition and completion contract](product-definition.md)
- [System architecture](architecture/system.md)
- [Visual build platform, Conjunct boundaries and ordered milestones](architecture/build-platform.md)
- [Physical BuildSpec, compatibility and formal verification](architecture/physical-build-contract.md)
- [Frameshift packs, research orchestration and model qualification](architecture/build-orchestration.md)
- [Optional service, purchasing and care integration — final milestone](architecture/build-commerce.md)
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
- [Release artifact manifest](architecture/release-manifest.md)
- [Browser guide simulation](architecture/guide-simulation.md)
- [Shared Gleam decision kernel](architecture/shared-decision-kernel.md)
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
- [Thin composition families, source drawings and geometry gaps](research/thin-composition-evidence.md)

## Research

- [Conjunct adoption, product bundle and extraction plan](research/conjunct-adoption.md)
- [Hardware platforms and power feasibility](research/hardware-platforms.md)
- [Software stack](research/software-stack.md)
- [Technical build decisions, producer seams and model qualification](research/build-platform-decisions.md)
- [SQLite and Elixir boundary](research/sqlite-elixir-boundary.md)
- [Embedded persistence review](research/embedded-persistence.md)
- [Host diagnostics research](research/host-diagnostics.md)
- [AI image generation](research/ai-image-generation.md)
- [Protocol foundations](research/protocol-foundations.md)
- [Prior art and libraries](research/prior-art-and-libraries.md)
- [Display technologies](research/display-technologies.md)
- [Open questions](research/open-questions.md)

## Evidence vocabulary

- **Specified:** required by the product contract, not automatically implemented.
- **Research:** evidence for a direction is being investigated.
- **Candidate:** evidence suggests a fit, but a required check is missing.
- **Validated:** an exact revision passed a named recorded test.
- **Reference:** an interoperable implementation target, not a fixed product SKU.
- **Prototype:** a build intended to invalidate assumptions.

Geometry documentation levels and product/received-hardware evidence are
separate. A linked drawing is not a received part; a mesh is not fit proof; a
passed software test is not a safety certificate.

The complete visual builder and printable list precede final transactional
integration. Software completion and external activation/release evidence are
tracked separately. Missing external permissions or physical measurements do
not justify leaving implementable refusal, simulation and recovery paths
unfinished. The current platform and linked contracts supersede the earlier
build-branch proposal and its presentation. Conjunct extraction requires actual
producer exports, consumer conformance and explicit identity/path migration;
no directory move or runtime readiness is implied by these documents.
