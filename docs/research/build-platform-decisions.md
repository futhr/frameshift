# Build Platform Technical Decision Research

**Updated:** 2026-09-25; earlier source observations are dated 2026-09-24 unless stated otherwise.
**Evidence:** repository/source inspection and attributed published measurements.
**Not performed:** Frameshift model benchmarks, paid inference, Maude proof runs, live provider qualification or physical hardware validation.

The technical design is in the [build-platform specification](../architecture/build-platform.md) and its linked contracts. [Conjunct adoption](conjunct-adoption.md) records the generic product-engine extraction. [Thin composition evidence](thin-composition-evidence.md) retains hardware and geometry sources.

This record contains technical decisions only. Company strategy, monetization, partner agreements, legal interpretations and monetary scenarios have been moved to the private corporate research owner. Historical revisions remain in Git; they do not define the current product's business model.

## Repository and proposal provenance

| Source | Inspected revision or document | Technical consequence |
| --- | --- | --- |
| Frameshift | Earlier proposal `7527cb3`; app audits `d15afc9`, `45a1cda`; current handoff base `e60f207b0104ff08f765fca7f3d52839c7fe971e` | Preserve the existing native product, guide and exact physical contracts while extracting genuinely generic semantics |
| Refpath | Earlier research cohort `4a8e128628cac28706b0479bd2eabd3b9d240236` | Reuse runtime owners, qualify actual exports and joined consumer behavior; unreleased/private source is not a public distribution path |
| phoenix-assets | `c76b626104e938d1c6601b73ed8c4d9d7aa4feb3` | Existing Phoenix/SvelteKit asset tooling, generated contracts and Ash metadata; no second schema generator |
| ExMaude | `73acecf087934e593d6bae231b0e1a4d2ddf60b4` | Separate-process backend; explicit completion/bound/session evidence must be qualified |
| Conjunct | Initial CJ.01–CJ.08 draft producer contract | Generic physical model, evidence, geometry/procedure and operator-host seams; not a released SDK |

These are research snapshots, not automatically admitted dependency pins. Repeat owner/API discovery against the selected implementation cohort. All public requirements must be understandable without private memos or a maintainer's local Downloads file.

The stable direction is independent visual instructions/list first, optional external service integration last. Frameshift retains its profiles, models, procedures, native app and evaluation fixtures. Generic application-generation/effect machinery belongs in Refpath; generic physical composition belongs in Conjunct.

## Ash, assets and diagnostics

Ash domains group resources behind defined actions and policies. AshPostgres supplies server persistence without changing the local core's SQLite writer. Sources: [Ash domains](https://ash.hexdocs.pm/domains.html), [policies](https://ash.hexdocs.pm/policies.html), [AshPostgres](https://ash-postgres.hexdocs.pm/readme.html).

The selected frontend is Svelte 5/SvelteKit through [phoenix-assets](https://github.com/futhr/phoenix-assets). Pin actual exposed metadata and manifest behavior. Do not infer complete server rendering from a working asset build. Electric/Phoenix.Sync remains optional pending a real synchronization requirement.

[Beamlens](https://beamlens.hexdocs.pm/readme.html) describes a read-only diagnostic runtime. Qualify the exact dependency, native components, authorized observations, redaction and resource ceilings. Its [provider setup](https://beamlens.hexdocs.pm/providers.html) uses a BAML client registry; it is not automatically the same provider path as ordinary Refpath inference.

The earlier Refpath inspection found Beamlens optional for development/test and an observability owner capable of starting it when available. A production host must declare the dependency, select one supervisor and avoid a duplicate instance. Bound investigation frequency, concurrency, context and execution. Diagnostic failure cannot remove ordinary logs, metrics or alerts, and diagnostic models cannot mutate product/commitment state.

The shared operated deployment uses GreptimeDB-oriented metrics and bounded structured logs/traces, not ELK. This is host configuration, not a dependency of pure product decisions. Heavy CAD/model processing must not starve authoritative application/reconciliation work.

## Gleam and ExMaude

Existing Frameshift Gleam code shares selected host/guide decisions. Physical composition extends that boundary. Keep deterministic decisions free of database access, clocks, inference and provider I/O. Conjunct extraction must preserve canonical output parity and leave frame-specific rules here.

The inspected [ExMaude search implementation](https://github.com/futhr/ex_maude/blob/73acecf087934e593d6bae231b0e1a4d2ddf60b4/lib/ex_maude/maude.ex) returns bounded search solutions; an empty result or partial statistics do not establish global exhaustion. The [Maude manual](https://maude.lcc.uma.es/maude-manual/maude-manual.html) describes search within selected semantics. Require distinct counterexample, bounded-no-counterexample, exhausted-finite-model and inconclusive outcomes, with same-session witnesses and replay.

Use bounded separate OS processes through the qualified Port backend. Review formal predicates independently, mutate rules deliberately and replay counterexamples against production decisions. Formal evidence covers its model and bounds, not physical supplier truth. [Dependency notices](https://github.com/futhr/ex_maude/blob/main/THIRD_PARTY_NOTICES.md) distinguish library and executable licensing; retain exact tool/version notices in release artifacts without making a new licensing strategy here.

## Small-model qualification

No evidence makes Jev mandatory or establishes that it is the only suitable decision model. Begin with explicit actions and rules. Evaluate optional free-text intent using existing Refpath/Ollama support and exact Qwen3.5 2B/4B candidates. Compare trained compact classifiers when project labels exist; Jev can be an optional challenger for appropriate typed questions.

[Ollama structured outputs](https://docs.ollama.com/capabilities/structured-outputs) constrain response shape for supported profiles, not correctness or authority. Qualify the exact local/hosted implementation rather than assuming equivalent features. Pin artifacts from the [Qwen library](https://ollama.com/library/qwen3.5). The [2B model card](https://huggingface.co/Qwen/Qwen3.5-2B) reports instruction-following benchmarks; these are not Frameshift intent or engineering-fact accuracy.

The independent author's [Banking77 report](https://github.com/dhruvmehra/jevbench/blob/main/docs/results/2026-09-22-n500-summary.md) reported the following on 500 held-out examples on 2026-09-22:

| Model | Reported accuracy | Macro-F1 | Median latency |
| --- | --- | --- | --- |
| Fine-tuned DistilBERT | 88.0% | 86.4% | 8 ms |
| Jev 1.13 | 76.4% | 75.3% | 389 ms |
| Laya base | 38.2% | 32.1% | 130 ms |

These are inherited published results, not rerun measurements. DistilBERT was trained for the dataset; other models used label descriptions. Local Apple Silicon timing and a hosted OpenRouter hop are not directly comparable deployment conditions. The [method](https://github.com/dhruvmehra/jevbench) helps design a controlled comparison; it does not select a universal winner.

[SetFit](https://huggingface.co/docs/setfit/conceptual_guides/setfit), [Laya's report](https://github.com/NandhaKishorM/laya#benchmarks) and [FunctionGemma](https://ai.google.dev/gemma/docs/functiongemma/model_card) are specialist/classifier research leads. Training or evaluating a model does not automatically justify adding a Python runtime to Frameshift. Distinguish base checkpoint, fine-tuned artifact, inference host and evaluation method.

[Jev typed primitives](https://docs.typesafe.ai/introduction) and [documented jaggedness](https://docs.typesafe.ai/model-jaggedness/jev-1.13) make the previously ambiguous name explicit. Its numerical/date reasoning, indirection and adversarial-context limitations reinforce the need for deterministic arithmetic, compatibility and authorization. The [vendor methodology](https://typesafe.ai/blog/introducing-system-one-models-and-jev) is not independent engineering ground truth.

No model is admitted by this research. Build held-out examples covering exact part/revision identity, unit extraction, contradictory documents, missing geometry, ambiguous intent, abstention, source references, prompt injection, outage and bounded fallback. Measure quality, uncertainty and latency on the actual deployment. CPU/GPU memory depends on model/quantization/context/concurrency, not parameter count alone.

[Z3 optimization](https://microsoft.github.io/z3guide/docs/optimization/intro/) is a separate candidate only when configuration search demonstrates a need that existing deterministic rules do not satisfy. Optimization cannot turn a violated hard constraint into an eligible build.

## Runtime portability

Browser/offline validation, Popcorn/AtomVM experiments and network-edge execution are separate profiles. A browser success does not prove a Cloudflare Worker can run Phoenix/Ash, persistent Refpath workflows, native CAD conversion or local model serving. Qualify exact runtime libraries, host drivers, memory, persistence, sockets and restart semantics before claiming support.

A missing adaptive capability leaves the narrower deterministic guide useful. It does not authorize a copied local runtime or silently weakened authority. Keep provider/client code at its existing owner and record actual conformance gaps.

## Required implementation consequences

Maintain the independent list in D, nontransactional research/qualification in E and optional purchasing/service/care in final F. Preserve Ash/Svelte/phoenix-assets, bounded diagnostics, product-owned packs and procedures, deterministic physical decisions and targeted formal checks.

Models may propose or explain. They cannot admit a physical composition with required unknowns, grant new capabilities, change financial parameters, certify safety or authorize spending. External policy references and generic financial execution are handled through the [technical service contract](../architecture/build-commerce.md), not business assumptions in this file.

Record missing evidence in the [verification ledger](../architecture/verification.md). Specifications, source inspection, simulation, measured hardware and live producer qualification remain distinct.
