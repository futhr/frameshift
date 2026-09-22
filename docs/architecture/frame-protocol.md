# Frame Protocol v0.1

**Status:** normative implementation draft; security review required before
production

**Scope:** authenticated transfer and activation of still-image artifacts

The words MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY are interpreted as in
[RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).

## 1. Design goals

1. Work on a local network without a Frameshift cloud.
2. Support continuously powered frames and deeply sleeping battery frames.
3. Describe displays by capabilities, not vendor/model branches.
4. Keep expensive transforms and AI off the frame.
5. Make every mutation bounded, authenticated, idempotent, and recoverable.
6. Never replace valid artwork with partial, corrupt, or incompatible bytes.
7. Report physical display outcome separately from network acceptance.
8. Carry still images and still-image playlists only.

## 2. Roles and terms

- **Host:** the trusted Frameshift controller that owns masters and renders
  artifacts.
- **Frame:** a paired display device.
- **Artifact:** immutable bytes in one advertised display profile.
- **Digest:** lowercase hexadecimal SHA-256 of the exact artifact bytes.
- **Desired asset:** the digest the frame should display next.
- **Current asset:** the digest last confirmed by the display adapter.
- **Previous-known-good:** the prior confirmed current asset retained for
  recovery.
- **Direct mode:** an awake frame exposes the API and the host pushes.
- **Outbox mode:** a sleeping frame wakes, connects to the host, and pulls.

## 3. Interaction model

Frames expose a constrained [W3C WoT Thing Description 1.1](https://www.w3.org/TR/wot-thing-description/).
The TD describes properties and actions; HTTPS forms bind them to the resources
below. Frameshift tools preserve unknown namespaced fields and never dereference
remote JSON-LD contexts during normal parsing.

Protocol major `0` is experimental. Any incompatible wire change increments
the major. Additive properties/actions increment the minor. A consumer MUST
reject an unsupported major and MUST ignore an unknown optional minor field.

## 4. Discovery

### 4.1 Direct frames

An awake paired-capable frame advertises `_frameshift._tcp.local` using DNS-SD.
The instance label is an opaque random identifier. TXT records contain only:

| Key | Value |
| --- | --- |
| `v` | protocol major, currently `0` |
| `id` | opaque device ID or its non-reversible short form |
| `path` | exploration path, currently `/.well-known/wot` |
| `pair` | `1` only while physical pair mode is active |

The advertisement MUST NOT include owner, room, artwork, friendly name, panel
model, dimensions, battery level, or network credentials. The full TD requires
authentication. This follows W3C WoT Discovery's introduction/exploration
privacy split.

### 4.2 Host outbox

The Mac MAY advertise `_frameshift-host._tcp.local` while its outbox is
available. TXT contains only protocol major and an opaque paired-host ID. A
sleeping frame already knows the host certificate fingerprint and accepts no
unpaired outbox.

mDNS is link-local. v0.1 does not discover across routed networks or provide
internet remote access.

## 5. Commissioning and pairing

Commissioning installs network credentials and cryptographic identities;
pairing authorizes a host identity. They are distinct even if one UI performs
both.

The hardware-independent v0.1 requirements are:

1. Every frame has a unique TLS key/certificate and at least 128 bits of random
   one-time bootstrap secret.
2. A QR label or equivalent physical record carries device ID, SHA-256 SPKI
   fingerprint, and the bootstrap secret. The secret MUST NOT appear in mDNS.
3. A physical action enables a five-minute pairing window. Network requests
   alone cannot enable it.
4. The host pins the device SPKI fingerprint before sending the bootstrap
   secret and its own client certificate.
5. The frame verifies proof of possession of the client private key, stores the
   allowed certificate fingerprint, and destroys or rotates the one-time secret.
6. Normal protocol traffic uses mutually authenticated TLS.

A temporary USB setup connection is permitted and does not violate a cable-free
installed frame. BLE or temporary access-point commissioning MAY be added by a
hardware profile, but cannot weaken certificate pinning or physical pair mode.

Short numeric PIN authentication without a reviewed PAKE is prohibited. Device
private keys SHOULD live in secure hardware on manufactured devices. Recovery,
host replacement, and factory reset require physical access.

## 6. Transport rules

- HTTPS is mandatory for LAN traffic.
- TLS 1.3 SHOULD be used; any TLS 1.2 fallback must be explicitly profiled and
  independently reviewed.
- Frame and host validate the pinned/allowlisted peer certificate, not just a
  public Web PKI hostname.
- Mutating requests MUST NOT follow redirects.
- Mutating requests MUST NOT be retried unless the method, digest, and
  precondition make the retry idempotent.
- Every request has an absolute deadline. A timeout is an unknown result until
  state is read again.
- Credentials are resolved immediately before transport and never serialized
  into domain requests, results, recipes, TDs, or logs.
- Control JSON uses UTF-8 and `application/json`. Duplicate object keys are
  rejected.
- Errors use `application/problem+json` as defined by
  [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457).

## 7. Bounds

An implementation MAY advertise smaller values. It MUST enforce bounds before
allocation where possible.

| Item | v0.1 upper bound |
| --- | --- |
| Thing Description | 256 KiB decoded bytes |
| Other control JSON | 64 KiB decoded bytes |
| JSON nesting | 32 levels |
| Request target | 1 KiB |
| Header fields | 64 |
| One header value | 8 KiB |
| Asset bytes | advertised `maximumAssetBytes` |
| Playlist entries | advertised `maximumPlaylistLength` |

Asset upload/pull requires a known content length. A frame MAY reject chunked
asset transfer in v0.1. Decompression bombs are avoided by negotiating exact
artifact profiles and validating decoded dimensions before commit.

## 8. Direct-mode resources

The paths below are canonical v0.1 bindings. A TD form remains authoritative
when a future minor version adds an alternative binding.

| Method and path | Purpose | Success |
| --- | --- | --- |
| `GET /.well-known/wot` | Authenticated Thing Description | `200` |
| `GET /v0/state` | Capabilities summary and runtime state | `200` |
| `HEAD /v0/assets/sha256/{digest}` | Test immutable asset presence | `200` or `404` |
| `PUT /v0/assets/sha256/{digest}` | Store verified immutable asset | `201` new, `204` already identical |
| `GET /v0/assets/sha256/{digest}` | Retrieve for audit/recovery when allowed | `200` |
| `DELETE /v0/assets/sha256/{digest}` | Collect an unreferenced asset | `204` |
| `PUT /v0/desired` | Set desired still asset | `200` current or `202` pending |
| `PUT /v0/playlist` | Replace complete still playlist | `200` or `202` |
| `POST /v0/actions/retry-display` | Retry current desired asset | `202` |

Pairing and firmware-update resources are intentionally separate profiles. They
are never inferred from the existence of the display API.

## 9. Asset upload

The upload request MUST contain:

```text
Content-Type: <advertised media type>
Content-Length: <bounded byte count>
Content-Digest: sha-256=:<RFC 9530 base64 digest>:
Frameshift-Artifact-Profile: <advertised profile id>
If-None-Match: *
```

The URI hex digest and `Content-Digest` MUST identify the same bytes. The frame
streams into an inactive temporary slot while hashing. It validates size,
profile, dimensions/header, and digest before atomically publishing the digest
path. A mismatch returns a digest problem and deletes the candidate.

If the digest is already present with matching metadata, the operation is a
successful no-op. If bytes or profile metadata conflict for the same digest,
the frame returns `409` and marks storage health degraded; SHA-256 identity is
never silently redefined.

Upload does not change desired or current state.

## 10. Desired and current state

`GET /v0/state` includes at least:

```json
{
  "stateRevision": 42,
  "displayState": "displayed",
  "desiredAsset": "sha256:0123...",
  "currentAsset": "sha256:0123...",
  "previousKnownGood": "sha256:abcd...",
  "pendingRequestId": null,
  "lastError": null
}
```

The response has a strong ETag derived from `stateRevision`.

`PUT /v0/desired` contains `assetDigest`, `artifactProfile`, and a host-generated
`requestId`. It MUST include `If-Match` with the last read state ETag or
`If-None-Match: *` for initial empty state. The referenced asset must already be
verified.

Processing order is:

1. atomically store desired digest, profile, and request ID;
2. prepare the display adapter without changing `currentAsset`;
3. perform the physical still-image update;
4. on confirmed success, move old current to previous-known-good and desired to
   current in one metadata transaction;
5. on failure, retain current and record a typed error against the request.

Repeating the same PUT with the same request ID and body returns the same
operation/state. Reusing a request ID with different content returns `409`.
A `202` means accepted/pending, not displayed. The host confirms success by
observing `currentAsset` and `displayState: displayed`.

`displayState` is one of `empty`, `preparing`, `refreshing`, `displayed`,
`failed`, or `recovering`.

## 11. Still-image playlists

A playlist is a complete replace operation containing a revision, mode, and
ordered entries:

```json
{
  "revision": "sha256:...",
  "mode": "cycle",
  "entries": [
    {"assetDigest": "sha256:...", "dwellMs": 21600000}
  ]
}
```

All referenced assets MUST already exist. Every dwell MUST meet the capability
minimum. The frame either accepts the whole playlist or none of it. Mode `hold`
shows one selected entry; `cycle` swaps complete cached stills. Crossfades,
scrolling, interpolation, animated formats, and motion transitions are invalid.

Wall-clock schedules are optional and require an advertised trustworthy-clock
capability. Relative dwell playlists do not.

## 12. Sleeping-frame outbox mode

A sleeping frame initiates the connection. Mutual TLS maps the caller to one
device, so the host never accepts a caller-supplied identity as authorization.

| Method and path | Purpose |
| --- | --- |
| `GET /v0/outbox/manifest` | Return desired digest/profile/playlist revision or `204` |
| `GET /v0/outbox/assets/sha256/{digest}` | Stream exact artifact with `Content-Digest` |
| `POST /v0/outbox/ack` | Report verified storage, refresh outcome, and current digest |

The frame first compares the manifest digest with local desired/current state.
It downloads only missing bytes. The host keeps a manifest until a confirmed
ack or the user supersedes it. If the host is absent, authentication fails, or
no work exists, the frame returns to sleep without changing current artwork.

An optional always-on bridge may host the same outbox later. It receives only
rendered artifacts and frame instructions, never AI credentials or the full
host library.

## 13. Error model

Problem details include a stable `type`, human-readable `title`, HTTP `status`,
and `requestId` when safe. Candidate problem types include:

- `urn:frameshift:problem:authentication-required`
- `urn:frameshift:problem:pair-mode-required`
- `urn:frameshift:problem:unsupported-protocol`
- `urn:frameshift:problem:unsupported-profile`
- `urn:frameshift:problem:asset-too-large`
- `urn:frameshift:problem:digest-mismatch`
- `urn:frameshift:problem:asset-missing`
- `urn:frameshift:problem:state-precondition`
- `urn:frameshift:problem:request-id-conflict`
- `urn:frameshift:problem:storage-full`
- `urn:frameshift:problem:display-failed`
- `urn:frameshift:problem:power-insufficient`

Problems MUST NOT contain credentials, bootstrap secrets, private paths, prompt
text, or artwork bytes.

## 14. Storage and recovery

- Current and previous-known-good artifacts are protected.
- Temporary assets older than the profile's recovery window may be removed at
  boot after their metadata journal is examined.
- Garbage collection deletes only unreferenced verified artifacts.
- Metadata updates use redundant records, checksums, and monotonic revisions or
  an equivalent power-loss-safe scheme.
- Boot verifies current metadata and artifact digest before asking the adapter
  to restore output.
- A bistable frame does not refresh merely because it rebooted if the retained
  panel image and confirmed metadata are consistent.

## 15. Compliance tests

A conforming v0.1 implementation must demonstrate:

1. unpaired LAN clients cannot read the full TD, upload, activate, or list
   artwork;
2. power loss at every upload and metadata-write boundary retains a valid
   current asset;
3. a wrong digest, profile, dimension, or oversized body never reaches the
   display adapter;
4. repeated identical PUTs are safe and request-ID conflicts are rejected;
5. a `202` is never reported as physically displayed;
6. current and previous-known-good survive collection and firmware update;
7. a sleeping frame can miss multiple wake windows and later converge on the
   newest outbox manifest;
8. playlist switches are discrete still-image changes;
9. no endpoint accepts video, animated image playback, audio, or arbitrary
   remote fetch URLs;
10. secrets are absent from TDs, logs, errors, and packet captures after the
    encrypted transport boundary.

## 16. Open gates before v1.0

- independent pairing and TLS review;
- exact secure-element and certificate rotation profile;
- commissioning transport per controller;
- conformance fixtures and canonical TD examples;
- final artifact media-type registration/naming;
- measured retry/deadline values for each hardware class;
- recovery behavior when a panel update is interrupted electrically;
- multi-host ownership and revocation policy.
