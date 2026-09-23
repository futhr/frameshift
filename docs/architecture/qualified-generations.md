# Qualified Render and Transfer Generations

**Status:** normative design; implementation and conformance evidence are tracked
separately in the [verification map](verification.md)

## Purpose and ownership

Frameshift may change a renderer build, frame capability instance, artifact
profile, generation provider, or transfer binding while accepted work is in
flight. The host must bind each new job and delivery intent to one exact,
qualified combination. This is a local contract for the Rendering and Delivery
boundaries under the single SQLite writer. It does not create a SaaS tenant or
move original assets, recipe lineage, rendered bytes, or confirmed display
state out of Frameshift.

The September 2026 adaptive adoption atlas proposes an asset/profile
generation for this repository. This specification narrows
that proposal to the bytes and effects that require stable compatibility.
SwiftUI presentation may change independently. A generation provider is part
of the generation recipe that produces a master; a target render generation
pins the resulting immutable master and its recipe lineage.

## Immutable identity and outcome

A candidate manifest is canonical JSON and has a versioned schema. Its digest
is SHA-256 of those exact canonical bytes. Required identity fields are:

- source master digest and composition recipe digest;
- frame ID and admitted canonical Thing Description digest;
- selected artifact profile ID and canonical profile/capability digest;
- renderer binary digest, renderer protocol revision, and deterministic
  algorithm revision;
- transfer binding identity, selected advertised Form contract, connector
  implementation revision, and required security/effect semantics.

The manifest contains no credential, provider context, raw source bytes,
raw endpoint URL, UI layout, mutable health data, or final artifact digest. The
final digest does not exist when a render candidate is formed. A separate
immutable result binds the candidate digest to its exact rendered wire-byte
digest, byte count, media type, and conformance evidence. The artifact digest
alone remains SHA-256 of the exact wire bytes, independent of database IDs and
manifest metadata. A generation result must never rewrite either identity.

An operation descriptor for each renderer and transfer connector declares its
version, scope, input/output schema, authority and credential audience, effect
class, evidence shape, compatibility rules, and unavailable or ambiguous
outcomes. The host admits only an exact compatible descriptor and profile
combination. Optional WoT extensions are preserved; required unknown profiles
fail closed. The frame receives the existing protocol artifact digest and
profile. A generation digest is host custody metadata unless a separately
versioned frame affordance is specified and qualified.

## Admission, pinning, and rollback

Candidate creation validates the master, recipe, admitted frame identity,
profile, renderer, and connector without a network effect. Qualification
records the exact software fixture suite and, for a physical cohort, the
measured device evidence. Candidate, admitted, and retired states are durable.
One active generation pointer per frame/cohort selects *new* work. A candidate
cannot activate itself; an activation command records the qualification
decision and previous active pointer under the single writer.

An accepted render job and both push and pull delivery intents record the
generation digest. Retries, acknowledgements, and reconciliation use that
frozen record even after another generation is activated. Revision, request
ID, artifact digest, authenticated frame identity, and authoritative display
state still govern confirmation. Only confirmed display advances current and
previous-known-good. Both accepted pending work and last-good bytes remain
protected from collection. Rollback changes the pointer for future work; it
never reassigns an in-flight intent or claims that a frame changed display.

Existing pre-generation work is preserved by migration with an explicit
legacy/unqualified marker. It can be reconciled using its original identity
and digest, but must not be reported as having passed new qualification.

## Diagnostic and verification contract

Audit and native logs include generation, command, and attempt IDs with bounded
public fields. Metrics count qualification refusal, render outcome, transfer
attempt, ambiguous outcome, and confirmed display with bounded dimensions such
as outcome and mode. Generation, frame, recipe, and attempt IDs are excluded
from metric labels. Health exposes qualification coverage and loss/reset status.

The software conformance suite must cover incompatible geometry/color,
changed profile content under the same display name, renderer build change and
rollback, exact byte replay, unsupported connector substitution, duplicate
transfer, power-off timeout, candidate switch during pending work, restart
recovery, last-good retention, and migration of old pending work. Physical
panel refresh, certificate custody, signing, packaging, and independent device
interoperability remain separate release evidence gates.
