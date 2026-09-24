# Build Research and Orchestration

**Status:** normative integration and evaluation contract; implementation open
**Owner:** Frameshift domain commands and `packs/frameshift/`; external Refpath runtime
**Milestone:** E for research/qualification; transactional workflows only in final F

## Runtime ownership and admission

**BO-01 — One runtime.** Embed Refpath at an exact qualified revision in the
Phoenix build-platform host. Reuse its schedules, task/attempt identities,
authority enforcement, effect journal, budgets, pause/recovery and verification
contracts. Do not implement a second scheduler, generic effect ledger, agent
engine or adaptive composition runtime. Refpath status labels are not consumer
conformance evidence; verify the actual host API and migrations at that revision.

**BO-02 — Frameshift-owned packs.** Research and, in F, procurement/care packs,
task bindings, schemas, methods, rubrics and evaluations are versioned and tested
in `packs/frameshift/` in this repository. Refpath loads an admitted exact pack
revision. The host owns catalog/order truth and exposes authorized typed actions;
packs cannot write domain tables, change policies, or grant purchasing authority.
Reusable runtime, provider and capability-contract improvements belong upstream.

Pin each execution's task contract, pack/rule/model/source revisions, permitted
capabilities, actor and resource scope, cost/time limits, and authority expiry.
New generations affect new admissions only. Resume checks must reject revoked,
expired or incompatible authority while retaining accepted identities and
reconciling outstanding effects. A deployment or pack rollback cannot erase an
unknown external outcome. Research/adaptive-composition descriptions are not
evidence that these boundaries are already implemented upstream.

| Existing seam | Required integration evidence or known gap |
| --- | --- |
| RT.03 / RT.64 schedules | Exact task binding, duplicate/DST occurrence behavior, report/assisted/unattended operation, budget, pause, maker/checker and recovery |
| RT.68 task/attempt contract | Consumer tests for identity and terminal/unknown outcomes; inspected implementation/spec remains partial |
| RT.77 / SY.33 effect and capability contracts | Admitted operation, durable effect intent, normalized receipt, explicit unknown outcome and reconciliation; inspected status labels and narrative do not consistently establish completion |
| Research engine | Reuse source manifests and extraction/evidence methods; host adapters acquire sources and Frameshift commands commit catalog changes |
| RT.59 / R.153 composition | Prove durable flow, restart admission, generation changes and revocation at the pinned revision; no copied host runtime |
| Commerce/post-purchase contracts | In F only: implement missing placement/cancellation and actual notification/refund effects; current methods/drafts are not executed external actions |

## Autonomous nontransactional research

**BO-03 — Research loop.** A versioned schedule contains permitted source scope,
budget, cutoff, freshness targets and required evidence. The loop must:

1. Acquire permitted manufacturer documents and supported supplier feeds,
   retaining exact revisions, content digests, retrieval dates and provenance.
2. Extract candidate facts with field-level source references. Preserve missing
   values and conflicting observations; distinguish source facts from inference.
3. Independently check schema, physical constraints, required formal results,
   existing evidence, supported integration capability and applicable policy.
4. Publish a revision automatically only when every preapproved applicable gate
   passes. Otherwise retain a candidate or quarantine and record a recoverable
   exception with the missing evidence and responsible owner.
5. Detect changed sources, end-of-life, safety notices, stale evidence and
   affected derived configurations. Recompute or quarantine affected projections
   without rewriting accepted specs or paired-device state.

Treat acquired text as untrusted data. It cannot modify permissions, supplier
bank details, payment destinations, executable code, Maude modules, model tools,
or admission policy. Require reviewed capability admission for a new protocol
or source connector. New facts that fit an existing schema may be admitted as
data; unsupported retailer operations remain unavailable for automation.

Retain source material only within permission and retention constraints. Fetches
must have URL/redirect, network destination, size, timeout, rate and parser bounds.
Use source-change detection and caching to limit unnecessary acquisition. An
inaccessible source leaves evidence stale/unknown; it does not fabricate facts.

## Decision model selection

**BO-04 — Roles.** Explicit controls and versioned Gleam/Elixir rules are the
default for customer actions and business policy. Optional free text proposes
an intent or clarification; it cannot authorize spending or prove compatibility.
Use separate tasks and acceptance gates for intent routing, source-evidence
triage and preference ranking. Apply hard eligibility constraints before ranking.

| Candidate | Permitted role and adoption condition |
| --- | --- |
| Rules/explicit UI | Baseline and outage fallback; closed actions and transparent policy |
| Local Ollama Qwen3.5 2B/4B | Initial language-routing candidates through Refpath's existing provider; short bounded context/output, closed intent enum and `unknown`/abstain |
| Compact classifier/SetFit approach | Evaluate after obtaining Frameshift labels; adopt only with a repository-compliant serving/export path and demonstrated advantage |
| Jev | Optional challenger for structured evidence questions, revision conflicts, entity matches or soft preference decisions; no required dependency without task-specific value |
| FunctionGemma/Laya or another small model | Research candidates with the same held-out gates; published task-specific results do not qualify Frameshift use |
| Z3/SMT | Consider only if a measured combinatorial optimization requirement exceeds ordinary constraint code; no default extra solver service |

Reuse Refpath's Ollama transport, structured output, accounting and provider
controls. Qualify exact model digest, quantization, context, output schema,
thinking controls and serving configuration. JSON-schema output constrains shape;
Frameshift still validates meaning and authority. A model-supplied confidence
number is not calibrated probability. Do not silently fall back to cloud or a
different model. Cloud research uses public component evidence by default and
must not transmit customer information or credentials.

The repository's no-project-owned-Python rule applies to classifiers, scripts,
tests and examples as well as the app. SetFit/Laya research is not authorization
to add a Python application service. A compliant exported model/serving path or
a separately agreed external training tool boundary must be established before
adoption. Do not introduce every candidate or a dedicated GPU merely to avoid
small per-call API charges.

**BO-05 — Qualification.** Keep cases, labels, rubrics and versioned outcomes in
`packs/frameshift/evals/`; reuse Refpath's generic evaluation machinery. Compare
the same cases, allowed labels and response contract against explicit rules.
Hold out manufacturers, revisions and paraphrase families to prevent leakage.
Include ambiguity, unsupported requests, unknowns, numerical contradictions,
hostile source text and Swedish/English if those languages are claimed.

Record dataset provenance/license, labeling and adjudication, splits, model
identity, serving parameters, hardware, warm/cold conditions, failures and all
billable work. Report macro-F1, per-class false acceptance/error rates,
abstention coverage, calibration where meaningful, uncertainty intervals,
p50/p95 latency, cold start, memory and full cost per correctly resolved case.
Include retries, timeouts, abstentions and escalation in comparisons. Freeze
task-specific thresholds before selecting the cheapest qualifying candidate;
do not retroactively weaken a threshold to admit a favored model. Requalify
model/provider/rubric changes. No Frameshift benchmark has yet selected a winner.

**BO-06 — Cost limits.** Use changed-source research, relevant excerpts, batching
of questions sharing source context, and caches keyed by source/question/model/
policy revision. Apply request, token, time, concurrency and spend limits,
bounded retries and circuit breakers through Refpath. Reconcile provider usage
and estimated reservations so parallel work cannot exceed the admitted budget.
Local inference has compute, memory, energy and maintenance costs. Select by
total task cost and error handling, not provider token price alone. Treat
probabilities for separate questions as dependent unless justified; do not
multiply them into unsupported certainty. Pricing/benchmarks are dated research
in [the decision record](../research/build-platform-decisions.md), not fixed
production assumptions.

## Failure, safety and completion

**BO-07 — Effect discipline.** Even before commerce, source fetches, notifications
and catalog commands need exact task/attempt identity, scoped actor authority,
durable receipts, and declared retry behavior. Domain actions are idempotent
by command identity and canonical payload; changed payloads conflict. Use
Refpath's effect boundary rather than a second host effect journal. Do not keep
database transactions open over provider I/O. Persist reconciliation links and
test interruption between runtime receipt and domain commit in either direction.

Research provider outages leave work pending and preserve the last admitted
catalog. Customers can still inspect deterministic configurations and export
shopping lists. Routine admitted work proceeds unattended. Exceptions require
the specific missing fact, authority or external action; a human cannot approve
away an unknown physical fact or convert an unknown payment into failure.

**BO-08 — E acceptance.** Demonstrate exact-revision runtime/pack conformance,
schedule duplication and DST handling, independent admission checks, source
injection refusal, budgets, provider outage, restart, generation revocation,
quarantine propagation and safe resumption. Required model use must have passed
the evaluation gate; deterministic paths remain complete without inference.
Measure source freshness, eligible automatic completions, manual interventions,
false admissions, queue age, unknown outcomes, inference spend and diagnostic
resource limits under the [diagnostics contract](diagnostics.md).

Prove Beamlens redaction, authorized read-only queries, single supervision,
provider/budget failure and runtime overhead separately from intent-model
qualification. E must not place an order, charge, cancel, refund or alter a
supplier commitment. Those adapters, packs and failure proofs are part of
[F, the final purchasing milestone](build-commerce.md).
