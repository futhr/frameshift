# Optional Service, Purchasing and Care Integration

**Status:** deferred optional technical contract; transactional shop implementation on hold
**Revision date:** 2026-09-25
**Milestone:** F — on hold, after independent composition/instructions/list (D)
and applicable producer/research/operations qualification (E)

This document specifies code, data ownership, integration, authorization and failure behavior. It does not choose a company business model, fee rate, seller/manufacturer role or admitted market. Such decisions enter as approved external configuration/evidence. Company strategy, economics and legal interpretation are outside this repository.

If resumed, the extension includes all transactional provider integrations, purchasing/service packs, commitment UI, fulfillment and care. It does not gate the Conjunct consumer proof or native product completion. Earlier milestones define contracts and qualify reusable seams; transactional implementation remains parked. The [build-platform plan](build-platform.md) defines the required sequence. [Conjunct adoption](../research/conjunct-adoption.md) defines the generic versus product-specific ownership.

## Service and authority contracts

**BC-01 — Optional capabilities.** The independent visual builder, exact printable list and local computer application remain usable without service enrollment or a payment integration. Additional profiles may expose component handoff, quote requests, purchasing, kitting, assembly, packaging, installation or care only when their actual capabilities and authority are admitted. No mandatory assembler, one-seller topology or per-product source fork is encoded.

Record seller, manufacturer, importer, responsible economic operator, assembler, packer and carrier as distinct externally evidenced role references where the selected operation requires them. One actor may hold several roles, but fulfillment or branding metadata cannot infer the assignments. Preserve exact counterparty and accepted terms in the user-visible commitment. Product code validates the external decision's scope; it does not generate legal conclusions.

A frame configuration/share link grants no device-control, supplier-order or financial authority. Changes to application presentation cannot change accepted composition or commitment identity.

**BC-02 — Capability and scope admission.** Implement versioned readiness records for provider operations, product/evidence scope and operator context. Required input groups are:

- Provider identity, supported operation descriptors, exact revision/no-substitution contract, permitted feeds/assets, quote/stock/reservation semantics, status lookup, cancellation, tracking, returns and exception capabilities.
- Qualified financial-provider account and operation references through Rivure, including supported currency/account context, authentication and reversal/reconciliation behavior.
- Applicable product, source, geometry and procedure evidence with current quarantine/revocation checks. Component evidence cannot substitute for combined-assembly qualification.
- Approved external policy/permission envelopes identifying issuer, subject, scope, effective interval, conditions, required disclosures, review/authority and revocation reference.
- Hosting, data-access and processor-policy bindings, retention, export and operational recovery evidence required for the selected profile.

Missing support is `unavailable`, not a simulated successful operation. Unsupported stores remain usable as informational shopping-list references where permitted. Models cannot alter provider credentials, banking destinations or policy authority. Prefer explicit supported APIs/feeds; a component profile alone cannot automate a retailer.

## Quotes and financial references

**BC-03 — Immutable acceptance.** An accepted snapshot pins exact BuildSpec/CompositionSpec, current compatibility/evidence decision, quantities/revisions, named counterparty per commitment, offer IDs/expiry, amounts/currencies and their typed components, delivery conditions, financial-rule references, terms version, consent and authority limits. Indicative planning observations are not binding quotes.

Recheck current quarantine, operation support, offer/reservation expiry and route eligibility before commitment. Use reservations only where the provider actually supports them. Material changes require a new accepted snapshot; no silent part substitution, increased amount or changed counterparty.

A bounded mandate specifies allowed operations, exact configuration or permitted changes, counterparties, monetary ceilings/currency where relevant, expiry, revocation and partial-completion policy. Model output or a refreshed workflow cannot widen it. Preserve required authentication and durable confirmations.

**BC-04 — Financial owner boundary.** Rivure owns reusable financial primitives, provider interaction, fee/commission calculations, reversals, disputes and settlement evidence. Frameshift supplies typed product/commitment references and consumes approved results; it must not maintain a competing money ledger, Stripe adapter or fee engine.

Use integer minor units and explicit currency/rounding semantics at the boundary. Rule version, payer, earning event, required disclosures, reversal behavior and amount composition are explicit external inputs. Never infer a charge from a generated estimate or charge two parties without their respective admitted commitments. Do not encode company rates, margins, reserves or infrastructure-cost allocations in product fixtures.

[PC-09](producer-contracts.md) defines the joined delivery contract. Refpath
delivers the financial command; Rivure owns financial execution and provider
retries. Persist both identities. Refpath never independently retries the PSP
operation. A provider binding declares idempotency retention, account/environment
and lookup semantics; an unknown outcome cannot be resent after key expiry merely
because its old key is available. These requirements do not resume deferred F.

Distinguish financial authorization, capture, transfer, payout, refund and accounting projection. A financial receipt does not establish supplier acceptance, physical delivery or completed assembly. Provider account and loss allocation are qualified financial configuration, not facts inferred from the words marketplace or direct charge.

## Execution and state ownership

**BC-05 — Separate commitments.** A coordination group relates independently accepted goods/service commitments and fulfillment allocations. One seller with several dispatching providers differs from several separate sellers. The selected structure comes from admitted inputs, not a fixed actor hierarchy.

Record independently quote, mandate, financial references, provider acknowledgement, production/testing, fulfillment, care and accepted outcome. A database transaction cannot make multiple external commitments atomic.

Typed Ash commands enforce actor and current scope. Refpath owns generic work/effect execution and recovery; Rivure owns financial state. Provider adapters advertise actual placement, lookup, cancellation, tracking, notification and applicable reversal operations. Generic gaps belong upstream; Frameshift maps its product semantics here. No direct writes to another application's private tables or competing effect journal are allowed.

**BC-06 — Unknown outcomes and partial execution.** Before every external mutation, persist authorized intent and a stable idempotency/reconciliation identity through the canonical effect owner. Join that identity to the domain commitment and the producer's financial command identity where applicable. One layer dispatches the actual provider mutation; nested orchestration must not dispatch it twice.

Outcomes are confirmed success, definite refusal or unknown. Timeout/crash after dispatch is unknown. Use supported lookup/reconciliation before repeat. An adapter without safe reconciliation/idempotency cannot perform unattended uncertain retries. Receipts bind provider/account context, operation, authority, exact request digest and external reference. Reject same-key changed-payload reuse.

Authenticate, bound, deduplicate and scope callbacks. Handle replay, out-of-order observations and eventual consistency without reopening terminal commitments incorrectly. Apply the preaccepted partial-completion policy after partial success: compensate only confirmed reversible effects, preserve unknown outcomes, and require new authority when existing policy cannot resolve the remainder. Compensation is not an atomic rollback across independent providers.

## Fulfillment and care

**BC-07 — Complete care.** Implement per-commitment and per-parcel tracking, notification delivery, delay/loss/damage/wrong-revision handling, cancellation before and after acceptance, returns, repair/replacement, partial/full refund references, financial reversals, disputes, recalls and safety notices.

As-built evidence binds actual serial/lot, part/firmware revisions, test method/result, procedure and packaging revision where required. Completing a UI task is not a replacement for a required physical measurement. Distinguish requested, acknowledged and completed external actions.

Provide an accessible progress view and bounded exception queue identifying owner, reason, next action and safe-resume conditions. Retain accepted terms and communication evidence. Routine actions may run unattended within their admitted scope; material changes and unresolved authority require the appropriate approval. Disabling new transactions must not disable authorized care and reconciliation for existing commitments.

**BC-08 — Policy-driven operations.** Implement typed obligations and evidence references for required identity fields, listing/disclosure content, tax/reporting inputs, product notices, withdrawal/cancellation consent where required, durable confirmations, privacy access/export/correction and retention/deletion dispositions.

The policy issuer determines applicability through its own approved process. Product code checks subject, scope, effective period, required evidence and current revocation; it cannot waive an obligation or select a jurisdiction from model preference. Keep legally retained financial records distinct from erasable profile data according to the supplied retention policy. Support security/vulnerability and product-notice workflows without presenting software conformance as physical certification.

Denied or unsupported operations yield explicit refusal and the permitted narrower output, such as a guide or quote request. Informational fallback is not permission to perform otherwise prohibited external actions.

## Qualification and activation

**BC-09 — Required fault evidence.** Use deterministic provider simulations and the selected producers' consumer suites; add real provider sandboxes where supported. Cover:

- exact revisions, changed stock/amounts/shipping, expired offer/mandate, current quarantine and unauthorized actor/scope;
- missing capabilities, single-seller versus multi-seller topology and separate fulfillment roles;
- duplicate commands, changed-payload replay, concurrent budget claims, invalid signatures, repeated/out-of-order callbacks and partial acceptance;
- remote success followed by timeout, process/database restart around receipt, reconciliation after provider outage or revoked authority, and no duplicate purchase/charge/cancellation/refund;
- partial delivery/cancellation/return, refused refund, dispute, earning-event reversal, failed QC, recall and customer-data requests;
- producer/account isolation, backups/restores, migrations, bounded queues, redaction, accessible UI and deployed artifact/generation identity.

Financial fixtures use Rivure's actual exported calculations and reconcile accepted amounts and cumulative reversals. A simulator qualifies only its simulated contract; missing credentials leave sandbox/live evidence open, without excusing implementable recovery tests.

**BC-10 — Completion versus activation.** An enabled F profile includes every applicable codeable requirement above with named evidence in the [verification ledger](verification.md). External agreements, source/asset permissions, role/policy admission, credentials, release administration and physical measurement have separate readiness records. They gate the operations or claims that depend on them, not the existence of implementable code and simulations.

Keep real effects disabled until the selected profile is admitted. The independent builder, exact list and local application remain usable throughout. Documentation changes do not claim implementation or live readiness.
