# Frameshift Claude configuration

This directory contains repository-specific rules and reusable skills. The
configuration is self-contained and tailored to Frameshift's research and
prototype needs.

## Layout

```text
.claude/
├── rules/
│   ├── agentic-workflow.md
│   └── scope-discipline.md
├── skills/
│   ├── decision-provenance/
│   ├── decision-research/
│   ├── evidence-prose/
│   ├── hardware-validation/
│   ├── spec-authoring/
│   ├── spec-readiness/
│   └── unslop/
└── settings.json
```

Skills are selected from their descriptions. They can also be invoked by name,
for example `decision-research secure Frame Protocol pairing` or
`unslop docs/architecture/system.md`.

The workflow is research, specification, readiness review, implementation, and
validation. A later stage may send work back to an earlier stage when evidence
is missing.

## Provenance

These skills adapt reusable research, specification, evidence, and prose-review
patterns from sibling repositories such as Orbit, Diggymon, Reloved Commons,
and the Refpath projects. They were rewritten around Frameshift's hardware,
power, protocol, language, and validation boundaries. No sibling application
code or dependency is imported by this configuration.
