# Frame Protocol artifacts

This directory contains executable artifacts for the experimental Frame
Protocol v0.1 draft in `docs/architecture/frame-protocol.md`.

- `schemas/` contains JSON Schema Draft 2020-12 documents for bounded control
  messages. The schemas do not authorize network access or replace transport,
  authentication, allocation, or duplicate-key checks.
- `fixtures/` contains examples consumed by the conformance tests. Simulator
  profile and media-type names are explicitly experimental; they do not close
  the naming gate recorded in `docs/research/open-questions.md`.

The protocol remains experimental until the open v1.0 gates in the normative
draft are closed.
