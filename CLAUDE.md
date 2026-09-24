# Frameshift maintainer instructions

Frameshift is a complete product specification under active implementation for
thin, frameable digital art displays. Read `README.md` and `docs/README.md`
before changing the repository. The documents under `docs/` are the current
design record; implementation status does not reduce their scope.

## Working rules

1. Research precedes specification. A product page, marketplace listing, or
   plausible architecture is not evidence that a component will work.
2. Keep evidence states distinct:
   - **Research**: a direction is under investigation.
   - **Candidate**: sourced evidence suggests suitability, but the choice has
     not passed physical validation.
   - **Reference**: an intended interoperable implementation or target, not a
     commercial product.
   - **Prototype**: hardware or software built to test stated assumptions.
   - **Validated**: the specific revision and configuration passed documented
     measurements. Validation does not transfer to a different revision.
3. Never describe Frameshift, a frame, or a component as production-ready,
   proven, safe, compatible, or available without linked evidence at that tier.
4. Keep requirements separate from candidates. Architecture must not silently
   depend on a vendor, product listing, transport, runtime, or unmeasured value.
5. Prefer capability negotiation over vendor or model branching. Preserve the
   separation between the macOS host, Frame Protocol, frame agent, display
   adapter, and physical panel.
6. The host owns expensive rendering. A frame owns persistence, capability
   reporting, safe commits, and enough autonomy to keep valid art visible while
   the host or network is offline.
7. Record complete physical constraints: active area, outline, total depth,
   connector and cable clearance, voltage, current, thermal behavior, PSU,
   weight, mounting, service access, and passe-partout geometry.
8. Prices, stock, firmware support, and vendor specifications are dated
   observations. Recheck them before a purchase or prototype decision.
9. Do not commit or push unless asked. Never add AI-tool attribution or a
   co-author trailer.
   Once commits are authorized, use Conventional Commit subjects in the form
   `type(scope): imperative description`; Git Ops uses their type to classify
   changes. Enable `.githooks/commit-msg` through
   `git config core.hooksPath .githooks` before committing.
10. Never change repository visibility. Visibility changes are manual,
    user-only actions on every hosting provider.
11. Do not write Python in Frameshift application code, firmware, scripts,
    examples, or tests. A pinned upstream firmware/system toolchain may require
    Python inside an isolated, reproducible build environment; record its
    version, inputs, license, and output, and never ship it as an application
    runtime. Prefer Elixir/OTP for host orchestration. Use Nerves for a
    separately qualified external Pi appliance or bridge. Use Zig for the
    existing native renderer; select MCU firmware language and vendor tooling
    from exact hardware and recovery evidence rather than language preference.
    A thin Swift/SwiftUI shell owns macOS-only lifecycle and system APIs.
12. Frameshift reference builds contain no Raspberry Pi hardware. Prior art
    built around it may be cited only as research evidence, not adopted as the
    reference architecture.
13. Frameshift handles still images only. Do not add Membrane, video, motion,
    animation, audio, or streaming infrastructure.
14. Builders may choose any frame class and are not required to build all of
    them. Prototype-first is risk-reduction advice within a chosen track, not a
    mandatory sequence across Paper, Photo, and Pixel.
15. Zero visible cable is a design priority, not a universal pass/fail rule.
    Describe the real power path; only bistable Paper can be passive while the
    image remains visible.

## Authoritative locations

- `docs/research/`: external evidence, comparisons, experiments, and open
  questions.
- `docs/architecture/`: cross-cutting system and protocol specifications.
- `docs/frames/`: reference-frame requirements and validated configurations.
- `docs/host/`: host application requirements and platform integration.
- `docs/hardware/`: shared physical constraints and candidate BOM policy.

Do not create a parallel `docs/specs/` hierarchy. Put a specification beside
the subsystem that owns it and link it from `docs/README.md`.

## Authoring workflow

1. Use `decision-research` when a decision depends on facts absent from the
   repository.
2. Use `spec-authoring` for new or revised requirements.
3. Run `spec-readiness` before implementation.
4. Apply `evidence-prose` and `unslop` to persisted prose.
5. Use `hardware-validation` for a component selection, build record, or bench
   test.
6. Use `decision-provenance` before reversing an existing boundary or choice.

## Validation

Run checks proportionate to the change. At minimum, inspect the diff, verify
all relative Markdown links, and search edited prose for stale placeholders,
unsupported certainty, and unqualified price or availability claims. Code must
also pass the affected formatter, tests, static checks, and build before the
work is called complete.
