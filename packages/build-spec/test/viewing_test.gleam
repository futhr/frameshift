import frameshift_build/assembly/model as a
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{ProfileInput}
import frameshift_build/compiler/rectangles.{Rectangle}
import frameshift_build/compiler/viewing
import frameshift_build/model as p
import frameshift_build/resolution as r
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleeunit/should
import profile_fixture
import viewing_fixture as fixture

fn check(value: r.Resolution, code: String) -> Finding {
  let assert Ok(finding) =
    list.find(viewing.evaluate(value), fn(f) { f.check.code == code })
  finding
}

pub fn a_frame_and_exact_active_region_cover_the_opening_with_sources_test() {
  let value = fixture.resolved()
  let findings = viewing.evaluate(value)
  list.all(findings, fn(f) { f.check.outcome == Compatible }) |> should.be_true
  let coverage = check(value, "view.coverage")
  coverage.check.reason |> should.equal("aperture_covered")
  let assert [target, active] = coverage.regions
  target.role |> should.equal("target")
  target.possible |> should.equal(Some(Rectangle(10, 10, 110, 90)))
  active.role |> should.equal("active")
  active.guaranteed |> should.equal(target.possible)
  list.all(coverage.readings, fn(r) { r.sources == [profile_fixture.source()] })
  |> should.be_true
  let assert Ok(part) = r.find_instance(value, "part-a")
  list.contains(
    coverage.check.inputs,
    ProfileInput("part-a", part.profile, ["facts", "active.offset.x"]),
  )
  |> should.be_true
}

pub fn two_nested_mats_preserve_each_mask_and_plane_obligation_test() {
  let value =
    fixture.resolved()
    |> fixture.mat(False)
    |> fixture.mat(True)
    |> fixture.canonical
  let findings = viewing.evaluate(value)
  list.all(findings, fn(f) { f.check.outcome == Compatible }) |> should.be_true
  list.filter(findings, fn(f) { f.check.code == "view.mask.plane" })
  |> list.length
  |> should.equal(2)
  check(value, "view.coverage").check.instances
  |> should.equal(["mat-2", "part-a"])
}

pub fn wrong_mask_size_and_plane_order_do_not_hide_behind_coverage_test() {
  let value =
    fixture.resolved()
    |> fixture.mat(False)
    |> fixture.mat(True)
    |> fixture.canonical
  let overlapping = fixture.place(value, "mat-2", a.Placement(0, 5, 5, 2))
  list.any(viewing.evaluate(overlapping), fn(f) {
    f.check.code == "view.mask.plane" && f.check.outcome == Incompatible
  })
  |> should.be_true
  let hidden_display = fixture.place(value, "part-a", a.Placement(0, 10, 10, 5))
  check(hidden_display, "view.display.plane").check.outcome
  |> should.equal(Incompatible)
  check(hidden_display, "view.coverage").check.outcome |> should.equal(Unknown)
  let shifted = fixture.place(value, "mat-1", a.Placement(0, 15, 0, 1))
  check(shifted, "view.mask.outer").check.outcome |> should.equal(Incompatible)
}

pub fn tiled_displays_preserve_a_one_micrometre_seam_test() {
  let value =
    fixture.resolved()
    |> fixture.set_fact(
      "display",
      "outline.width",
      fixture.fact("outline.width", 50),
    )
    |> fixture.set_fact(
      "display",
      "active.width",
      fixture.fact("active.width", 50),
    )
  let assert [frame, panel] = value.assembly.instances
  let other =
    a.Instance(..panel, id: "part-b", placement: a.Placement(0, 60, 10, 10))
  let value =
    fixture.canonical(
      r.Resolution(
        ..value,
        assembly: a.Assembly(..value.assembly, instances: [frame, panel, other]),
      ),
    )
  check(value, "view.coverage").check.outcome |> should.equal(Compatible)
  let seam = fixture.place(value, "part-b", a.Placement(0, 61, 10, 10))
  check(seam, "view.coverage").check.outcome |> should.equal(Incompatible)
  check(seam, "view.coverage").check.reason
  |> should.equal("aperture_not_covered")
}

pub fn uncertain_or_missing_active_geometry_does_not_get_centered_or_accepted_test() {
  let source = profile_fixture.source()
  let value =
    fixture.resolved()
    |> fixture.set_fact(
      "display",
      "active.offset.x",
      p.Fact("active.offset.x", [], "um", p.Missing),
    )
  check(value, "view.coverage").check.outcome |> should.equal(Unknown)
  let conflict =
    fixture.set_fact(
      value,
      "display",
      "active.offset.x",
      p.Fact(
        "active.offset.x",
        [source, p.Source(..source, locator: "other")],
        "um",
        p.Conflicting,
      ),
    )
  check(conflict, "view.coverage").check.reason
  |> should.equal("conflicting_fact")
  let mat =
    fixture.resolved()
    |> fixture.mat(False)
    |> fixture.set_fact(
      "mat",
      "outline.depth",
      p.Fact("outline.depth", [], "um", p.Missing),
    )
    |> fixture.canonical
  check(mat, "view.display.plane").check.outcome |> should.equal(Unknown)
  check(mat, "view.coverage").check.outcome |> should.equal(Unknown)
}

pub fn possible_obstruction_remains_unknown_but_disjoint_and_behind_parts_pass_test() {
  let value = fixture.resolved()
  let assert [frame, panel] = value.assembly.instances
  // Reuse a display outline as a second physical body in front of the first.
  let front =
    a.Instance(..panel, id: "part-b", placement: a.Placement(0, 10, 10, 5))
  let value =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, instances: [frame, panel, front]),
    )
  let obstacle = check(value, "view.obstruction")
  obstacle.check.reason |> should.equal("possible_obstruction")
  obstacle.check.outcome |> should.equal(Unknown)
  let disjoint = fixture.place(value, "part-b", a.Placement(0, 120, 10, 5))
  check(disjoint, "view.obstruction").check.reason
  |> should.equal("outside_view")
  let behind = fixture.place(value, "part-b", a.Placement(0, 10, 10, 15))
  check(behind, "view.obstruction").check.reason
  |> should.equal("behind_view_plane")
}

pub fn missing_profiles_external_displays_and_no_enclosure_are_explicit_test() {
  let value = fixture.resolved()
  let assert [frame, panel] = value.assembly.instances
  let missing =
    r.Resolution(
      ..value,
      profiles: list.filter(value.profiles, fn(p) {
        p.identity != panel.profile
      }),
    )
  check(missing, "view.classification").check.reason
  |> should.equal("missing_profile")
  check(missing, "view.display.required").check.outcome |> should.equal(Unknown)
  check(missing, "view.coverage").check.outcome |> should.equal(Unknown)
  let external =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, instances: [
        frame,
        a.Instance(..panel, location: "external"),
      ]),
    )
  check(external, "view.location").check.reason
  |> should.equal("unsupported_view_location")
  let no_frame =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, instances: [panel]),
    )
  check(no_frame, "view.enclosure").check.outcome |> should.equal(Unknown)
}

pub fn canonical_order_and_equal_depth_mask_ties_are_deterministic_test() {
  let value =
    fixture.resolved()
    |> fixture.mat(False)
    |> fixture.mat(True)
    |> fixture.place("mat-2", a.Placement(0, 5, 5, 1))
  let reversed =
    r.Resolution(
      ..value,
      profiles: list.reverse(value.profiles),
      assembly: a.Assembly(
        ..value.assembly,
        instances: list.reverse(value.assembly.instances),
      ),
    )
  viewing.evaluate(fixture.canonical(value))
  |> should.equal(viewing.evaluate(fixture.canonical(reversed)))
  let planes =
    viewing.evaluate(fixture.canonical(value))
    |> list.filter(fn(f) { f.check.code == "view.mask.plane" })
  list.map(planes, fn(f) { f.check.instances })
  |> should.equal([["frame", "mat-1"], ["mat-1", "mat-2"]])
}

pub fn unknown_obstacle_cannot_be_ignored_by_complete_active_coverage_test() {
  let value = fixture.resolved()
  let assert [frame, panel] = value.assembly.instances
  let unknown =
    a.Instance(
      ..panel,
      id: "unknown",
      profile: "sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
      placement: a.Placement(0, 0, 0, 0),
    )
  let value =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, instances: [frame, panel, unknown]),
    )
  check(value, "view.coverage").check.outcome |> should.equal(Compatible)
  check(value, "view.obstruction").check.outcome |> should.equal(Unknown)
  check(value, "view.obstruction").check.reason
  |> should.equal("missing_profile")
  check(value, "view.classification").check.outcome |> should.equal(Unknown)
}

pub fn maximum_instance_count_evaluates_every_ordered_obstacle_pair_test() {
  let value = fixture.resolved()
  let assert [frame, panel] = value.assembly.instances
  let panels =
    int.range(0, 63, [], fn(acc, i) {
      [a.Instance(..panel, id: "panel-" <> int.to_string(i)), ..acc]
    })
  let value =
    fixture.canonical(
      r.Resolution(
        ..value,
        assembly: a.Assembly(..value.assembly, instances: [frame, ..panels]),
      ),
    )
  viewing.evaluate(value)
  |> list.filter(fn(f) { f.check.code == "view.obstruction" })
  |> list.length
  |> should.equal(3906)
}
