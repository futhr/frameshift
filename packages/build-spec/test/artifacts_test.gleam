import artifact_fixture as fixture
import frameshift_build/artifact/model.{Document, Tile} as _
import frameshift_build/assembly/model as a
import frameshift_build/compiler/artifact_layout.{Layout}
import frameshift_build/compiler/artifacts
import frameshift_build/compiler/finding.{AtMost, Measurement}
import frameshift_build/compiler/model.{LayoutInput}
import frameshift_build/model as p
import frameshift_build/resolution as r
import frameshift_physical.{Compatible, Incompatible, Interval, Unknown}
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import load_fixture

fn checks(value, layouts) {
  let assert Ok(findings) = artifacts.evaluate(value, layouts)
  findings
}

fn check(value, layout, code) {
  let assert Ok(finding) =
    list.find(checks(value, [layout]), fn(f) { f.check.code == code })
  finding
}

fn budget(value: r.Resolution, bytes: Int) -> r.Resolution {
  r.Resolution(
    ..value,
    assembly: a.Assembly(
      ..value.assembly,
      intent: a.Intent(..value.assembly.intent, storage_bytes: bytes),
    ),
  )
}

pub fn single_canvas_preserves_exact_wire_retention_units_and_sources_test() {
  let #(value, layout) = fixture.one()
  list.all(checks(value, [layout]), fn(f) { f.check.outcome == Compatible })
  |> should.be_true
  check(value, layout, "artifact.retained_payload").measurement
  |> should.equal(
    Some(Measurement(
      "byte",
      AtMost,
      Some(Interval(54, 90)),
      Some(Interval(1_000_000, 1_000_000)),
    )),
  )
  let raster = check(value, layout, "artifact.tile_raster")
  let assert [region] = raster.regions
  region.unit |> should.equal("count")
  list.length(raster.readings) |> should.equal(2)
  list.contains(
    raster.check.inputs,
    LayoutInput("controller", layout.identity, ["tiles", "panel"]),
  )
  |> should.be_true
}

pub fn all_quarter_turns_keep_exact_contact_and_repeated_profile_tiles_test() {
  let #(value, layout) = fixture.tiled(2, 2, 3)
  list.each([0, 90, 180, 270], fn(rotation) {
    let #(width, height) = case rotation {
      90 | 270 -> #(3, 2)
      _ -> #(2, 3)
    }
    let layout =
      Layout(
        ..layout,
        document: Document(..layout.document, width: 2 * width, height:, tiles: [
          Tile("panel-0", rotation, 0, 0),
          Tile("panel-1", rotation, width, 0),
        ]),
      )
    list.all(checks(value, [layout]), fn(f) { f.check.outcome == Compatible })
    |> should.be_true
  })
}

pub fn holes_overlap_and_exterior_pixels_are_separate_failures_test() {
  let #(value, layout) = fixture.tiled(2, 2, 3)
  let hole =
    Layout(
      ..layout,
      document: Document(..layout.document, width: 5, tiles: [
        Tile("panel-0", 0, 0, 0),
        Tile("panel-1", 0, 3, 0),
      ]),
    )
  check(value, hole, "artifact.coverage").check.reason
  |> should.equal("canvas_gap")
  let overlap =
    Layout(
      ..layout,
      document: Document(..layout.document, width: 3, tiles: [
        Tile("panel-0", 0, 0, 0),
        Tile("panel-1", 0, 1, 0),
      ]),
    )
  check(value, overlap, "artifact.coverage").check.outcome
  |> should.equal(Compatible)
  check(value, overlap, "artifact.tile_separation").check.outcome
  |> should.equal(Incompatible)
  let outside =
    Layout(..layout, document: Document(..layout.document, width: 3))
  list.any(checks(value, [outside]), fn(f) {
    f.check.code == "artifact.tile_width" && f.check.outcome == Incompatible
  })
  |> should.be_true
}

pub fn assignments_and_profile_roles_cannot_be_omitted_or_disguised_test() {
  let #(value, layout) = fixture.one()
  checks(value, [])
  |> list.map(fn(f) { f.check.reason })
  |> should.equal(["missing_artifact_layout", "missing_artifact_layout"])
  let missing = r.Resolution(..value, profiles: [])
  list.all(checks(missing, [layout]), fn(f) {
    f.check.code != "artifact.classification" || f.check.outcome == Unknown
  })
  |> should.be_true
  check(fixture.kind(value, "panel", "cable"), layout, "artifact.display_kind").check.outcome
  |> should.equal(Incompatible)
  check(
    fixture.kind(value, "controller", "frame"),
    layout,
    "artifact.controller_kind",
  ).check.outcome
  |> should.equal(Incompatible)
}

pub fn tile_owner_must_match_selected_controller_and_be_unambiguous_test() {
  let #(value, layout) = fixture.one()
  let assert Ok(controller) = r.find_instance(value, "controller")
  let wrong =
    r.Resolution(
      ..value,
      assembly: a.Assembly(
        ..value.assembly,
        instances: [
          a.Instance(..controller, id: "other"),
          ..value.assembly.instances
        ],
        dependencies: [a.Dependency("panel", "other", "controller")],
      ),
    )
  check(wrong, layout, "artifact.controller_owner").check.reason
  |> should.equal("wrong_layout_controller")
  let missing =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, dependencies: []),
    )
  check(missing, layout, "artifact.controller_owner").check.outcome
  |> should.equal(Unknown)
  let ambiguous =
    r.Resolution(
      ..wrong,
      assembly: a.Assembly(..wrong.assembly, dependencies: [
        a.Dependency("panel", "controller", "controller"),
        ..wrong.assembly.dependencies
      ]),
    )
  check(ambiguous, layout, "artifact.controller_owner").check.reason
  |> should.equal("multiple_controller_owners")
}

pub fn strict_layout_boundaries_refuse_duplicate_assignments_and_stale_scope_test() {
  let #(value, layout) = fixture.one()
  let d = layout.document
  list.each(
    [
      Document(..d, controller: "absent"),
      Document(..d, firmware: "other"),
      Document(..d, artifact: "other"),
      Document(..d, protocol: "other"),
      Document(..d, tiles: [Tile("absent", 0, 0, 0)]),
    ],
    fn(doc) {
      artifacts.evaluate(value, [Layout(..layout, document: doc)])
      |> should.equal(Error(p.InvalidReference))
    },
  )
  list.each(
    [
      Document(..d, width: 0),
      Document(..d, height: 32_769),
      Document(..d, tiles: [Tile("panel", 45, 0, 0)]),
      Document(..d, tiles: [Tile("panel", 0, -1, 0)]),
    ],
    fn(doc) {
      artifacts.evaluate(value, [Layout(..layout, document: doc)])
      |> should.equal(Error(p.InvalidRange))
    },
  )
  artifacts.evaluate(value, [layout, layout])
  |> should.equal(Error(p.DuplicateIdentifier))
  let alternate =
    Layout(
      ..layout,
      identity: "sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
    )
  artifacts.evaluate(value, [layout, alternate])
  |> should.equal(Error(p.DuplicateIdentifier))
  artifacts.evaluate(value, [
    Layout(..layout, document: Document(..d, schema: 2)),
  ])
  |> should.equal(Error(p.UnsupportedVersion))
  artifacts.evaluate(value, [
    Layout(
      ..layout,
      document: Document(..d, tiles: list.repeat(Tile("panel", 0, 0, 0), 65)),
    ),
  ])
  |> should.equal(Error(p.InvalidCount))
  artifacts.evaluate(value, [
    Layout(
      ..layout,
      document: Document(..d, tiles: [
        Tile("panel", 0, 0, 0),
        Tile("panel", 0, 2, 0),
      ]),
    ),
  ])
  |> should.equal(Error(p.DuplicateIdentifier))
  artifacts.evaluate(value, [
    Layout(..layout, document: Document(..d, tiles: [])),
  ])
  |> should.equal(Error(p.InvalidCount))
  artifacts.evaluate(value, list.repeat(layout, 65))
  |> should.equal(Error(p.InvalidCount))
}

pub fn unknown_encoding_and_ambiguous_raster_never_choose_fallbacks_test() {
  let #(value, layout) = fixture.one()
  let unsupported =
    Layout(
      ..layout,
      document: Document(..layout.document, encoding: "future-encoding"),
    )
  check(value, unsupported, "artifact.encoding").check.outcome
  |> should.equal(Unknown)
  let assert Some(m) =
    check(value, unsupported, "artifact.retained_payload").measurement
  m.required |> should.equal(None)
  let ambiguous =
    load_fixture.component(
      value,
      "panel",
      load_fixture.number("raster.width", "count", 1, 2),
    )
  check(ambiguous, layout, "artifact.tile_raster").check.reason
  |> should.equal("ambiguous_raster_dimension")
  check(ambiguous, layout, "artifact.coverage").check.outcome
  |> should.equal(Unknown)
  let missing =
    load_fixture.component(
      value,
      "panel",
      p.Fact("raster.height", [], "count", p.Missing),
    )
  check(missing, layout, "artifact.tile_raster").check.reason
  |> should.equal("missing_fact")
}

pub fn individual_payload_and_retained_budget_use_distinct_conservative_limits_test() {
  let #(value, layout) = fixture.one()
  let too_small =
    load_fixture.component(
      value,
      "controller",
      load_fixture.number("artifact.maximum", "byte", 17, 18),
    )
  check(too_small, layout, "artifact.payload_limit").check.outcome
  |> should.equal(Incompatible)
  check(budget(value, 90), layout, "artifact.retained_payload").check.outcome
  |> should.equal(Compatible)
  check(budget(value, 89), layout, "artifact.retained_payload").check.outcome
  |> should.equal(Incompatible)
  let slots =
    load_fixture.component(
      value,
      "controller",
      load_fixture.number("storage.retained_artifacts", "count", 2, 3),
    )
  check(slots, layout, "artifact.retention_minimum").check.outcome
  |> should.equal(Incompatible)
  let missing =
    load_fixture.component(
      value,
      "controller",
      p.Fact("storage.retained_artifacts", [], "count", p.Missing),
    )
  check(missing, layout, "artifact.retained_payload").check.reason
  |> should.equal("missing_fact")
  let fact = load_fixture.number("storage.retained_artifacts", "count", 3, 5)
  let assert [source] = fact.sources
  let conflicting =
    load_fixture.component(
      value,
      "controller",
      p.Fact(
        "storage.retained_artifacts",
        [source, p.Source(..source, locator: "contradiction")],
        "count",
        p.Conflicting,
      ),
    )
  check(conflicting, layout, "artifact.retained_payload").check.reason
  |> should.equal("conflicting_fact")
  let wrong_unit =
    load_fixture.component(value, "controller", p.Fact(..fact, unit: "byte"))
  check(wrong_unit, layout, "artifact.retained_payload").check.reason
  |> should.equal("unit_mismatch")
}

pub fn maximum_physical_count_keeps_every_tile_and_pair_obligation_test() {
  let #(value, layout) = fixture.tiled(63, 1, 1)
  let findings = checks(value, [layout])
  list.all(findings, fn(f) { f.check.outcome == Compatible }) |> should.be_true
  list.count(findings, fn(f) { f.check.code == "artifact.tile_separation" })
  |> should.equal(1953)
  list.count(findings, fn(f) { f.check.code == "artifact.tile_raster" })
  |> should.equal(63)
}

pub fn renderer_ceiling_and_retention_products_are_exact_on_both_runtimes_test() {
  let #(value, layout) = fixture.one()
  let value =
    value
    |> load_fixture.component(
      "panel",
      load_fixture.number("raster.width", "count", 32_768, 32_768),
    )
    |> load_fixture.component(
      "panel",
      load_fixture.number("raster.height", "count", 32_768, 32_768),
    )
    |> load_fixture.component(
      "controller",
      load_fixture.number(
        "storage.retained_artifacts",
        "count",
        1_000_000,
        1_000_000,
      ),
    )
    |> budget(1_099_511_627_776)
  let layout =
    Layout(
      ..layout,
      document: Document(..layout.document, width: 32_768, height: 32_768),
    )
  check(value, layout, "artifact.renderer_pixels").check.outcome
  |> should.equal(Incompatible)
  let retained = check(value, layout, "artifact.retained_payload")
  retained.check.outcome |> should.equal(Incompatible)
  let assert Some(m) = retained.measurement
  m.required
  |> should.equal(Some(Interval(3_221_225_472_000_000, 3_221_225_472_000_000)))
}
