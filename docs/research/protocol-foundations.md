# Protocol Foundations

**Research date:** 2026-09-22

**Outcome:** HTTPS on the local network, DNS-SD introduction, a constrained W3C
WoT Thing Description 1.1 profile, immutable digest-addressed assets, and atomic
desired-state activation.

## Standards reused

| Concern | Foundation | Frameshift use |
| --- | --- | --- |
| Local introduction | [mDNS RFC 6762](https://datatracker.ietf.org/doc/rfc6762/) and [DNS-SD RFC 6763](https://datatracker.ietf.org/doc/rfc6763/) | `_frameshift._tcp.local` service on the local link |
| Capability/interface description | [W3C WoT Thing Description 1.1](https://www.w3.org/TR/wot-thing-description/) | Properties and actions with a small Frameshift extension vocabulary |
| Privacy-preserving discovery | [W3C WoT Discovery](https://www.w3.org/TR/wot-discovery/) | Minimal introduction; authenticated exploration |
| Upload integrity | [RFC 9530 Digest Fields](https://datatracker.ietf.org/doc/html/rfc9530) | `Content-Digest: sha-256=:...:` plus digest-addressed URI |
| HTTP semantics | RFC 9110 family | Idempotent `PUT`, conditional requests, explicit status codes |
| Structured errors | [RFC 9457 Problem Details](https://datatracker.ietf.org/doc/html/rfc9457) | `application/problem+json` terminal errors |
| Requirements language | [RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174) | Meaning of uppercase normative terms |

The W3C interaction model already covers properties, actions, events, forms,
data schemas, and security declarations. Its security model also says secrets
must not be stored in a Thing Description. Frameshift therefore profiles it
rather than creating a parallel capability document.

## Lessons from Wotex

The sibling Wotex work is useful as a semantic and implementation reference,
but Frameshift does not depend on an unpublished sibling checkout. The adopted
patterns are:

- preserve unknown TD extensions and encode deterministically;
- never fetch remote JSON-LD contexts while parsing a frame response;
- bound JSON size, nesting, string length, array length, and total asset size;
- resolve credentials only at the transport boundary and redact them from
  request/result values;
- use absolute deadlines; no hidden retry or redirect on mutations;
- report protocol success separately from physical display success;
- give every long-lived subscription or task an explicit supervisor owner;
- return structured, typed failures rather than prose-only errors.

These are design patterns, not copied source. Before importing any Wotex code,
the package publication status and license must be recorded.

## Why HTTP rather than CoAP in v0.1

HTTP over TLS has strong library support on macOS and embedded stacks, supports
streamed uploads and standard digest/conditional semantics, and is easy to
inspect during hardware bring-up. CoAP can be reconsidered only if measurements
show HTTP is a material resource or power problem. A sleeping Paper frame may
initiate an HTTPS exchange and pull from a paired host outbox rather than remain
awake for incoming requests.

## Discovery privacy

W3C WoT Discovery separates introduction from exploration so metadata can be
authorized. Frameshift follows that split:

- DNS-SD advertises an opaque instance, protocol major, port, and exploration
  path—never the owner's name, artwork title, room, display model, or dimensions;
- the full Thing Description requires a paired client certificate;
- an unpaired frame exposes only the pairing endpoint while physical pair mode
  is active.

mDNS is link-local by design. Cross-VLAN or remote discovery is not part of
v0.1; a future relay must have its own threat model.

## Pairing research conclusion

A short numeric PIN without a password-authenticated key exchange is not enough
against an active local attacker. The v0.1 prototype therefore uses physical
possession plus high-entropy bootstrap material:

1. manufacturing or USB provisioning creates a device TLS key/certificate and
   at least 128 bits of random, one-time bootstrap secret;
2. a QR label contains the device ID, certificate SPKI SHA-256 fingerprint, and
   bootstrap secret; a grouped manual code is an accessibility fallback;
3. a physical button enables pairing for five minutes;
4. the Mac pins the advertised device certificate, submits the one-time secret
   and its client certificate, and proves possession of the client key;
5. the frame stores the client-certificate fingerprint and destroys the
   bootstrap secret after the first successful pair;
6. all normal requests use mutually authenticated TLS.

Prototype MCU devices without secure hardware may keep a software key in a
protected flash region with explicit development status. A manufactured frame
should use an appropriate secure element after provisioning and recovery are
tested. An optional Nerves bridge can use NervesKey/ATECC608-class storage;
NervesKey keeps private-key operations in the chip and supports X.509, but its
provisioning locks configuration and must be treated as a manufacturing
operation. That library is evidence for the security pattern, not a dependency
of Zig MCU firmware. Source: [NervesKey documentation](https://hexdocs.pm/nerves_key/readme.html).

This pairing design still needs an independent security review, certificate
rotation design, multi-user authorization policy, and lost-host recovery test
before protocol v1.0.

## What not to copy

- Do not advertise the complete TD in mDNS TXT records.
- Do not accept a digest supplied only inside mutable JSON; verify streamed
  bytes against RFC 9530 `Content-Digest` and the digest URI.
- Do not automatically follow a redirect to another host carrying frame
  credentials.
- Do not retry a display-changing request unless its method/precondition makes
  the retry demonstrably idempotent.
- Do not equate an HTTP success with the panel showing the asset. Read
  `currentAsset` and `displayState` for physical outcome.
