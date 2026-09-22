# Scope discipline

Classify the request before acting.

| Mode | Expected result | Out of scope by default |
|---|---|---|
| Research | Evidence and a decision record under `docs/research/` | Source code or frozen requirements |
| Specification | Requirements in the owning `docs/` subtree | Implementation presented as complete |
| Implementation | The smallest change that satisfies an approved specification | Adjacent refactors or speculative platforms |
| Fix | A reproducible repair and regression evidence | New features |
| Review | Findings with file and line references | File changes |

Before creating a file, search for an existing owner. Extend that owner when it
can carry the new material without mixing unrelated lifecycles.

Do not introduce a plugin system, service boundary, protocol layer, cache,
background process, feature flag, hardware abstraction, or configuration system
for hypothetical future use. A display adapter or capability belongs in the
architecture only when a current reference target or explicit interoperability
requirement needs it.

Do not turn a candidate into a dependency to make a document feel decisive.
State the unresolved decision and the evidence required to close it.
