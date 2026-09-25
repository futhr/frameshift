# Sourced physical candidates

These are immutable input profiles for the existing Paper, Photo and Pixel
baselines. They are **candidates**, with no selected controller or qualified
assembly. The complete [physical contract](../../docs/architecture/physical-build-contract.md)
and [source review](../../docs/research/build-platform-decisions.md#c-sourced-baseline-profile-admission-2026-09-24)
define their interpretation.

These product-owned revisions and their hashes are retained by the
[Conjunct integration](../../docs/architecture/conjunct-integration.md).
They are not generic producer schemas or signed federated packs. Richer
claim/geometry/procedure mappings require explicit successor identities and
rights evidence; they cannot silently promote these candidates.

`manifest.json` pins each canonical file's versioned identity. It separately
records labels, unresolved gates and source retrieval metadata. Each fact keeps
its source digest, document revision and locator. Manufacturer/board revisions
remain `unverified`; a document revision cannot identify a delivered component.

| Profile | Scope and limitations |
| --- | --- |
| Waveshare 13.3-inch E6 panel | Native portrait axes; active-area and body tolerances from the drawing. Film/glass thickness is layer-specific. Full connection envelope and thermal conflict remain unresolved. The development HAT is not included. |
| BOE MV270QHM-N40 | Preliminary P1 source; nominal geometry with a mechanical-model scope conflict. Logic and backlight ports are distinct. Electrical figures retain their test conditions in fact names and source locators. |
| Waveshare P3 SKU 22100 | One 64×64 module. Nominal dimensions and nameplate power do not establish tolerances, exact pinout, driver revision, supply design or thermal capacity. Six modules are a later explicit layout, not one indivisible product. |

Facts ending in `.nominal`, `.typical`, `.nameplate` or a condition suffix must
not be substituted for required worst-case bounds. Explicit missing facts are
not zero. Port labels do not establish pin compatibility. Required roles do
not constitute a complete shopping list; the composite compiler must account
for the full enclosure, controller, power, protection, mounting and assembly.

Waveshare's 180-second and 24-hour refresh guidance remains manufacturer advice.
Frameshift's enforced receiver minimum and provisional six-hour suggestion
belong to the separate [display policy](../../docs/architecture/display-timing.md).
No profile here asserts an energy-optimal dwell.

## Integrity and updates

Run `scripts/check build-spec`. The offline gate validates profile bytes and
hashes on both BEAM and JavaScript, every source/revision reference, manifest
schema, unique records and the complete set of files. Regression fixtures retain
conflicts and incomplete assembly facts. The gate checks repository integrity;
it does not authenticate the manufacturer or repeat a physical measurement.

A changed source or interpretation requires a new reviewed profile revision
and identity. Retain old revisions while accepted builds reference them.
Changing the public label or retrieval metadata cannot alter physical identity.
Live pages may change; their current bytes are never fetched during compilation.
The manifest contains digests of the bodies retrieved on 2026-09-24. The
download-completion timestamps are retained as `retrieved_at`, alongside the
retrieval date, for explicit catalog observation imports.
Original manufacturer PDFs/HTML are not redistributed in this repository. Source access,
archival permissions and current qualification remain catalog responsibilities.
