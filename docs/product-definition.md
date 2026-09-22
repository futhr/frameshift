# Product Definition and Completion Contract

**Status:** normative product scope

Frameshift is one complete local-first product: a native macOS controller,
durable host core, deterministic renderer, universal still-frame protocol,
frame agents, display adapters, and qualified physical frame assemblies. A
partial implementation, simulator, development bundle, or selected hardware
prototype is evidence toward this product. It is not an alternate MVP, demo,
or reduced delivery target.

## Product promise

A person can import or generate still artwork on a Mac, preview the exact
target interpretation, and send or schedule it on any paired compatible frame.
The system states whether work is queued, transferred, refreshing, failed, or
physically displayed. Existing artwork remains visible through host, network,
transfer, refresh, and update failures.

The ordinary import, render, transfer, display, library, and playlist flows
work without a Frameshift cloud or AI account. Cloud generation and remote
access are optional, explicit adapters.

## Complete installed flow

```text
source file / Photos / generated result
  -> decoded, normalized immutable master
  -> durable library, labels, provenance and recipe
  -> target preview and deterministic artifact
  -> paired frame selected by advertised capabilities and Forms
  -> authenticated direct push or sleeping-frame pull
  -> verified inactive storage
  -> desired state
  -> physical display adapter completion
  -> current state and host acknowledgement
```

Every arrow is part of the product. Tests that inject an intermediate byte
array or call a simulator process directly prove only that component boundary;
they do not prove this installed flow.

## Universal frame contract

Frameshift compatibility is defined by W3C Web of Things semantics plus the
namespaced Frameshift still-display vocabulary. It is never defined by a
vendor-name switch in host or firmware code.

- A Thing Description declares interaction affordances, security metadata,
  protocol Forms, and a capability instance.
- A Thing Model defines the reusable frame contract independently of endpoints
  and hardware.
- A Form binds one semantic operation to HTTPS, CoAP, MQTT, or a future
  compatible transport profile. The host selects a compatible advertised Form;
  it does not infer endpoints from a manufacturer.
- An artifact profile is the atomic compatibility unit for exact bytes. It may
  identify a qualified panel, controller, palette, packing, waveform, color,
  gamma, or power-limit revision without changing the interaction model.
- Unknown optional namespaced terms survive round trips. Unknown required
  profiles fail explicitly instead of being guessed.

Paper, Photo, and Pixel are reference capability classes. A builder may select
specific vendors early, and the repository may ship vendor-specific display
adapters and measured profiles. Those choices instantiate the universal
contract rather than narrowing it.

## Definition of done

The product is complete only when evidence covers all of the following:

1. The distributed macOS application embeds and supervises the core and raster
   worker, uses authenticated local IPC, migrates data safely, survives
   sleep/restart, and passes signing, hardened-runtime, and notarization gates.
2. Real supported image formats import through bounded decode, orientation and
   color normalization into durable storage; restart never requires caller-held
   source bytes.
3. Library search, labels, similarity, pin, recoverable removal, trash/cache
   policy, provenance, recipes, playlists, schedules, and audit export work
   through the installed UI and durable core.
4. Each enabled AI provider passes explicit capability, credential, privacy,
   cost, progress, cancellation, result-validation, and local-only isolation
   requirements. Import and rendering remain fully usable without AI.
5. Rendering produces deterministic preview and wire artifacts for every
   claimed artifact profile and has measured visual evidence for each shipped
   hardware revision.
6. Frame discovery, pairing, identity custody, certificate rotation,
   authorization, direct push, sleeping pull, retry reconciliation, and state
   observation work over real authenticated transports.
7. Frame agents verify and atomically retain assets, execute still playlists,
   distinguish desired from current state, recover from interruption, and run
   signed rollback-capable firmware.
8. The compact UI passes all specified keyboard and VoiceOver scenarios and
   never conflates accepted, transferred, refreshing, and displayed states.
9. Versioned conformance evidence covers value/schema, runtime, binding, live
   transport, packaged application, firmware, hardware, security, lifecycle,
   and upgrade/recovery profiles at their exact revisions.
10. Every released physical configuration has a reproducible build record and
    measured electrical, power, thermal, optical, mechanical, mounting, and
    interrupted-refresh evidence. Applicable independent security and
    regulatory work is complete for the release claim being made.

## Status and release claims

Implementation status is recorded in the verification ledger. It may say
`missing`, `partial`, or `proven` for a bounded claim. It must not introduce a
smaller edition or declare the product complete because all checks for the
currently implemented subset pass.

External signing credentials, independent reviews, laboratory certification,
and physical measurements cannot be fabricated in software. They remain named
completion gates; their absence does not authorize deleting or weakening the
corresponding requirement.
