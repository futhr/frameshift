# Build artifact layouts and storage footprint

**Status:** normative design under PB-04/PB-05; implementation evidence belongs
in the [verification map](verification.md). This extends the
[physical BuildSpec contract](physical-build-contract.md), without granting
paired-device admission or [render-generation qualification](qualified-generations.md).

These are Frameshift raster, display-routing and retention obligations within
the [Conjunct product profile](conjunct-integration.md). They remain product-owned
even if rectangle or bounded-arithmetic primitives are extracted. The v1 layout
domain/bytes remain valid until an explicit successor migration is qualified.
Procedure scenes and CAD delivery meshes are different artifacts from the
still-image canvases defined here.

## Ownership and scope

The builder records one logical still-image canvas per controller. Explicit
pixel placements map that canvas to its physical displays. The shared Gleam
v1 compiler checks raster coverage, encoding limits, exact wire size and
retained artifact storage on both runtimes. These are Frameshift profile
obligations; Conjunct owns the successor's generic check aggregation and
composition report. No image bytes, artwork or inference enters these
calculations. The installed host still admits the actual authenticated device
and its advertised artifact profile.

Pixel placements are distinct from enclosure dimensions in micrometres. Do not
infer pixel offsets, orientation or controller wiring from physical proximity.
Qualified runtime/driver evidence must bind the logical assignment to the
actual display route and physical orientation. Geometric coverage alone cannot
establish that a controller sends pixels to the intended panel.

## Layout inputs

A sourced component profile describes component constraints. An artifact layout
instead records the builder's explicit intended pixel assignment. Each layout
selects a controller instance, artifact/firmware/protocol contract IDs, encoding,
canvas width/height and one to 64 tiles. A tile selects a display instance and
integer `x`, `y`, `rotation`. Rotation is clockwise 0/90/180/270 degrees from
the display's native raster. No scaling, clipping, mirroring or implicit tile
ordering is supported by this revision.

Use at most 64 layouts and 64 tiles across the entire build. Controllers and
displays reference existing assembly instance IDs. Each controller has at most
one layout, and a display may appear only once across all layouts. Duplicate
assignments, dangling instance IDs, malformed identifiers and counts are input
refusals. Canvas width/height are integers 1–32,768; tile coordinates are
integers 0–32,768. These are software limits, not manufacturer capabilities.
Encoding and runtime identifiers use the existing bounded identifier syntax.

Omitted layouts remain valid planning input. Every resolved controller still
receives a missing-layout unknown, and every resolved display receives an
unassigned-display unknown when omitted. Missing profiles remain unknown
classification. A layout attached to a known non-controller or a tile attached
to a known non-display is incompatible. Each tile's declared controller owner
must be the selected layout controller; missing/ambiguous owners stay unknown,
and a known different owner is incompatible. Layout runtime IDs must equal the
assembly's selected intent; supplied stale selections are input refusals.

## Raster and encoder checks

Read each tile's exact positive `raster.width` and `raster.height` count facts.
A range with unequal endpoints is unknown; never choose a nominal or upper
dimension as its actual raster. Quarter turns swap width and height. The
resulting rectangle starts at the tile's integer pixel offset.

Every tile rectangle must lie entirely inside the canvas. Rectangles may touch
at edges, but may not overlap. Their union must cover the entire canvas;
holes or duplicate coverage are incompatible. Unknown raster rectangles keep
their own constraints unknown. Reuse the bounded rectangle-union algorithm,
preserving individual tile operands and coverage evidence. No bounding-box or
summed-area shortcut can establish coverage. This revision does not describe
intentional black gaps, mirrored displays or partial crops; those need an
explicit future layout contract.

The first executable encoding is `rgb24-srgb-v1`: uncompressed, tightly packed
RGB, eight bits per channel, sRGB transfer/colour space, one-byte row alignment,
no byte-order choice and no artifact header. Exact wire bytes are
`canvas_width × canvas_height × 3`. Reuse the installed renderer's limits:
each axis at most 32,768 and at most 16,777,216 pixels. A selected larger canvas
is incompatible with this renderer even if its physical displays could accept
it. Other encoding identifiers remain unknown, without a guessed byte count or
silent fallback. Adding an encoder requires its executable implementation,
wire definition and conformance evidence.

Each controller supplies sourced component `artifact.maximum` (`byte`,
nonnegative), the guaranteed maximum individual artifact payload accepted under
the selected runtime contract. Compare exact wire bytes with its least available
bound. Missing/conflicting facts remain unknown. Do not use total storage
capacity as an individual-artifact limit. The runtime mapping must additionally
cover colour, renderer/profile selection, tile assignment and driver behavior;
these arithmetic checks cannot qualify that mapping.

## Retention budget

The selected controller supplies `storage.retained_artifacts` (`count`, positive)
as the complete bound on distinct artifact payloads that its selected runtime
can retain simultaneously. The source must cover active and staged playlists,
pending uploads, current and previous-known-good custody, and recovery behavior
under that runtime's documented queue limits. It is not the current cache size,
an average deduplication rate or a user-provided estimate. Unsupported retention
scope remains unknown at qualification, even when a numeric declaration exists.

Require the least declared retention bound to be at least three so current,
previous-known-good and a distinct incoming artifact can coexist. Use the largest
declared bound when computing storage. No slot defaults to zero, and identical
test art cannot justify assuming payload deduplication. All payloads for one
layout have the same exact size under the admitted encoding.

Required payload storage is `wire_bytes × retained_artifacts.maximum`. Compare
it with `intent.storage_bytes`. The existing storage allocation stage separately
requires the controller's integrated or dedicated storage capacity to cover that
intent. Together these checks prevent an undersized configured budget even when
the physical storage device itself is larger. `storage.capacity` remains usable
artifact-payload bytes after filesystem, per-object allocation, metadata,
journal, firmware and other reserves under the qualified storage contract;
raw chip capacity or currently free bytes cannot supply it.

The profile count ceiling is 1,000,000. The largest intermediate is
`32,768 × 32,768 × 3 × 1,000,000 = 3,221,225,472,000,000`, below both runtimes'
exact integer ceiling. Check each controller separately; do not pool storage
or sum unrelated controller capacities. A large but exactly calculable footprint
can be incompatible without becoming an overflow or an unknown.

## Identity and evidence

The schema-1 canonical document contains exactly `artifact`, `controller`,
`encoding`, `firmware`, `height`, `protocol`, `schema`, `tiles`, `width` in that
order. Tile objects contain `display`, `rotation`, `x`, `y` in order and sort by
unique display ID. Structural validation enforces the bounds and identifiers
above; assembly reference, runtime-selection and global assignment checks follow
during context resolution. An unknown encoding remains a valid desired input,
with unknown execution/footprint findings from the compiler.

Use the existing 262,144-byte/depth-16 ASCII JSON resource gate, decimal integers,
exact reencoding and one final LF. Refuse duplicate/unknown fields, ambiguous
numbers or escapes, invalid bounds and unsupported schema versions. Typed export
sorts tiles but does not silently remove duplicates. Hash canonical bytes after
`frameshift.artifact-layout.v1\n` with standard OTP/Web Crypto SHA-256 and return
the existing `sha256:<lowercase hex>` identity. The `layout_identity` /
`layoutIdentity` adapters never trust a supplied digest and return bounded errors;
browser cryptography loss cannot produce a substitute identity.

Compilation context accepts an additional optional collection of zero to 64
layout bodies, with the same shared 4 MiB budget across assembly, profiles,
signal mappings and layouts. Snapshot browser arrays before async hashing.
Recompute every layout pin, preserve its complete document, sort by identity,
then run the typed selection checks. Exact context bindings include
`kind: "artifact-layout"`; sort all binding objects together by canonical bytes.
The context schema/domain remain unchanged because the binding type is explicit.
Omitting the layout collection preserves the earlier context bytes and hash,
while the final compiler must still report missing mandatory layouts. Wrong
known controller/display kinds remain explained incompatibilities from the
artifact stage; dangling IDs and stale selected runtime scope are input refusals.

Compilation context binds layout identities alongside signal mappings. Keep layout references separate from
profile facts and signal-mapping references. Every finding retains the selected
controller/display, exact layout fields, owner dependencies, intent, raster facts
and storage-limit citations used in the result.
Rectangle evidence carries an explicit unit: `count` for logical pixel edges
and `um` for physical viewing regions. A renderer of the report must preserve
that distinction.

An internal typed calculation stage may precede the portable codec, but cannot
authenticate a caller-supplied identity. Until the context resolver validates
layout bytes and recomputes their pins, that stage is not a public acceptance
boundary. The final compiler always runs layout/footprint obligations; empty
caller data cannot disable them.

Codec/context acceptance includes exact both-target bytes/hash, independent
standard-crypto pins, source-document and layout mutations, input-order
independence, duplicate/global tile assignments, malformed imports, combined
resource limits, missing encodings/profiles and absent cryptography. Accepted
documents must round-trip offline without artwork or catalog access.

## Acceptance

Cover single and tiled canvases, every quarter turn, exact edge contact, gaps,
overlap, oversized tiles, repeated component profiles, wrong/ambiguous owners,
missing assignments, stale runtime IDs, unresolved profiles and unknown formats.
Check byte counts against independent raster enumeration on small cases and
cross-runtime generated fixtures. Exercise pixel/count/byte boundaries,
retention below three, missing/conflicting storage declarations and an artifact
that fits individually but cannot coexist with retained copies. Maximum tile
counts and arithmetic intermediates must remain bounded and exact. Physical
driver, storage and refresh evidence remains separate from these software checks.
