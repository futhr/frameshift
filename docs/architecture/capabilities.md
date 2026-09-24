# Capability Model

**Status:** normative draft for Frame Protocol v0.1

Frameshift targets declared physical and artifact capabilities, not product
names. Specific vendor hardware is welcome and may be selected early. Its exact
revision becomes a capability instance and measured artifact/display-adapter
profile; it never creates a vendor branch in the universal interaction model.

The companion [physical build contract](physical-build-contract.md) references
these profile/interface identities while adding exact part revisions, geometry,
mounting, electrical and evidence constraints. A printable configuration is not
paired-device admission, a render qualification or proof of physical display.
Custom parts may have explicit unknowns. New data can reuse a qualified contract;
new protocols, drivers or artifact formats require code and conformance evidence.
Source manufacturer refresh recommendations without inventing energy savings.

The words MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY are interpreted as in
[RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).

## W3C WoT envelope and Thing Model

A paired frame MUST expose a W3C Thing Description 1.1 that instantiates the
Frameshift Frame Thing Model. The document MUST use the W3C 1.1 context and MAY
add the versioned Frameshift context `urn:frameshift:td:v0`. Network code MUST
NOT dereference a context, schema, vocabulary, or Thing Model while admitting a
frame response.

The TD uses:

- properties for capabilities, health, desired asset, current asset, display
  state, brightness, and playlist state;
- actions for asset installation/collection, desired state, playlist
  replacement, display retry, pairing lifecycle, identify, and firmware update
  when supported;
- events for bounded state-change and display-completion notification when
  supported; and
- forms to bind those interactions to one or more qualified transports.

Unknown namespaced extensions MUST survive read/modify/write tooling. Unknown
optional extensions MUST NOT block otherwise compatible interactions. Unknown
required semantic, binding, security, or artifact profiles MUST be rejected
before transport or rendering; the host never guesses a downgrade.

The host selects operations by semantic affordance name, compatible Form, and
artifact profile. It MUST NOT select endpoints, renderer behavior, or security
policy from a vendor or model string.

The TD's top-level `profile` member lists required Frameshift semantic and
binding profiles as URI identifiers. The v0.1 semantic identifier is
`urn:frameshift:profile:frame:0.1`. Profiles are Frameshift contracts; the
project does not claim conformance to the W3C WoT Profiles Working Draft.

## Required capability groups

### Identity and protocol

| Field | Requirement |
| --- | --- |
| `protocolMajor` | Frameshift semantic profile incompatible-change boundary |
| `protocolMinor` | Frameshift semantic profile additive level |
| `deviceId` | Stable opaque identifier; no owner/location semantics |
| `hardwareRevision` | Exact board/panel assembly revision |
| `firmwareVersion` | Immutable build/version identifier |
| `stillOnly` | MUST be `true` in v0.1 |
| `transferModes` | Non-empty subset of `push`, `pull` |

### Geometry

- exact pixel width and height;
- active width and height in millimetres when known;
- orientation transform supported by the frame;
- safe inset in pixels for mat/overscan protection;
- pixel aspect ratio, defaulting to 1:1 only when true.

Physical dimensions are not decoration: they let the host preview crop, scale,
viewing density, and passe-partout loss.

### Color

Continuous-color frames declare accepted color spaces, transfer function,
channel order, bit depth, alpha handling, and ICC/profile identifier if used.

Restricted-palette frames declare an ordered palette. Every entry contains a
wire code and preview sRGB value. The advertised palette revision identifies
the measured conversion profile, not merely the pigment marketing name.

Pixel frames additionally declare brightness range, hardware maximum, applied
gamma/profile revision, and whether incoming values are straight RGB or
already power-limited.

### Refresh

| Field | Meaning |
| --- | --- |
| `refreshKind` | `sample-and-hold`, `global-bistable`, or `scanned-emissive` |
| `typicalRefreshMs` | Observed/declared time to a confirmed still update |
| `maximumRefreshMs` | Host deadline basis |
| `minimumDwellMs` | Shortest accepted still-image dwell |
| `recommendedDwellMs` | Optional profile suggestion for a new cycle; at least the minimum |
| `recommendationBasis` | Required with a suggestion: `measured-energy` or `provisional-profile` |
| `recommendationRevision` | Required bounded identifier for the recommendation evidence/profile version |
| `partialRefresh` | Supported modes and region alignment, or absent |
| `flashDuringRefresh` | Whether visible global flashing is expected |

No v0.1 field advertises video or animation support.
The suggestion is not a scan frequency or proof of battery life. See
[display timing](display-timing.md) for evidence and override rules.

### Power

`powerClass` is one of:

- `bistable-sleeping`: retains image with main rails off;
- `continuous-emissive`: input power is required while visible;
- `continuous-high-current`: emissive and subject to a hardware brightness/
  current ceiling.

The frame also declares whether it is currently on external power or battery,
battery percentage only when measured credibly, next scheduled wake for a
sleeping frame, and whether remote wake is possible. The host MUST NOT assume a
sleeping frame is immediately reachable.

### Storage and artifacts

The frame declares:

- maximum single asset bytes;
- total and currently available asset bytes;
- maximum stored asset count;
- digest algorithms (v0.1 requires SHA-256);
- accepted artifact profiles with media type, exact/maximum dimensions,
  row alignment, byte order, palette/profile revision, and compression;
- maximum playlist length.

An artifact profile is an atomic compatibility unit. Matching only MIME type is
not sufficient. It can name an exact vendor panel, controller, palette,
waveform, packing, gamma, or electrical limit after those properties have been
qualified. That name selects bytes and adapter behavior; it does not alter the
Frame Thing affordances.
The host records the canonical digest of the selected profile and relevant
capability instance in its [qualification](qualified-generations.md). Reusing a
profile name after any byte-affecting property changes does not reuse the old
render result or silently rebind accepted work.

## Reference capability classes

These classes are reusable examples and conformance cohorts, not an exhaustive
device list. A frame that does not call itself Paper, Photo, or Pixel remains
compatible when its declared capabilities and Forms satisfy the contract.

### Paper

```text
displayClass: restricted-palette-reflective
powerClass: bistable-sleeping
transferModes: [pull]
refreshKind: global-bistable
stillOnly: true
```

The exact palette and packer revision are mandatory. The host respects the
long refresh and minimum dwell; the UI reports next contact rather than showing
the frame as generically offline.

### Photo

```text
displayClass: continuous-color-raster
powerClass: continuous-emissive
transferModes: [push, pull]
refreshKind: sample-and-hold
stillOnly: true
```

The controller accepts a still framebuffer or decodable still artifact. It
does not advertise a video codec.

### Pixel

```text
displayClass: low-resolution-emissive-matrix
powerClass: continuous-high-current
transferModes: [push, pull]
refreshKind: scanned-emissive
stillOnly: true
```

Logical geometry, physical module mapping, scan configuration, color depth,
gamma, brightness ceiling, and artifact channel order are mandatory.

## Validation rules

The host MUST reject a capability document when:

- its decoded size exceeds 256 KiB, nesting exceeds 32, or required strings
  exceed documented bounds;
- `protocolMajor` is unsupported;
- geometry is zero, negative, or inconsistent with the chosen profile;
- a palette has duplicate wire codes or exceeds the profile bit width;
- an artifact profile is incomplete;
- a numeric field is NaN, infinite, or outside its schema;
- the frame claims a v0.1 motion capability.

Capabilities describe what the exact running assembly supports. They are not a
promise that an operation succeeded; runtime properties report that result.
