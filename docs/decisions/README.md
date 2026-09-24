# Decision Ledger

This ledger records decisions that materially constrain Frameshift. It is not
a substitute for the detailed specifications linked from each entry. A
decision can change when measurements or upstream changes invalidate its
evidence, but it must change explicitly.

## D-001 — Product name

- **State:** accepted
- **Decision:** The product and project name is **Frameshift**.
- **Consequence:** All other capitalizations and word breaks are incorrect in
  product copy, source identifiers, and protocol names.

## D-002 — Still images only

- **State:** accepted
- **Decision:** Frameshift displays still images. It does not render video,
  animation, live streams, motion graphics, or animated transitions.
- **Consequence:** A slideshow is a sequence of independently cached still
  assets with discrete swaps and dwell times. Membrane and media-streaming
  infrastructure are outside the architecture.
- **Rationale:** This matches the product intent and removes continuous
  decoding, frame-rate, streaming, and audio concerns from every layer.

## D-003 — Language boundary

- **State:** accepted
- **Decision:** Elixir/OTP is the host orchestration language;
  Swift/SwiftUI is the smallest practical macOS shell and Apple API bridge;
  the existing isolated host renderer uses Zig. Nerves is the selected base
  for a separately qualified dedicated Pi 5 bridge/appliance. Select MCU
  firmware language and toolchain from exact board, display, security, and
  recovery evidence.
- **Consequence:** Frameshift-owned application, firmware, scripts, tests, and
  examples contain no Python. A pinned upstream toolchain may run Python in
  an isolated reproducible build; its provenance and output are release
  evidence. It is never a shipped application runtime.
- **Detail:** [Software stack research](../research/software-stack.md)

## D-004 — Host-rendered immutable artifacts

- **State:** accepted
- **Decision:** The Mac retains source masters and renders immutable,
  display-specific artifacts. Frames store and display validated artifacts.
- **Consequence:** The frame never needs an AI model or a general image editor.
  A renderer upgrade can reproduce target artifacts from the source and recipe.
- **Detail:** [Content pipeline](../architecture/content-pipeline.md)

## D-005 — Local-first AI with explicit fallback

- **State:** accepted with provider qualification gates
- **Decision:** Local generation is preferred. Draw Things/
  MediaGenerationKit is the current dependable Apple Silicon candidate;
  Ollama remains an experimental adapter subject to runtime preflight. Draw
  Things+ is the preferred subscription-backed cloud candidate. Gemini image
  models are optional metered API providers or manual-import sources.
- **Consequence:** Consumer web subscriptions are never automated or presented
  as API entitlement. Cloud use requires an explicit destination and cost
  disclosure before generation.
- **Detail:** [AI image generation research](../research/ai-image-generation.md)

## D-006 — W3C WoT capability envelope

- **State:** accepted for protocol v0.1
- **Decision:** Frames and host outboxes use W3C Web of Things Thing Description
  1.1 and reusable Thing Models. Frameshift adds a small namespaced still-display
  vocabulary. Properties, Actions, Events, and Forms separate semantic
  interactions from HTTPS, CoAP, MQTT, BLE, Matter, or gateway bindings.
- **Consequence:** Implementations preserve unknown extensions, bound parsing,
  do not fetch remote JSON-LD contexts at runtime, select advertised Forms
  deterministically, and never derive compatibility or endpoints from a vendor
  name. Exact hardware revisions remain first-class artifact/display-adapter
  profile data.
- **Detail:** [Frame Protocol](../architecture/frame-protocol.md) and
  [protocol foundations](../research/protocol-foundations.md)

## D-007 — Content addressing and atomic activation

- **State:** accepted for protocol v0.1
- **Decision:** Asset bytes are addressed by SHA-256. Upload and activation are
  separate. A complete, verified asset becomes desired state through an atomic
  pointer change; current state changes only after the adapter succeeds.
- **Consequence:** Interrupted transfers cannot replace displayed artwork.
  Frames retain current and previous-known-good assets through garbage
  collection.

## D-008 — Thin electronics and honest power classes

- **State:** accepted constraint; controllers remain candidates
- **Decision:** No Raspberry Pi hardware belongs in a Frameshift reference
  build.
  Paper targets a sleeping MCU and battery. Photo and Pixel use thin embedded
  controllers and concealed/remote continuous power because their panels are
  emissive.
- **Consequence:** “Cable-free and passive” is a Paper-frame capability.
  “No visible cable” for Photo and Pixel requires an installation accessory,
  wall contact, or concealed low-voltage wiring; it does not mean no power
  connection. Controller boards, connectors, bend radii, batteries, converters,
  and thermal clearances all count toward depth.
- **Detail:** [Hardware platform research](../research/hardware-platforms.md)

## D-009 — No mandatory cloud

- **State:** accepted
- **Decision:** Local import, deterministic rendering, discovery, transfer,
  caching, playlists, and display operation work without a Frameshift cloud.
- **Consequence:** AI providers, remote access, and managed firmware services
  are optional adapters, never prerequisites for showing existing artwork.

## D-010 — Host metadata boundary

- **State:** accepted; release qualification gates remain
- **Decision:** One Frameshift-owned OTP process serializes metadata access
  through Exqlite. The implementation uses direct SQL and numbered
  migrations rather than Ecto. Immutable artwork bytes remain in the
  content-addressed file store.
- **Consequence:** Transaction and reference-protection invariants stay in one
  owner. No other module receives the database connection. The Exqlite NIF is a
  packaging and crash-recovery validation dependency and does not inherit the
  Zig worker's process-isolation claim. NodeDB Lite, CubDB, and analytic
  engines do not replace the authoritative ledger; search projections remain
  rebuildable.
- **Detail:** [SQLite and Elixir boundary](../research/sqlite-elixir-boundary.md)
  and [embedded persistence review](../research/embedded-persistence.md)

## D-011 — Universal WoT interaction boundary

- **State:** accepted; implementation and interoperability gates remain
- **Decision:** Frameshift semantics are defined as W3C WoT Thing Models,
  Thing Descriptions, affordances, DataSchemas, and Forms. The reference HTTPS
  binding is one transport mapping, not the protocol identity. Additional
  bindings may coexist when they preserve the same state and effect contract.
- **Consequence:** Hosts consume advertised Forms and preserve unknown optional
  extensions. Required unknown profiles fail explicitly. Specific vendors,
  panels, controllers, and packers are represented by exact capability and
  artifact-profile data, not conditional endpoint logic.
- **Implementation reference:** The sibling Wotex checkout supplies patterns
  for bounded admission, deterministic selection, explicit credential and
  transport ports, supervised subscriptions, and evidence-scoped conformance.
  Frameshift consumes the qualified Wotex packages from the Wotex GitHub
  organization at one pinned full commit; it still owns binary artifact
  transfer, transport security policy, canonical state, and proof of physical
  display effects.
- **Detail:** [Protocol foundations](../research/protocol-foundations.md) and
  [Universal Frame Protocol](../architecture/frame-protocol.md)

## D-012 — Portable domain boundaries

- **State:** accepted as a software design; platform qualification remains
- **Decision:** Organize the host as a modular monolith with Library, Frames,
  Delivery, Rendering, and Generation domain boundaries. Diagnostics supports
  them all. Delivery owns desired, confirmed displayed, and previous-known-good
  transitions; Frames exposes their read projection. One SQLite writer retains
  the cross-boundary atomic invariants.
- **Consequence:** A context is not a separate process, database, or generic
  repository interface. Domain decisions are independent of storage and IPC
  representations. D-010 remains in force; adding Ecto is not a domain
  architecture requirement.
- **Detail:** [Host domain map](../architecture/domain-map.md)

## D-013 — Local diagnostic signals and OS log readers

- **State:** accepted as a software design; installed/platform evidence remains
- **Decision:** Store audit facts with domain mutations, aggregate bounded
  local metrics from named telemetry events, and send operational logs to
  native OS logging. Console.app and `/usr/bin/log` are the macOS log readers;
  a read-only authenticated CLI exposes health, metric rollups, and audit.
- **Consequence:** Logs and metrics are not authoritative display state. The
  Mac's privileged local log-store API is not an application diagnostic
  dependency. No diagnostic UI or remote telemetry service is required.
- **Detail:** [Diagnostics contract](../architecture/diagnostics.md) and
  [host diagnostics research](../research/host-diagnostics.md)

## D-014 — Qualified render and transfer generations

- **State:** accepted as a software design; qualification implementation and
  physical evidence remain open
- **Decision:** Admit a reusable renderer/profile/transfer qualification for
  each exact frame capability instance. Pin each accepted render and transfer
  workflow to an immutable work digest combining that qualification with its
  source and recipe. The work identity exists before rendering; the exact
  wire-byte digest is attached as a result. Accepted work retains its binding
  across activation, rollback, and restart.
- **Consequence:** The artifact digest remains SHA-256 of the exact wire bytes.
  A successful transfer cannot stand in for display confirmation. Qualification
  and activation are durable local host decisions; cloud tenancy and a remote
  composition service are not prerequisites.
- **Detail:** [Qualified generations](../architecture/qualified-generations.md)

## D-015 — Public guide and native installation

- **State:** accepted delivery design; public release evidence remains open
- **Decision:** Publish an accessible static installation guide first at
  `frameshift.wotex.io`. Mac direct download, Homebrew Cask, and Sparkle consume
  one signed and notarized release artifact. Ubuntu uses architecture-specific
  packages authenticated by a signed release manifest or APT repository;
  public binaries live in a separate release channel created
  public from the outset. The private source repository's visibility is never
  changed as part of distribution.
- **Consequence:** `frameshift.se` is optional. No public release claim or
  install command precedes signing, licensing, notices, clean-install tests,
  and manifest/digest verification.
- **Detail:** [Installation and interactive guide](../architecture/install-and-guide.md)

## D-016 — Shared browser decision kernel

- **State:** accepted design; generated cross-target parity passes locally,
  while browser and installed release acceptance remain open
- **Decision:** Extract a bounded pure decision kernel into Gleam, compiled
  from the same source to Erlang for the host and JavaScript for the public
  installation simulation. The browser runs locally and holds no pairing
  credentials or delivery authority. Exact raster bytes remain the Zig
  renderer's responsibility.
- **Consequence:** The guide can demonstrate capability and failure behavior
  without a hosted Elixir execution service. BEAM/JavaScript parity and safe
  integer bounds are release gates. Native deep links carry non-secret setup
  choices only; pairing remains an installed-app action.
- **Detail:** [Installation and interactive guide](../architecture/install-and-guide.md)

## D-017 — Linux host and Pi appliance roles

- **State:** accepted platform design; installed qualification remains open
- **Decision:** Ubuntu amd64/arm64 and Ubuntu Server arm64 on Pi 5 reuse the
  portable host core. A Nerves Pi 5 image is a separate dedicated external
  bridge/appliance with its own signed firmware lifecycle. No Pi enters a
  reference frame.
- **Consequence:** Linux service identity, credentials, journald, package
  updates, and native dependencies need platform tests. Nerves uses persistent
  `/data`, firmware validation/revert, and a bounded OTP log sink instead of
  systemd facilities. Neither role needs a vendor cloud to show artwork.
- **Detail:** [Linux host](../host/linux.md)

## D-018 — Companion platform and repository ownership

- **State:** accepted design, 2026-09-24; implementation evidence open
- **Decision:** Build the companion platform with Phoenix, Ash/AshPostgres and
  phoenix-assets/Svelte 5/SvelteKit. Embed one qualified external Refpath runtime.
  Frameshift packs, physical models, rubrics and evaluations live in Frameshift.
  Establish monorepo dependency boundaries before verified directory moves.
- **Consequence:** Commercial server domains never replace the local single-writer
  SQLite core or make ordinary frame operation depend on accounts. The static
  installation/offline guide remains available; D-015 does not require the entire
  companion application to be static. Generic tooling/runtime changes go upstream.
- **Detail:** [Build platform](../architecture/build-platform.md)

## D-019 — Independent shopping first, dropshipping last

- **State:** accepted scope and ordering, 2026-09-24
- **Decision:** Deliver the full visual configurator and printable exact shopping
  list in D, then complete research/operational qualification in E. Optional
  supplier-direct purchasing, percentage fees, fulfillment and care are final
  milestone F. Preparation can overlap by dependency; F starts only after D/E.
- **Consequence:** Shopping-list usefulness cannot depend on live checkout,
  supplier APIs or an account. No mandatory lead assembler, stockholding or
  Frameshift-branded assembled hardware. This supersedes the corresponding
  assumptions in the `7527cb3` build-branch proposal. Role/contract review gates
  real transactions; external administration and hardware measurements are not
  additional software milestones or grounds to omit codeable work.
- **Detail:** [Commerce](../architecture/build-commerce.md),
  [implementation order](../architecture/implementation-plan.md)

## D-020 — Deterministic composition, bounded formal checks and evaluated models

- **State:** accepted boundaries, 2026-09-24; physical kernel/formal implementation
  and Frameshift model benchmarks remain open
- **Decision:** Extend pure Gleam decisions for BEAM/JavaScript physical
  compatibility. Use ExMaude for targeted CI/async verification with independent
  predicates, explicit search outcomes and counterexample replay. Use explicit
  controls/rules first; evaluate local Ollama and compact models per task, with
  Jev an optional challenger. No model receives compatibility or spending authority.
- **Consequence:** The generic ExMaude completion/trace contract needs upstream
  work; bounded empty search is not exhaustive proof. Frameshift owns formal
  models. No candidate classifier creates an exception to D-003's no-Python rule.
- **Detail:** [Physical contract](../architecture/physical-build-contract.md),
  [orchestration/evaluation](../architecture/build-orchestration.md),
  [research](../research/build-platform-decisions.md)

## D-021 — Read-only server investigation and independent telemetry

- **State:** accepted design, 2026-09-24; production qualification open
- **Decision:** Include Beamlens explicitly in the server dependency graph with
  one configured supervisor, authorized bounded observations and no domain-write
  authority. Configure and budget its BAML provider separately from Refpath's
  ordinary inference path; account for both centrally.
- **Consequence:** Early-development dependency/skill behavior needs exact-version
  qualification. Provider outage and exhausted budgets cannot disable ordinary
  telemetry, alerts or app actions. D-013 native Console.app/CLI access remains.
- **Detail:** [Diagnostics](../architecture/diagnostics.md)
