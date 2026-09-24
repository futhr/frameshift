# Optional Purchasing, Dropshipping and Care

**Status:** normative final-milestone specification; implementation open
**Milestone:** F — FINAL, after the complete independent shopping list (D) and
research/operational qualification (E)
**Planning market:** Swedish operator serving EU consumers; qualify each enabled route

This milestone includes all transactional supplier/PSP integrations, purchasing
packs, checkout, fulfillment and care. Earlier milestones may define contracts
and build reusable runtime seams, but do not implement a partial checkout at
the expense of the complete independent journey. The [build-platform plan](build-platform.md)
defines the required sequence.

## Operating model and legal-role contract

**BC-01 — Disclosed service.** Customers can optionally pay for coordinated
supplier-direct purchasing. Each identified supplier sells and ships its own
goods under its own goods contract. Frameshift supplies software and a defined
coordination service with a disclosed percentage fee. No stockholding,
mandatory lead assembler or Frameshift-branded assembled hardware is assumed.
The independent printable list remains available without the service or fee.

Record seller, manufacturer, importer and responsible economic operator as
distinct roles, with destination/market scope and evidence. Do not infer seller
identity from a brand or treat a customer checkbox as assigning importer duties.
The actual contracts, payment flows, invoices, marketing and product UI must
match the operating model. DIY assembly does not waive consumer rights or
excuse inaccurate compatibility claims. Indemnities provide contractual recourse;
they cannot erase duties to customers. Legal role and applicability require
review of the implemented flow, using the [dated primary-source research](../research/build-platform-decisions.md).

**BC-02 — Partner and market admission.** Implement versioned readiness records
and enable real transactions only for admitted supplier/PSP/destination routes:

- Supplier identity, trading role, authority to relay orders, invoices, terms,
  exact revision/no-substitution policy, permitted feeds/assets, price/stock
  API, fulfillment promises, returns address, cancellation/refund capabilities,
  support escalation, recalls, insurance and agreed loss/indemnity terms.
- PSP merchant onboarding, supported markets/currencies, charge/fee topology,
  authentication, payout, refunds, disputes, negative balances and reserves.
  A supplier direct-charge/platform-fee arrangement is a candidate, not a
  committed PSP selection or a legal exemption.
- Product/supply-chain evidence, relevant EU operator, safety information,
  customs/VAT and producer-responsibility assessment. Component evidence does
  not certify the customer assembly.
- Company/hosting/model processor agreements, data region/transfers, provider
  data use, access controls, backup/restore, incident response, export and exit.
- Versioned legal decisions for platform safety/due diligence, consumer/service
  withdrawal, tax/reporting, privacy and software-security applicability.

New research cannot modify banking instructions or these authorities. Unsupported
stores remain in shopping lists. Prefer contracted APIs/feeds and supported
commerce endpoints; a component profile alone cannot automate a retailer.

## Quotes, mandates and fees

**BC-03 — Immutable acceptance.** A purchase snapshot pins the exact BuildSpec,
current compatibility/evidence decision, line quantities/revisions, named seller
per line, offer IDs/expiry, currency, taxes, shipping, duties where applicable,
delivery promises, fee rule/amount, terms version, consent and authorization
limits. Separate indicative configuration cost from a valid landed quote.

Recheck current quarantine, supported operations, stock, offer expiry and route
eligibility before commitment. Reservations are used only where a supplier
supports them, with explicit expiration. Material changes require new customer
acceptance; no silent substitution, increased amount or changed seller.

A bounded mandate must specify permitted operations, exact configuration or
allowed changes, sellers, monetary ceiling/currency, fee limit, expiry,
revocation, substitution and partial-order policy. The allowed scope cannot
expand from model output or a refreshed workflow. Capture customer payment
authentication when required. Preserve durable accepted terms and confirmations.

**BC-04 — Percentage accounting.** The contract supports an explicitly chosen
supplier commission, customer service fee, or disclosed combination. The actual
rate and payer are commercial configuration, not assumed research examples.
Display the percentage, eligible merchandise base and final amount before
acceptance; state shipping/tax treatment, earning event, refund/withdrawal rules,
rounding and currency. Do not silently charge both parties. Use integer minor
units and versioned calculations; never floating-point payment arithmetic.

Track gross merchandise value, supplier funds, earned commission, customer fees,
tax and reversals separately. Compute realized contribution after PSP fees,
refunds, disputes, research/provider cost and other allocated variable costs.
Keep fixed hosting, database/backups, operations, security, legal/accounting and
insurance costs visible in operational economics. Avoid advancing supplier
purchase costs without a separate financing decision. Refundability follows the
accepted and lawful service terms, not a blanket nonrefundable default.

## Execution and state ownership

**BC-05 — Separate commitments.** A customer purchase group relates multiple
supplier orders; it does not pretend they form an atomic transaction. Show seller
identity and separate contracts before payment and in progress/care views.
Record independently the quote, customer mandate, PSP authorization/capture,
supplier order acknowledgement, fulfillment, refunds and fee settlement.
A payment receipt is not proof of supplier acceptance, and shipment is not
proof of delivery or successful assembly.

Use typed Ash commands under the correct actor and current mandate. Refpath
executes the admitted purchasing/care packs and owns runtime effects. Provider
adapters advertise actual placement, lookup/reconciliation, cancellation,
tracking, notification and refund capabilities. Extend upstream generic
contracts where missing; implement Frameshift mappings here. Do not claim a
draft notification, an abstract adapter, or a local settlement record sent money
or created a supplier order.

**BC-06 — Uncertain outcomes and partial orders.** Before every external write,
persist the authorized intent and stable idempotency/reconciliation identity
through the Refpath effect contract. Link it to the domain commitment. Classify
outcomes as confirmed success, definite refusal or unknown; a timeout or crash
after dispatch is unknown. Reconcile by supported external lookup before a
potential repeat. An adapter lacking safe lookup/idempotency cannot be admitted
for unattended writes. Receipts bind provider, operation, authority, exact
request and external reference. Reject changed-payload reuse.

Handle duplicate/out-of-order callbacks, signature verification, replay windows,
bounded parsing and eventual consistency. Monotonic state rules must prevent
late callbacks from reopening canceled/refunded commitments. Use the preaccepted
partial-order policy when a supplier fails after another accepts: compensate
only confirmed reversible effects, retain unknown holds, and request new consent
when the accepted policy cannot resolve the remaining order. Never describe
compensation as an atomic rollback across suppliers.

## Fulfillment, care and responsibility

**BC-07 — Complete care.** Implement per-seller/parcel tracking and notification
delivery, delayed/missing/damaged/wrong-revision handling, cancellation before
and after acceptance, returns, partial/full refunds, fee reversal, disputes,
recalls and safety notices. Distinguish requested, acknowledged and completed
external actions. Provide a customer progress view and a bounded operator
exception queue with reason, owner, next action and safe resume conditions.
Preserve accepted terms and communication evidence. Routine admitted flows run
unattended; authentication, material changes and unresolved authority return to
the appropriate person.

**BC-08 — Applicable obligations.** Implement policy-driven data/operations for
seller due diligence and reporting (including DAC7 where applicable), VAT/fee
accounting and qualifying deemed-supplier cases, product-safety contacts/listing
information/unsafe-offer handling and recall cooperation, service withdrawal and
early-performance consent, accessible durable confirmations, and privacy access,
export, correction, retention and deletion. Handle legally retained financial
records separately from erasable profile data. Apply controller/processor and
international-transfer decisions to actual providers. Record CRA applicability
and software vulnerability/security processes for the commercial product.
Do not base the model on an assumed payment-agent exemption or customer waiver.

## Qualification and activation

**BC-09 — Required fault evidence.** Build deterministic supplier, PSP, shipping
and notification simulators (containerized where useful) and exercise selected
provider sandboxes where available. Cover at least:

- exact revisions, changed stock/price/shipping, expired quote/mandate, current
  quarantine, unsupported market and unauthorized actor refusals;
- duplicate commands, changed-payload replay, concurrent budget claims, repeated
  callbacks, invalid signatures, out-of-order state and partial acceptance;
- timeout after remote success, process/database restart before/after receipt,
  unknown outcome reconciliation, provider outage, exhausted budget and revoked
  authority without duplicate order, charge, cancellation or refund;
- separate-seller authentication, partial delivery/cancellation/return, refused
  refund, chargeback, fee reversal, recall, customer data requests and recovery;
- backup/restore, migrations, bounded queues/backpressure, privacy/redaction,
  policy isolation, accessible UI, and deployed artifact/configuration identity.

Golden accounting fixtures reconcile accepted amounts, fees and every reversal.
Use contract/property tests around transitions and real provider sandbox
round trips to verify concrete adapters. A simulator passes only its own
contract; unavailable credentials leave sandbox evidence explicitly open,
without excusing missing code or deterministic recovery tests.

**BC-10 — Completion versus activation.** F is the final software milestone and
includes every codeable requirement above with named evidence in the
[verification ledger](verification.md). External agreements, legal review,
company setup, production credentials, release administration and real hardware
measurements have their own readiness records. They gate the claims or real
transactions that depend on them; they are not later software milestones and
must not be used to postpone implementable functionality. Keep real money
disabled until the selected operating route is admitted. The independent
builder, shopping list and computer app remain usable throughout.
