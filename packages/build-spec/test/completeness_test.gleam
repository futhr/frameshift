import completeness_fixture as fixture
import frameshift_build/assembly/model as a
import frameshift_build/compiler/completeness
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/ownership
import frameshift_build/model as p
import frameshift_build/resolution as r
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import load_fixture
import power_fixture

fn check(value: r.Resolution, code: String, id: String) -> Finding {
  let assert Ok(f) =
    list.find(completeness.evaluate(value), fn(f) {
      f.check.code == code && list.first(f.check.instances) == Ok(id)
    })
  f
}

pub fn fixed_obligations_accept_explicit_roles_and_ignore_optional_flags_test() {
  let value = fixture.resolved() |> fixture.frame
  list.all(completeness.evaluate(value), fn(f) { f.check.outcome == Compatible })
  |> should.be_true
  let assert Ok(display) = r.find_instance(value, "panel")
  let #(finding, owner) = ownership.controller(display, value)
  finding.check.outcome |> should.equal(Compatible)
  let assert Some(owner) = owner
  owner.id |> should.equal("controller")
}

pub fn empty_requirements_optional_ports_and_no_wiring_cannot_make_a_complete_build_test() {
  let value = fixture.resolved()
  let missing =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, connections: [], dependencies: []),
    )
  list.each(
    [
      #("complete.power_sink", "panel"),
      #("complete.power_sink", "controller"),
      #("complete.signal_sink", "panel"),
      #("complete.signal_source", "controller"),
      #("complete.controller_owner", "panel"),
    ],
    fn(pair) {
      check(missing, pair.0, pair.1).check.outcome |> should.equal(Unknown)
    },
  )
  let omitted =
    r.Resolution(
      ..missing,
      profiles: list.map(missing.profiles, fn(profile) {
        r.ResolvedProfile(
          ..profile,
          profile: p.Profile(..profile.profile, ports: []),
        )
      }),
    )
  check(omitted, "complete.power_scope", "psu").check.outcome
  |> should.equal(Incompatible)
  check(omitted, "complete.signal_sink", "panel").check.outcome
  |> should.equal(Unknown)
}

pub fn exterior_and_enclosing_dimensions_are_required_and_cavity_cannot_exceed_outline_test() {
  let value = fixture.resolved() |> fixture.frame
  let missing =
    value
    |> load_fixture.component(
      "psu",
      p.Fact("outline.depth", [], "um", p.Missing),
    )
    |> load_fixture.component(
      "frame",
      p.Fact("outline.width", [], "um", p.Missing),
    )
  check(missing, "complete.outline.depth", "psu").check.outcome
  |> should.equal(Unknown)
  check(missing, "complete.outline.width", "frame").check.outcome
  |> should.equal(Unknown)
  let exceeds =
    load_fixture.component(
      value,
      "frame",
      load_fixture.number("inner.width", "um", 1900, 2001),
    )
  check(exceeds, "complete.cavity.width", "frame").check.outcome
  |> should.equal(Incompatible)
  let exact =
    load_fixture.component(
      value,
      "frame",
      load_fixture.number("inner.width", "um", 1900, 2000),
    )
  check(exact, "complete.cavity.width", "frame").check.outcome
  |> should.equal(Compatible)
}

pub fn raster_requires_an_exact_count_and_never_selects_a_nominal_test() {
  let value =
    fixture.resolved()
    |> load_fixture.component(
      "panel",
      load_fixture.number("raster.width", "count", 1023, 1024),
    )
    |> load_fixture.component(
      "panel",
      load_fixture.number("raster.width.nominal", "count", 1024, 1024),
    )
  check(value, "complete.raster.width", "panel").check.reason
  |> should.equal("ambiguous_raster_dimension")
  let missing =
    load_fixture.component(
      value,
      "panel",
      p.Fact("raster.width", [], "count", p.Missing),
    )
  check(missing, "complete.raster.width", "panel").check.reason
  |> should.equal("missing_fact")
}

pub fn powered_roles_cannot_claim_passive_or_self_supplied_scope_test() {
  let value = fixture.resolved()
  list.each(["source", "passthrough"], fn(mode) {
    let changed =
      load_fixture.component(
        value,
        "panel",
        power_fixture.terms("power.mode", [mode]),
      )
    check(changed, "complete.power_scope", "panel").check.outcome
    |> should.equal(Incompatible)
  })
  let hidden =
    r.Resolution(
      ..value,
      profiles: list.map(value.profiles, fn(profile) {
        case profile.profile.kind == "power" {
          True ->
            r.ResolvedProfile(
              ..profile,
              profile: p.Profile(..profile.profile, kind: "cable"),
            )
          False -> profile
        }
      }),
    )
  check(hidden, "complete.source_kind", "psu").check.outcome
  |> should.equal(Incompatible)
  let assert Ok(source) =
    list.find(completeness.evaluate(hidden), fn(f) {
      f.check.code == "complete.power_source"
    })
  source.check.reason |> should.equal("missing_connected_power_source")
}

pub fn controller_ownership_rejects_multiple_wrong_and_self_providers_test() {
  let value = fixture.resolved()
  let assert Ok(panel) = r.find_instance(value, "panel")
  let with_owners = fn(owners) {
    r.Resolution(
      ..value,
      assembly: a.Assembly(
        ..value.assembly,
        dependencies: list.map(owners, fn(id) {
          a.Dependency("panel", id, "controller")
        }),
      ),
    )
  }
  let #(missing, owner) = ownership.controller(panel, with_owners([]))
  missing.check.reason |> should.equal("missing_controller_owner")
  owner |> should.equal(None)
  let #(multiple, owner) =
    ownership.controller(panel, with_owners(["controller", "psu"]))
  multiple.check.reason |> should.equal("multiple_controller_owners")
  owner |> should.equal(None)
  let #(wrong, _) = ownership.controller(panel, with_owners(["psu"]))
  wrong.check.outcome |> should.equal(Incompatible)
  let #(self, _) = ownership.controller(panel, with_owners(["panel"]))
  self.check.reason |> should.equal("self_controller_owner")
}

pub fn unresolved_and_composite_profiles_are_never_dropped_test() {
  let value = fixture.resolved()
  let missing = r.Resolution(..value, profiles: [])
  list.each(value.assembly.instances, fn(i) {
    check(missing, "complete.classification", i.id).check.outcome
    |> should.equal(Unknown)
    check(missing, "complete.outline.width", i.id).check.outcome
    |> should.equal(Unknown)
  })
  let composite =
    r.Resolution(
      ..value,
      profiles: list.map(value.profiles, fn(profile) {
        case profile.profile.kind == "display" {
          True ->
            r.ResolvedProfile(
              ..profile,
              profile: p.Profile(..profile.profile, kind: "assembly"),
            )
          False -> profile
        }
      }),
    )
  check(composite, "complete.constituents", "panel").check.reason
  |> should.equal("composite_expansion_required")
}

pub fn all_units_at_the_instance_limit_receive_their_own_obligations_test() {
  let value = fixture.resolved()
  let assert Ok(panel) = r.find_instance(value, "panel")
  let others = list.filter(value.assembly.instances, fn(i) { i.id != "panel" })
  let panels =
    int.range(0, 62, [], fn(acc, n) {
      [a.Instance(..panel, id: "panel-" <> int.to_string(n)), ..acc]
    })
  let connections =
    list.flat_map(panels, fn(panel) {
      [
        a.Connection(
          a.Endpoint("controller", "out"),
          a.Endpoint(panel.id, "dc"),
        ),
        a.Connection(
          a.Endpoint("controller", "data"),
          a.Endpoint(panel.id, "data"),
        ),
      ]
    })
  let value =
    load_fixture.canonical(
      r.Resolution(
        ..value,
        assembly: a.Assembly(
          ..value.assembly,
          instances: list.append(others, panels),
          connections: [
            a.Connection(
              a.Endpoint("psu", "out"),
              a.Endpoint("controller", "supply"),
            ),
            ..connections
          ],
          dependencies: list.map(panels, fn(p) {
            a.Dependency(p.id, "controller", "controller")
          }),
        ),
      ),
    )
  let findings = completeness.evaluate(value)
  list.all(findings, fn(f) { f.check.outcome == Compatible }) |> should.be_true
  list.count(findings, fn(f) { f.check.code == "complete.outline.depth" })
  |> should.equal(64)
  list.count(findings, fn(f) { f.check.code == "complete.controller_owner" })
  |> should.equal(62)
}
