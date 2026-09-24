# Frameshift Build Platform Plan

**Status:** architecture and implementation plan  
**Branch:** `build`  
**Scope:** interactive visual build guide + supplier orchestration + marketplace-style fulfillment  
**Important:** this document extends the current public repository state. Substantial unpublished local work may supersede parts of this plan and must be reconciled before implementation.

## 1. Intent

Frameshift started as an experimental system for thin, interoperable digital art frames. The next step is to turn the planned interactive visual build guide into a complete configuration and fulfillment surface without turning Frameshift into an inventory-holding retailer.

The platform should allow a user to visually compose the frame they want, validate the configuration against real technical constraints, generate a deterministic physical build specification, resolve that specification against qualified suppliers and production routes, obtain a live landed quote, complete checkout, and have the finished frame produced and shipped directly to the customer.

Frameshift should never hold stock.

The target commercial model is not a conventional dropship store and not a merchant-of-record reseller business. The preferred structure is a configuration marketplace / manufacturing-orchestration platform in which:

- Frameshift owns the configuration software, compatibility model, supplier qualification logic, quoting, routing, order orchestration, support experience, and marketplace UX.
- A qualified lead assembler / manufacturer is the identified seller of the finished physical frame where legally and commercially workable.
- Component suppliers operate behind that assembler as B2B suppliers.
- Frameshift takes a transparent percentage platform fee through a regulated marketplace PSP.
- Frameshift does not warehouse, take physical custody of, or intentionally take title to hardware.
- Marketplace role design must minimize liability, but must never pretend liability can be reduced to zero.

This design must preserve the existing Frameshift philosophy:

- capability-driven, not vendor-name driven;
- exact revision and evidence tracking;
- no silent substitutions;
- no unsupported claims of production readiness;
- local-first operation of the Frameshift product;
- commerce remains optional and must not become a prerequisite for compatibility;
- evidence states remain explicit: Research, Candidate, Reference, Prototype, Validated.

## 2. Repository structure

Frameshift should evolve toward a monorepo, but not toward one undifferentiated application.

The repository should contain multiple explicitly bounded applications and packages that share machine-readable product specifications and contracts.

Target shape:

```text
frameshift/
├── apps/
│   ├── macos/
│   │   └── existing SwiftUI host application
│   ├── core/
│   │   └── Elixir/OTP product core
│   ├── configurator-web/
│   │   └── public interactive build/configuration experience
│   ├── commerce/
│   │   └── Phoenix/Elixir commerce and orchestration application
│   └── supplier-portal/
│       └── later supplier / assembler operations interface
│
├── packages/
│   ├── build-spec/
│   │   └── canonical physical build model
│   ├── capabilities/
│   │   └── reusable capability definitions
│   ├── catalog/
│   │   └── component / offer / supplier normalization
│   ├── compatibility/
│   │   └── constraint and qualification logic
│   ├── commerce-contracts/
│   │   └── API and event contracts
│   └── ui/
│       └── reusable web UI where justified
│
├── renderer/
│   └── existing Zig rendering code
│
├── protocol/
│   └── existing Frame Protocol and shared protocol contracts
│
├── firmware/
│   └── project-owned frame firmware
│
├── integrations/
│   ├── payments/
│   ├── shipping/
│   ├── tax/
│   └── suppliers/
│       ├── supplier-a/
│       ├── supplier-b/
│       ├── generic-rest/
│       ├── generic-edi/
│       └── generic-sftp/
│
├── data/
│   ├── components/
│   ├── profiles/
│   ├── compatibility/
│   ├── suppliers/
│   └── regulatory/
│
├── docs/
│   ├── architecture/
│   ├── commerce/
│   ├── hardware/
│   ├── research/
│   └── ...
│
└── tools/
```

This is a target structure, not a command to immediately move every existing directory. Existing paths should only be moved once unpublished local work has been inspected and migration cost is understood.

## 3. Core architectural principle: BuildSpec

The new center of gravity should be a canonical, immutable `BuildSpec`.

The BuildSpec is the bridge between:

- product configuration;
- visual preview;
- hardware compatibility;
- manufacturing;
- supplier routing;
- quoting;
- fulfillment;
- regulatory scope;
- order history;
- warranty;
- recall traceability.

A BuildSpec is not a supplier SKU.

A supplier SKU is an external implementation of some part of a BuildSpec.

Conceptually:

```text
BuildSpec
  id
  version
  spec_hash

  frame
    geometry
    material
    finish
    orientation
    passe_partout

  display
    class: paper | photo | pixel
    panel_profile
    artifact_profile
    optical_profile

  electronics
    controller_profile
    power_profile
    firmware_profile

  mounting
    mount_profile

  thermal
    thermal_profile

  packaging
    packaging_profile

  market
    destination_market
    regulatory_profile

  qualification
    evidence_state
    allowed_production_routes[]
```

The BuildSpec must be:

- versioned;
- immutable once attached to a quote/order;
- hashable;
- reproducible;
- diffable;
- serializable;
- independent of a specific supplier;
- precise enough to determine exact compatibility requirements;
- explicit about market/regulatory assumptions.

## 4. Configurator as compiler

The visual configurator should behave as a compiler, not as a product catalog.

User choices:

```text
size
orientation
display class
frame material
finish
mat / passe-partout
mounting
power preference
visual style
```

should compile into:

```text
User intent
  -> normalized configuration
  -> constraint validation
  -> BuildSpec
  -> qualified production routes
  -> quote
```

The visual surface may look like a simple frame designer, but the backend must enforce engineering reality.

Examples of constraints that belong in the engine:

- active display area vs frame geometry;
- panel outline and connector clearance;
- total depth;
- cable bend radius;
- PSU volume and thermal envelope;
- controller compatibility;
- firmware compatibility;
- artifact profile compatibility;
- mount loading;
- destination voltage;
- package geometry;
- qualified supplier route;
- market-specific certification / economic-operator eligibility.

The frontend must never be authoritative for compatibility.

## 5. Visual configurator UX

The public build page should serve both DIY instruction and commercial fulfillment.

Primary user journey:

```text
Choose frame class
  -> choose dimensions
  -> choose display/panel class
  -> choose frame material/finish
  -> choose mat / passe-partout
  -> choose mount
  -> inspect visual preview
  -> inspect build implications
  -> see compatibility explanation
  -> see qualified quote(s)
  -> choose DIY BOM OR order finished build
```

UX requirements:

- show which choices affect thickness, power, price, lead time and compatibility;
- explain why a choice is invalid rather than simply disabling it;
- show price as a quote with validity window, not eternal catalog truth;
- show seller identity before checkout;
- show supplier split / assembly topology where relevant;
- show estimated lead time and shipping region;
- surface certification / validation status accurately;
- never imply certification from a marketplace listing alone;
- make DIY and commercial fulfillment distinct but based on the same BuildSpec;
- preserve accessibility and keyboard support;
- avoid making absolute color-accuracy promises from a browser preview.

Longer term, a room/wall visualizer can run locally in-browser where possible.

## 6. Frontend technology choice

Two viable web architectures should be evaluated:

### Option A — Phoenix + LiveView + focused JS rendering component

Use Phoenix/LiveView for application UI and a dedicated TypeScript/Three.js or React island for the visual renderer.

Advantages:

- fewer runtimes;
- aligns with Elixir orchestration;
- less duplicated state;
- strong server-authoritative validation;
- simpler deployment.

### Option B — React / Next.js frontend + Phoenix API

Use React/Next.js for the entire web UI and Phoenix as the commerce/domain backend.

Advantages:

- strongest ecosystem for complex interactive 2D/3D work;
- easier if the builder becomes CAD-like;
- rich component ecosystem.

Default direction:

Start with Phoenix/LiveView plus a focused JavaScript visual component unless the UI proves that React must own the full application.

Do not introduce an additional frontend runtime without a concrete need.

## 7. Commerce backend

Commerce should initially be a modular monolith in Elixir/Phoenix.

Do not start with microservices.

Recommended bounded modules:

```text
Catalog
BuildSpecs
Compatibility
Quotes
Compliance
Suppliers
Qualification
Routing
Orders
SupplierOrders
Payments
Shipping
Returns
Settlements
Support
Audit
```

Use one PostgreSQL source of truth.

Use durable Postgres-backed jobs for workflows and retries.

Only extract services when a real scaling, ownership, isolation or deployment requirement justifies it.

Do not introduce Kafka or a distributed event platform at the beginning.

## 8. Machine-readable specifications

The long-term source of truth should not be hand-maintained prose alone.

Introduce structured product data under `data/`.

Example:

```yaml
id: display.photo.27.r4
class: photo

geometry:
  width_mm: ...
  height_mm: ...
  depth_mm: ...

requires:
  controller_profiles:
    - controller.photo.r3

power:
  continuous: true
  profile: power.photo.27.r2

evidence:
  state: validated
  revision: 4
```

Machine-readable data should eventually drive:

- docs;
- configurator;
- compatibility checks;
- BOM generation;
- supplier qualification;
- commerce routing;
- validation reports.

The goal is to avoid:

```text
documentation says X
website hardcodes Y
supplier adapter assumes Z
```

## 9. Supplier model

Supplier integration must sit at the edge of the system.

Internal canonical operations:

```text
quote()
reserve()
place_order()
acknowledge()
cancel()
status()
shipment()
return()
refund()
```

External supplier protocols may vary:

- REST/JSON;
- webhooks;
- GraphQL;
- ANSI X12;
- UN/EDIFACT;
- SFTP CSV/XML.

Every external integration maps into the same internal models.

Supplier-specific concepts must not leak into BuildSpec semantics.

## 10. Preferred commercial operating model

The preferred B2C model is:

```text
Customer
   ->
Qualified lead assembler / finished-product seller
   ->
Customer
```

Frameshift:

- provides the configuration marketplace;
- qualifies routes;
- orchestrates orders;
- provides the unified customer experience;
- receives a platform percentage.

Component suppliers:

- sell B2B to the lead assembler;
- are not separate consumer sellers where avoidable.

The lead assembler:

- receives / procures components;
- assembles the finished product;
- flashes approved firmware where applicable;
- runs final Frameshift QC;
- records exact revisions;
- serializes the unit;
- packages and ships directly;
- handles physical RMA / statutory product remedies as the seller where legally applicable.

This is cleaner than one consumer transaction split legally across multiple component sellers.

## 11. Commercial models and boundary

Three operating models exist:

### Frameshift reseller / merchant

Frameshift buys/resells or is clearly seller.

Avoid for the initial model because this creates maximum exposure in:

- consumer sales;
- VAT / tax;
- warranties;
- returns;
- product liability;
- importer role;
- chargebacks;
- recalls.

### Multi-seller marketplace

Several suppliers are sellers in one checkout.

Useful for:

- B2B procurement;
- DIY kits;
- advanced marketplace use cases.

Weaknesses:

- fragmented warranty;
- multiple seller disclosures;
- multiple shipments;
- refund complexity;
- chargeback complexity;
- harder customer experience.

### Lead assembler marketplace

One qualified final seller for the completed frame.

Preferred for B2C.

## 12. Liability boundary

Target responsibility map:

| Area | Preferred primary responsible party | Frameshift role |
| --- | --- | --- |
| Customer sale contract | lead assembler / final seller | marketplace / configuration service |
| Hardware title | supplier / seller | avoid title |
| Physical custody | supplier / assembler / carrier | none |
| Inventory | supplier / assembler | none |
| Product manufacture | assembler/manufacturer | compatibility and qualification tooling |
| Component sourcing | assembler, possibly orchestrated by platform | routing |
| Payment processing | licensed PSP | platform integration |
| Platform commission | Frameshift | receives fee |
| Hardware invoice | seller | display / archive if needed |
| VAT / sales tax | depends on legal flow and jurisdiction | transaction classification / tooling |
| Importer role | seller/importer | avoid where possible |
| CE / conformity | relevant economic operator | verify evidence / qualification |
| GPSR obligations | seller/manufacturer/platform depending role | platform duties still apply |
| WEEE / battery / packaging | responsible economic operator | ensure route data / evidence |
| Shipping | seller / assembler | tracking aggregation |
| Returns | seller / assembler | front-door orchestration |
| Warranty | seller/manufacturer | support routing |
| Recall | manufacturer/seller + applicable platform duties | immediate route suspension, traceability, notification support |
| Chargeback | configured PSP/account topology | operational support / allocation |
| Personal data | role-specific controllers/processors | own GDPR obligations |
| Customer support | unified Frameshift-facing experience | triage and orchestration |

No contract language should claim that Frameshift has zero legal obligations.

## 13. Payments

Use a regulated marketplace payment provider.

Initial shortlist:

- Stripe Connect;
- Adyen for Platforms;
- Mangopay.

Pilot default: Stripe Connect unless final legal/account topology suggests otherwise.

Principles:

- supplier / seller onboarding through PSP where possible;
- do not manually hold customer funds in a Frameshift bank account;
- do not describe ordinary delayed settlement as escrow;
- define refund / chargeback / reserve economics contractually;
- exclude tax, government duties and similar pass-through items from commission basis unless intentionally agreed.

Illustrative commission:

```text
fee_base =
  merchandise_subtotal
  - supplier_funded_discounts
  - refunded_merchandise

frameshift_fee =
  fee_base * agreed_percentage
```

Model scenarios at 7.5%, 10% and 15%.

## 14. Supplier qualification

No supplier is eligible merely because it has a listing.

Qualification categories:

- legal identity;
- tax identity;
- manufacturer / assembler / seller role;
- product compliance evidence;
- insurance;
- quality control;
- exact Frameshift compatibility;
- integration capability;
- lead time;
- capacity;
- controlled substitution policy;
- shipping;
- warranty/RMA;
- data/security;
- financial resilience.

Hard fail criteria:

- legal manufacturer cannot be identified;
- required conformity evidence unavailable;
- no controlled BOM/revision process;
- no traceability;
- silent substitution allowed;
- no return/warranty process;
- no product responsibility assignment;
- no accepted liability / recall obligations.

Qualification attaches to a production route and exact revision, not just to a supplier company.

## 15. No silent substitutions

This is a non-negotiable system rule.

Automatic substitution may only occur when the replacement route:

- satisfies the same customer-visible specification;
- is market-eligible;
- is explicitly qualified;
- preserves required artifact/controller/power/thermal/mount profiles, or uses a pre-qualified equivalent BuildSpec revision;
- does not worsen the committed price;
- remains within disclosed lead-time tolerance.

Anything else requires:

- re-quote;
- explicit customer consent.

Never substitute because a marketplace says two products are “similar.”

## 16. Routing engine

Eligibility first, optimization second.

Routing flow:

```text
BuildSpec
  -> market eligibility
  -> compliance eligibility
  -> exact profile support
  -> supplier qualification
  -> exact BOM/revision availability
  -> capacity
  -> destination support
  -> warranty region
  -> landed cost
  -> lead time
  -> quality score
  -> selected production route
```

Do not optimize price before eligibility.

A route decision should be explainable and logged.

Example:

```text
route selected because:
  ✓ SE market approved
  ✓ BuildSpec supported
  ✓ exact artifact profile qualified
  ✓ required component revisions available
  ✓ lead time accepted
  ✓ landed cost within policy
  ✓ quality state GREEN
```

## 17. Quote model

A quote must be an immutable snapshot.

Quote should include:

- BuildSpec version/hash;
- seller;
- production route;
- supplier offers;
- merchandise price;
- commission;
- shipping;
- tax;
- duty;
- currency;
- FX assumptions;
- lead time;
- quote expiry;
- market;
- regulatory assumptions.

Order placement must never re-resolve silently against a newer quote.

## 18. Order orchestration

Canonical order topology:

```text
CustomerOrder
  -> SellerOrder
      -> SupplierSuborders / POs
      -> Production
      -> QC
      -> Shipment
```

The customer sees one coherent order.

Internally, the order may involve:

- component supplier orders;
- assembler order;
- shipping job;
- payment record;
- platform fee;
- returns;
- supplier settlement.

Use a saga-style durable workflow.

## 19. Events

Canonical event vocabulary:

```text
quote.requested
quote.created
quote.expired
order.created
payment.authorized
payment.captured
route.selected
supplier_order.created
supplier_order.acknowledged
supplier_order.rejected
production.started
production.test_passed
shipment.ready
shipment.dispatched
shipment.delivered
shipment.exception
rma.requested
rma.authorized
return.received
refund.authorized
refund.completed
supplier.settlement.created
supplier.settlement.completed
route.quarantined
recall.opened
```

Each event must have:

- event id;
- aggregate id;
- correlation id;
- causation id;
- event version;
- timestamp;
- actor/source;
- payload;
- idempotency key where externally triggered.

## 20. Idempotency and reconciliation

Every external mutation must be idempotent.

Examples:

- payment intent creation;
- supplier PO submission;
- shipment creation;
- cancellation;
- refund.

External webhooks must be:

- signature verified where supported;
- persisted before business processing;
- deduplicated;
- retried;
- traceable.

Use a transactional outbox.

Reconciliation jobs must regularly compare internal state against:

- PSP;
- supplier systems;
- carriers;
- tax provider where relevant.

## 21. Failure model

Explicitly design for:

- inventory race;
- supplier API outage;
- supplier timeout;
- supplier cancellation;
- partial multi-supplier failure;
- counterfeit component;
- revision drift;
- fraudulent supplier;
- incorrect conformity document;
- payment authorization failure;
- payment capture failure;
- duplicate webhook;
- duplicate supplier order;
- lost parcel;
- damaged parcel;
- customs hold;
- return lost in transit;
- chargeback;
- recall;
- sanctioned entity;
- export restriction;
- tax engine outage;
- shipping API outage;
- PSP outage.

Orders must enter explicit states rather than rely on ad hoc exception handling.

## 22. Supplier performance and quarantine

Track:

- acceptance rate;
- on-time ship rate;
- first-pass yield;
- defect rate;
- DOA rate;
- RMA rate;
- late response rate;
- cancellation rate;
- delivery exception rate;
- mean time to resolution.

A route must be automatically quarantinable.

A recall or critical compliance event should immediately suspend new orders for affected:

- supplier;
- BuildSpec revision;
- component revision;
- artifact profile;
- production site.

## 23. Production evidence

No Frameshift warehouse is needed for quality control.

Final seller / assembler should generate evidence:

- finished serial number;
- exact component revisions;
- firmware hash;
- artifact profile;
- BuildSpec hash;
- electrical test;
- display test;
- identity/pairing test;
- thermal or bounded process checks where defined;
- cosmetic check;
- packaging revision;
- site;
- timestamp;
- QC station/operator identifier.

Higher-value routes may include photographs tied to serial number.

## 24. Returns and RMA

Customer-facing flow:

```text
Frameshift support / returns portal
  -> identify order and seller
  -> classify issue
  -> collect evidence
  -> request seller RMA
  -> issue return label
  -> direct return to seller / RMA facility
  -> inspect
  -> replace / repair / refund
  -> update PSP and order state
```

Physical returns should not default to a Frameshift address.

Separate:

- change-of-mind return;
- statutory non-conformity;
- manufacturer warranty;
- software/support issue.

## 25. Regulatory and legal design

EU/Sweden-first legal review is required before production launch.

Architecture must account for:

- consumer rights;
- marketplace trader disclosure;
- Digital Services Act obligations where applicable;
- General Product Safety Regulation;
- product liability rules;
- CE / sector-specific conformity;
- radio/electrical requirements where applicable;
- WEEE;
- battery obligations;
- packaging/EPR;
- importer role;
- VAT;
- deemed-supplier marketplace VAT scenarios;
- IOSS/OSS where applicable;
- customs;
- privacy;
- payment regulation boundaries.

International expansion must treat each region as a launch gate.

Second-stage regions:

- UK;
- US;
- Canada;
- additional EU/EEA configurations.

Tax and regulatory role data must not be hardcoded into generic order logic.

## 26. Shipping

Initial shortlist:

- Sendcloud for EU-first marketplace shipping;
- EasyPost for broader global carrier abstraction;
- Shippo as an alternative.

Seller/assembler should normally be shipper of record.

Frameshift normalizes shipment state.

Internal statuses:

```text
LABEL_CREATED
PICKED_UP
IN_TRANSIT
CUSTOMS_HOLD
OUT_FOR_DELIVERY
DELIVERED
EXCEPTION
RETURN_TO_SENDER
LOST
DAMAGED
```

## 27. Refpath boundary

Refpath may be useful as part of an external attribution, referral, procurement or workflow layer depending on the exact product being referenced.

It must not become the authoritative source of:

- BuildSpec;
- compatibility;
- regulatory evidence;
- supplier qualification;
- order state;
- substitution policy.

If integrated, Refpath should sit at an adapter boundary.

Possible roles:

- referral / attribution;
- lead tracking;
- supplier discovery;
- affiliate flow;
- external procurement trigger.

The Frameshift commerce domain must remain the source of truth.

## 28. Data model

Core entities:

### Component

- component_id
- component_family
- manufacturer
- manufacturer_part_number
- revision
- geometry
- electrical profile
- thermal profile
- artifact implications
- regulatory evidence links
- evidence state

### Supplier

- supplier_id
- legal entity
- market roles
- tax ids
- PSP connected account
- insurance
- shipping regions
- RMA regions
- integration type
- status

### SupplierOffer

- supplier_id
- component_id / build capability
- supplier SKU
- currency
- price
- MOQ
- stock / capacity
- lead time
- valid_from
- valid_until
- revision lock
- source

### Qualification

- supplier_id
- production_route_id
- BuildSpec / profile scope
- market
- evidence
- state
- approved revision
- valid_from
- valid_until

### BuildSpec

- build_spec_id
- version
- hash
- frame config
- display config
- electronics config
- mounting config
- market
- packaging
- qualification references

### Quote

- quote_id
- BuildSpec hash
- seller
- route
- itemized price
- tax
- duty
- shipping
- commission
- expiry

### CustomerOrder

- order_id
- customer
- quote snapshot
- BuildSpec snapshot
- seller
- payment refs
- state

### SupplierOrder

- supplier_order_id
- parent order
- supplier
- PO lines
- idempotency key
- status
- external reference

### Shipment

- shipment_id
- carrier
- tracking
- seller
- origin
- destination
- state

### RMA

- rma_id
- order
- seller
- reason
- evidence
- authorization
- disposition
- refund / replacement reference

### RegulatoryDocument

- document_id
- type
- economic operator
- product/revision scope
- market
- valid period
- storage reference
- verification status

## 29. API boundary

The configurator must talk to a vendor-neutral commerce API.

Example endpoints:

```text
POST /v1/build-specs/compile
POST /v1/build-specs/:id/validate
POST /v1/quotes
GET  /v1/quotes/:id
POST /v1/orders
GET  /v1/orders/:id
POST /v1/orders/:id/cancel
POST /v1/orders/:id/returns
GET  /v1/orders/:id/events
```

Supplier adapter contract:

```text
quote(build_spec, destination)
reserve(offer, ttl)
place_order(order)
cancel(order)
fetch_status(order)
create_return(order, reason)
```

No supplier-specific endpoint shape should leak into the configurator.

## 30. Example compile request

```json
{
  "configuration": {
    "display_class": "photo",
    "width_mm": 700,
    "height_mm": 500,
    "frame_material": "aluminium",
    "finish": "black",
    "mount": "slim-wall",
    "market": "SE"
  }
}
```

Response:

```json
{
  "build_spec_id": "bld_...",
  "version": 12,
  "hash": "sha256:...",
  "status": "valid",
  "requirements": {
    "artifact_profile": "fs-photo-27-r4",
    "controller_profile": "photo-controller-r3",
    "power_profile": "photo-27-power-r2"
  },
  "qualified_routes": [
    "route_eu_assembler_a_r7"
  ]
}
```

## 31. Security

Requirements:

- PSP-hosted card collection;
- no PAN/CVC in Frameshift systems;
- strict secrets management;
- signed webhook verification;
- least privilege supplier credentials;
- per-supplier credential isolation;
- audit logging;
- PII minimization;
- EU-region hosting initially where practical;
- data retention policy;
- DPA / subprocessors review;
- incident response runbooks;
- supplier API rate limits and circuit breakers.

Wall-photo uploads should be local-first in-browser where feasible.

## 32. Build vs buy

Build internally:

- BuildSpec;
- compatibility engine;
- supplier qualification model;
- route eligibility;
- substitution policy;
- quote snapshot logic;
- order orchestration;
- audit trail;
- Frameshift-specific supplier adapters;
- configurator UX.

Buy / integrate:

- PSP marketplace infrastructure;
- shipping carrier abstraction;
- tax engine at multi-region scale;
- identity/KYB where possible;
- EDI gateway when supplier volume justifies it;
- object storage;
- observability.

Potential integrations:

- Stripe Connect;
- Adyen for Platforms;
- Mangopay;
- Sendcloud;
- EasyPost;
- Shippo;
- Avalara or comparable tax tooling;
- Pipe17 or an enterprise integration layer later;
- Europages / Thomasnet for supplier discovery only.

## 33. Do not cross rules

The system must never:

- automatically purchase a component whose exact required revision cannot be verified;
- silently substitute suppliers or components;
- claim certification based on a reseller/marketplace listing alone;
- route to an unqualified production path;
- hide the identity of the seller;
- obscure return/warranty terms;
- reinterpret an already accepted order using newer catalog data;
- treat supplier marketing text as evidence;
- use cheapest-price routing before technical/regulatory eligibility;
- let an external middleware decide component equivalence;
- require the commerce platform for ordinary Frameshift interoperability;
- put payment card data into application logs;
- imply Frameshift has no legal duties.

## 34. Phased implementation

### Phase 0 — reconcile unpublished work

Before restructuring:

- inspect current local/unpushed tree;
- identify web/configurator work already started;
- identify local commerce decisions;
- compare local architecture with this document;
- revise migration plan.

### Phase 1 — monorepo boundaries

- establish target app/package boundaries;
- avoid breaking current build paths unnecessarily;
- add shared contracts gradually;
- keep current product functioning.

### Phase 2 — BuildSpec

- define schema;
- define versioning;
- define hashing;
- define compiler;
- define validation errors;
- connect to capability/artifact profiles.

Exit gate:

Same user configuration produces a reproducible BuildSpec.

### Phase 3 — compatibility engine

- explicit constraints;
- exact revision requirements;
- market constraints;
- qualified route constraints;
- explanation output.

Exit gate:

Impossible configurations cannot be emitted by the backend.

### Phase 4 — visual configurator

- visual frame builder;
- engineering explanations;
- generated DIY BOM;
- export/share BuildSpec;
- no checkout required yet.

Exit gate:

A user can build every pilot configuration without impossible combinations.

### Phase 5 — supplier catalog

- Supplier;
- SupplierOffer;
- qualification;
- exact revision mapping;
- live-ish availability;
- quote validity.

Exit gate:

BuildSpec -> eligible offers works without purchasing.

### Phase 6 — quoting

- seller selection;
- landed cost;
- shipping;
- tax abstraction;
- quote snapshot;
- expiry.

Exit gate:

BuildSpec -> deterministic auditable quote.

### Phase 7 — marketplace payments

- PSP onboarding;
- seller connected accounts;
- checkout;
- commission;
- refunds;
- chargeback allocation.

Exit gate:

End-to-end test payment reconciles.

### Phase 8 — order orchestration

- supplier adapters;
- purchase orders;
- acknowledgements;
- retry;
- failure recovery;
- route fallback.

Exit gate:

Supplier rejection can recover without duplicate orders.

### Phase 9 — shipping and returns

- labels/tracking;
- RMA;
- seller return route;
- refund/replacement.

Exit gate:

A full order can ship, return and refund without Frameshift physical custody.

### Phase 10 — controlled production pilot

- one market;
- one lead assembler;
- one fallback;
- real customers;
- limited build set;
- explicit monitoring.

### Phase 11 — regional scale

- multiple assemblers;
- multi-country tax;
- redundant logistics;
- route quality metrics;
- automated quarantine.

## 35. Launch gates

Production launch requires:

- identified seller;
- signed economic-operator responsibility map;
- verified required compliance documents;
- active insurance;
- qualified golden sample;
- PSP approval of marketplace topology;
- tax review;
- live shipping test;
- live RMA test;
- refund test;
- supplier rejection test;
- recall test;
- privacy/DPA review;
- audit reconstruction test;
- exact BuildSpec route qualification.

A working website is not launch readiness.

## 36. Initial business architecture

Pilot target:

- one geography / customs area;
- one qualified final seller;
- one fallback seller in qualification;
- small validated BuildSpec set;
- one PSP;
- one shipping platform;
- one support workflow;
- no commodity supplier auto-substitution.

Prefer same-region assembly over sending several low-value component parcels independently to the end customer.

## 37. Longer-term supplier topology

At scale:

```text
                         Frameshift
                            |
                  BuildSpec / qualification
                            |
                  Supplier routing engine
                     /      |       \
                    /       |        \
             EU assembler  UK assembler  US assembler
                 |              |            |
            components      components    components
                 |              |            |
                 +------ finished product ----+
                                |
                             customer
```

The architecture should make regional final sellers replaceable without changing the user-facing BuildSpec model.

## 38. Product and commerce separation

The existing Frameshift protocol remains about:

- discovery;
- pairing;
- capabilities;
- rendering;
- transfer;
- frame state;
- still image behavior.

Do not add commerce concerns such as:

- price;
- Stripe;
- commission;
- shipping;
- supplier;
- tax.

Commerce consumes product capabilities; it must not pollute the Frame Protocol.

A compatible frame bought elsewhere must remain usable.

## 39. Source of truth hierarchy

Preferred authority order:

1. versioned machine-readable Frameshift specs;
2. validated evidence records;
3. qualified production-route records;
4. current supplier offers;
5. supplier external systems.

Marketplace listings and supplier marketing text are research input only.

## 40. Open decisions requiring unpublished context

Before implementation, reconcile:

- whether a web/configurator application already exists locally;
- whether local work already introduced a BuildSpec-like concept;
- whether directory moves have already happened;
- whether supplier or payment integrations have already been selected;
- what exactly “Refpath” refers to in the current local design;
- whether the local code already uses LiveView, React, Next.js, Three.js or another stack;
- whether the local architecture has already split the Elixir core;
- whether local hardware/BOM schema work exists;
- whether there are current decisions about finished-product manufacturer responsibility;
- whether local work has introduced firmware production provisioning;
- whether the local product now includes additional frame classes or hardware profiles;
- whether the no-Python policy remains unchanged in unpublished work;
- whether current packaging / release tooling assumes existing top-level paths.

## 41. Immediate implementation direction

Do not start by building “the shop.”

Build in this order:

```text
shared physical model
  -> BuildSpec
  -> compatibility engine
  -> visual configurator
  -> qualified supplier catalog
  -> quote engine
  -> checkout
  -> order orchestration
  -> shipping/RMA
```

The hardest and most valuable abstraction is BuildSpec.

If BuildSpec and qualification are correct:

- DIY instructions;
- BOM export;
- visual configuration;
- supplier routing;
- finished-frame ordering;
- multiple assemblers;
- future hardware revisions;
- marketplace fulfillment

all become consumers of the same model.

If those foundations are wrong, the system degenerates into vendor SKU logic and brittle supplier-specific commerce code.

## 42. Final architecture

```text
                         FRAMESHIFT MONOREPO

┌──────────────────────── PRODUCT ─────────────────────────┐
│ macOS │ core │ renderer │ protocol │ firmware           │
└───────────────────────────┬──────────────────────────────┘
                            │
                       capabilities
                            │
                     ┌──────▼──────┐
                     │  BuildSpec  │
                     │ constraints │
                     │ evidence    │
                     └──────┬──────┘
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
         ▼                  ▼                  ▼
    Visual Builder     DIY Build Guide      Commerce
                                                │
                                     ┌──────────▼──────────┐
                                     │ Qualification +     │
                                     │ Supplier Router     │
                                     └──────────┬──────────┘
                                                │
                                    ┌───────────┼───────────┐
                                    ▼           ▼           ▼
                              EU assembler   UK seller   US seller
                                    │           │           │
                                    └──── finished frame ───┘
                                                │
                                             customer
```

The architecture is therefore:

**monorepo + modular monolith + shared machine-readable physical specifications + immutable BuildSpec + qualified supplier routing + external regulated payment/shipping infrastructure + no Frameshift-owned inventory.**

The webshop is not the product model.

The BuildSpec is the product model.
