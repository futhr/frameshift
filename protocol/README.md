# Frame Protocol artifacts

This directory contains executable artifacts for the complete Universal Frame
Protocol v0.1 contract in `docs/architecture/frame-protocol.md`. Version 0.1 is
a pre-1.0 compatibility boundary, not an MVP or reduced product tier.

- `schemas/` contains JSON Schema Draft 2020-12 documents for bounded control
  messages. The schemas do not authorize network access or replace transport,
  authentication, allocation, or duplicate-key checks.
- `models/` contains the W3C WoT Thing Models for the universal Frame and Host
  Outbox roles. A device TD supplies concrete Forms, security, capabilities,
  and artifact profiles without changing those interaction semantics.
- `fixtures/` contains examples consumed by the conformance tests. A simulator
  artifact profile is test data, not the product definition.

The protocol is not v1.0 until the open gates in the normative draft are
closed. Implementations must report evidence against the exact profile they
actually pass; an unfinished implementation does not shrink this contract.
