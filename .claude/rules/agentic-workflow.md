# Agentic workflow

## Read before changing

- Read `README.md`, `docs/README.md`, and the documents that own or consume the
  affected contract.
- Search `docs/research/`, `docs/research/open-questions.md`, and Git history
  before repeating research or reversing a decision.
- For a decision based on external facts, complete `decision-research` before
  changing a specification.
- For implementation, confirm the owning specification passes
  `spec-readiness` first. If no specification exists, write or revise it before
  coding unless the change is a narrow defect with already-defined behavior.

## Preserve evidence boundaries

- A vendor statement is sourced evidence, not a measurement.
- A marketplace listing is a dated sourcing observation, not an architecture
  contract.
- A bench result applies only to the recorded revision, wiring, firmware,
  configuration, power conditions, and environment.
- An unbuilt design remains a candidate even when every individual data-sheet
  value appears compatible.
- Never promote research language to a requirement without recording the
  decision and its acceptance evidence.

## Language boundary

- Do not add Python source, environments, package managers, generated wrappers,
  scripts, tests, examples, or Python-dependent documented workflows.
- Prefer Elixir/OTP for host orchestration, Zig ports for native work and
  project-owned MCU firmware, and a bounded Swift/SwiftUI macOS shell for Apple
  APIs. Nerves is limited to an optional external bridge, simulator, or
  evidence-backed powered prototype; it is not the default frame runtime.
- A useful upstream project that requires Python is research evidence, not an
  admissible dependency.
- Do not add Raspberry Pi hardware to a Frameshift reference build. A project
  using it may still provide cited timing or protocol evidence.
- Do not add Membrane or any video, motion, animation, audio, or streaming
  path. Frameshift transfers and displays immutable still-image artifacts.

## Choice-preserving hardware work

- Treat Paper, Photo, and Pixel as independent paths. Do not impose a universal
  order or require a builder to implement every class.
- Recommend a cheap prototype of the selected path's riskiest assumption before
  premium hardware or finished joinery, but never present that recommendation
  as a prerequisite for participation.
- Treat zero visible cable as a high-priority design goal, not a universal
  requirement. Record the actual power source and route.

## Verify as work progresses

- Check edited Markdown links and document indexes after documentation changes.
- Run the narrowest relevant test immediately after a code change, then run all
  affected checks before completion.
- Inspect the final diff for scope drift, unsupported claims, leaked secrets,
  local-only paths, placeholders, and accidental vendor coupling.
- Report unavailable physical, credentialed, hardware, or platform proof as a
  remaining validation step. Do not imply that source inspection replaced it.

## Git behavior

- Do not commit, push, rewrite history, or change repository visibility unless
  the applicable action was explicitly requested. Repository visibility may
  never be changed by an agent.
- Keep changes coherent and preserve unrelated work in a dirty worktree.
- Never add co-author trailers or AI-tool attribution.
