# Build Platform Decision Research

**Checked:** 2026-09-24
**Evidence:** repository/source inspection and attributed published measurements
**Not performed:** Frameshift model benchmarks, paid inference, Maude proof runs,
provider purchasing qualification, or physical hardware validation

The accepted design is in the [build-platform specification](../architecture/build-platform.md)
and its linked contracts. This record preserves why the choices were made,
what remains unproved, and which upstream gaps implementation must close.

## Repository and proposal provenance

| Source | Inspected revision or document | Finding |
| --- | --- | --- |
| Frameshift | Build proposal `7527cb3`; app audit `d15afc9`, then `45a1cda` | Existing local product and guide, no commercial builder/order domain; reconcile the proposal rather than copying its lead-assembler assumptions |
| Refpath | `4a8e128628cac28706b0479bd2eabd3b9d240236` | Reuse runtime seams, but qualify the consumer; top-level project remains described as unreleased |
| phoenix-assets | `c76b626104e938d1c6601b73ed8c4d9d7aa4feb3` | Existing Phoenix/SvelteKit asset tooling, generated contracts and Ash metadata; keep Frameshift UI in the host |
| ExMaude | `73acecf087934e593d6bae231b0e1a4d2ddf60b4` | Separate-process backend available; search result needs explicit completion/bound/session evidence |
| Adoption proposal | Maintainer's `Downloads/adoption-plan.md` and Refpath Cloud R.153 | Stable domain ownership, qualified capabilities and admitted generations; not proof of a completed runtime |

These are research snapshots, not automatically approved dependency pins.
The [R.153 research proposal](https://github.com/refpath/refpath-cloud/blob/main/docs/research/R.153-adaptive-application-composition-foundation.md)
informs the integration boundary. Frameshift-specific packs, models and
evaluation fixtures remain here. User decisions supersede the earlier business
assumptions: independent visual shopping list first, supplier-direct optional
coordination last, no mandatory branded assembled hardware or lead assembler.

## Ash, assets and Beamlens

Ash domains group resources and provide a defined application interface; policies
support authorization around resource actions. AshPostgres supplies the server
data layer. This supports the commercial context boundaries without changing
the local core's SQLite writer. Sources: [Ash domains](https://ash.hexdocs.pm/domains.html),
[policies](https://ash.hexdocs.pm/policies.html),
[AshPostgres](https://ash-postgres.hexdocs.pm/readme.html).

[phoenix-assets](https://github.com/futhr/phoenix-assets) supplies the shared
Phoenix/Vite/SvelteKit integration and generated `$phoenix/*` contracts. Inspect
and pin its actual exposed metadata and asset-manifest behavior; do not infer
full server rendering or add a second schema generator. Svelte 5 is the selected
frontend. Electric/Phoenix.Sync is optional pending a real sync requirement.

[Beamlens](https://beamlens.hexdocs.pm/readme.html) describes an early-development
read-only diagnostic runtime with skills for BEAM/system observations and
optional database integration. It is included in the plan with exact-dependency
qualification, redaction, operator authorization and resource budgets. Its
[provider setup](https://beamlens.hexdocs.pm/providers.html) uses a BAML client
registry, including an Ollama-compatible route, rather than automatically using
Refpath's ordinary inference accounting path.

The inspected Refpath `mix.exs` makes Beamlens optional for development/test;
`lib/refpath/application/observability.ex` can start it when available/enabled
and configure its own registry. Consequently the production host must declare
the dependency, select one supervisor owner, prevent a duplicate instance and
enforce budgets at the diagnostic boundary. Reuse generic skills only after
qualification. No inference failure may remove normal logs/metrics/alerts.

## Gleam and ExMaude

Existing Frameshift Gleam code already shares selected host/guide decisions;
physical composition is a new extension. Pure bounded BEAM/JavaScript decisions
fit browser feedback and server rechecking. Physical identity, database truth
and purchase authority remain separately owned.

The inspected [ExMaude search implementation](https://github.com/futhr/ex_maude/blob/73acecf087934e593d6bae231b0e1a4d2ddf60b4/lib/ex_maude/maude.ex)
defaults to bounded search and returns solutions; neither an empty list nor
the inspected richer statistics establish global exhaustion. The
[Maude manual](https://maude.lcc.uma.es/maude-manual/maude-manual.html) describes
search and reachability within the chosen semantics. Require explicit
counterexample/bounded/exhausted/inconclusive results and same-session traces
before using this as admission evidence. Model review, mutation checks and
compiler replay address the risk of verifying a model disconnected from code.

Use the default Port backend and bounded separate OS processes. There is no
inference fee, but compute, binary maintenance and a second formal specification
have costs. [ExMaude's dependency notices](https://github.com/futhr/ex_maude/blob/main/THIRD_PARTY_NOTICES.md)
separate its MIT license from the Maude executable's GPL terms. Record the exact
binary license and distribution obligations for server/CI images.

## Small models and decision costs

**Conclusion:** no evidence makes Jev mandatory or demonstrates it is the only
useful decision model. Start with explicit actions/rules. Evaluate optional
free-text intent using existing Refpath/Ollama support and bounded Qwen3.5 2B/4B.
Evaluate trained compact classifiers once project labels exist; compare Jev as
an optional challenger for suitable structured evidence questions. Adopt the
cheapest candidate that meets the task's risk and quality thresholds.

Ollama's [structured-output documentation](https://docs.ollama.com/capabilities/structured-outputs)
supports local JSON-schema constraints; its cloud service currently does not
offer the same feature. This is output-shape enforcement, not correct intent
or authority. Pin exact artifacts from the [Qwen3.5 library](https://ollama.com/library/qwen3.5)
and qualify supported controls. The [Qwen 2B model card](https://huggingface.co/Qwen/Qwen3.5-2B)
reports non-thinking IFEval 61.2 versus 52.1 for 0.8B. These instruction-following
scores are not Frameshift intent accuracy or a direct Jev comparison.

The independent benchmark author's [Banking77 report](https://github.com/dhruvmehra/jevbench/blob/main/docs/results/2026-09-22-n500-summary.md)
gives the following on 500 held-out examples, dated 2026-09-22:

| Model | Accuracy | Macro-F1 | Median latency |
| --- | --- | --- | --- |
| Fine-tuned DistilBERT | 88.0% | 86.4% | 8 ms |
| Jev 1.13 | 76.4% | 75.3% | 389 ms |
| Laya base | 38.2% | 32.1% | 130 ms |

These are published measurements, not ours. DistilBERT was trained for that
dataset; others used label descriptions. Local timing uses the author's Apple
Silicon setup, while Jev includes an OpenRouter network hop. Sample size,
training and hardware differences prevent universal quality/latency conclusions.
The [benchmark method](https://github.com/dhruvmehra/jevbench) is useful for
designing a controlled Frameshift comparison, not selecting a winner outright.

[SetFit](https://huggingface.co/docs/setfit/conceptual_guides/setfit) is a candidate
for task-specific labeled classification. [Laya's own report](https://github.com/NandhaKishorM/laya#benchmarks)
distinguishes weak base-checkpoint typed-decision results from trained results.
Neither is an automatic Ollama replacement or exception to Frameshift's
no-Python runtime rule. [FunctionGemma's model card](https://ai.google.dev/gemma/docs/functiongemma/model_card)
reports Mobile Actions improvement from 58% to 85% after tuning its 270M model;
this supports investigating specialists, not an 85% Frameshift claim.

Jev offers [typed choice/scoring primitives](https://docs.typesafe.ai/introduction).
Its [documented limitations](https://docs.typesafe.ai/model-jaggedness/jev-1.13)
include numerical/date reasoning, indirection, irrelevant context and adversarial
text. Keep arithmetic, compatibility and authority in explicit code. The vendor's
[headline workflow methodology](https://typesafe.ai/blog/introducing-system-one-models-and-jev)
measures agreement with large-model reference probabilities and acknowledges
favorable performance conditions; it is not independent physical-composition
ground truth or a comparison with a trained local intent classifier.

The [published Jev pricing](https://docs.typesafe.ai/models), checked 2026-09-24,
is $0.042 per million input tokens with free output for Jev 1.13. It is text
only; include shared state and questions in billed input estimates. At that
rate, 10,000 calls averaging 2,000 input tokens cost $0.84; 100,000 cost $8.40.
These are arithmetic examples, excluding extraction/OCR, retrieval, other model
calls, hosting and integration. They are not measured Frameshift costs.

Local inference also costs compute, memory, energy and maintenance. Reusing an
available worker may be economical; a dedicated machine merely to avoid those
API charges may cost more. Compare total cost per correctly resolved case,
including abstention/escalation. No relevant local model or Jev evaluation was
run during this research. [Z3 optimization](https://microsoft.github.io/z3guide/docs/optimization/intro/)
is a separate candidate only if configuration search creates a demonstrated
optimization need.

## Commercial roles, residual duties and costs

**Planning inference:** a disclosed supplier marketplace plus coordination
service better matches the intended product than Frameshift selling assembled
hardware. It is not a liability exemption. Swedish/EU applicability must be
reviewed against actual contracts and conduct before admitting real routes.

| Primary source | Design consequence to review and implement where applicable |
| --- | --- |
| [Konsumentverket: dropshipping](https://www.konsumentverket.se/marknadsratt-foretag/dropshipping-regler-for-foretag/) | Ordinary dropshipping does not remove the selling business's consumer duties |
| [DSA Article 6(3)](https://eur-lex.europa.eu/eli/reg/2022/2065) and [Consumer Rights Directive Article 6a](https://eur-lex.europa.eu/legal-content/EN/ALL/?uri=celex%3A02011L0083-20220528) | Seller appearance and disclosed allocation of responsibilities matter; a label alone cannot determine intermediary status |
| [GPSR Article 22](https://eur-lex.europa.eu/eli/reg/2023/988) | Assess online-marketplace safety contacts, listing information, unsafe offers and recall cooperation |
| [Stripe charge types](https://docs.stripe.com/connect/charges) and [EBA/Commission Q&A](https://www.eba.europa.eu/single-rule-book-qa/qna/view/publicId/2020_5355) | PSP topology affects funds/losses; do not assume it settles legal role or a payment-agent exemption |
| [Skatteverket platform economy](https://www.skatteverket.se/omoss/digitalasamarbeten/utvecklingavflertekniskalosningar/plattformsekonomi.4.7c708f0e16bed42cd0555d5.html) | Assess seller due diligence and DAC7 obligations; active facilitation is not automatically referral-only |
| [Commission VAT OSS](https://vat-one-stop-shop.ec.europa.eu/one-stop-shop_en) | Assess fee VAT and qualifying deemed-supplier treatment based on sellers and dispatch routes |
| [IMY controller/processor guidance](https://www.imy.se/verksamhet/dataskydd/det-har-galler-enligt-gdpr/personuppgiftsansvariga-och-personuppgiftsbitraden/) | Specify actual privacy roles, retention, processor contracts and transfers |
| [Konsumentverket distance-contract information](https://www.konsumentverket.se/marknadsratt-foretag/informationskrav-vid-distansavtal-regler-for-foretag/) | Paid coordination needs service terms, durable information and applicable withdrawal/early-performance consent |
| [Commission CRA guidance](https://digital-strategy.ec.europa.eu/en/policies/cra-open-source) | Assess software security duties for the app's actual commercial/distribution model |

Supplier/manufacturer/customer roles do not eliminate Frameshift's own app,
service, representations, security/privacy and applicable platform obligations.
Supplier and PSP agreements must address exact revisions, fulfillment, returns,
refunds, recalls, liability allocation and recourse. Future branded licensing
requires a new role assessment and is outside the present operating flow.

Revenue can be supplier commission, customer service fee or an explicitly
disclosed combination. No percentage or PSP contract is chosen by this record.
Illustrative arithmetic excluding VAT: 10,000 SEK eligible goods × 8% less
250 SEK variable costs gives 550 SEK contribution before fixed costs/tax.
Those inputs are assumptions. Account for separate supplier charges, FX,
refund/dispute losses and actual [PSP pricing](https://stripe.com/se/connect/pricing).
Frameshift still bears hosting/database/backups, operations/security, research,
integration, support exceptions, legal/accounting and insurance costs. No fixed
monthly-cost or profitability claim is established.

## Decision consequences

The specs require a working independent shopping list in D, nontransactional
research/qualification in E and the entire dropshipping/purchasing/care flow in
final F. They require Ash, Svelte 5 through phoenix-assets, bounded Beamlens,
Frameshift-owned packs, shared Gleam decisions and targeted formal checks.
Jev remains optional; no classifier or solver receives compatibility, safety or
spending authority. Evidence missing from this research remains explicit in
the [verification ledger](../architecture/verification.md).
