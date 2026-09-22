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
  custom native and embedded work uses Zig. Nerves is allowed only for an
  optional external bridge, simulator, or powered prototype where a
  Linux-class controller is proven necessary. It is not the default frame
  runtime.
- **Consequence:** Python is forbidden in application code, firmware, build
  tools, scripts, tests, examples, and documented project workflows. An
  upstream project that uses it may inform research but cannot become a
  Frameshift dependency or required workflow.
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
  Zig worker's process-isolation claim.
- **Detail:** [SQLite and Elixir boundary](../research/sqlite-elixir-boundary.md)

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
