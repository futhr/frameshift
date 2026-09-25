import frameshift_build/assembly/model as a
import frameshift_build/compiler/envelope
import frameshift_build/compiler/facts
import frameshift_build/compiler/finding.{type Finding, AtMost, Measurement}
import frameshift_build/compiler/geometry
import frameshift_build/compiler/model.{BuildInput, ProfileInput}
import frameshift_build/model as p
import frameshift_build/resolution as r
import frameshift_physical.{Compatible, Incompatible, Interval, Unknown}
import geometry_fixture as fixture
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleeunit/should
import profile_fixture

fn check(value: r.Resolution, code: String, id: String) -> Finding {
  let assert Ok(finding) =
    geometry.evaluate(value)
    |> list.find(fn(f) {
      f.check.code == code && list.contains(f.check.instances, id)
    })
  finding
}

fn facts_without(value: r.Resolution, key: String) -> r.Resolution {
  let profile = fixture.part_profile()
  fixture.replace_part(
    value,
    p.Profile(
      ..profile,
      facts: list.filter(profile.facts, fn(f) { f.key != key }),
    ),
  )
}

pub fn every_face_preserves_measurement_and_exact_input_citations_test() {
  let value = fixture.resolved(130)
  let finding = check(value, "geometry.fit.x.positive", "part-a")
  finding.check.outcome |> should.equal(Compatible)
  finding.measurement
  |> should.equal(
    Some(Measurement(
      "um",
      AtMost,
      Some(Interval(24, 27)),
      Some(Interval(40, 42)),
    )),
  )
  list.map(finding.readings, fn(r) { r.key })
  |> should.equal(["outline.width", "clearance.right", "inner.width"])
  list.all(finding.readings, fn(r) { r.sources == [profile_fixture.source()] })
  |> should.be_true
  let assert Ok(part) = r.find_instance(value, "part-a")
  list.contains(
    finding.check.inputs,
    ProfileInput("part-a", part.profile, ["facts", "outline.width"]),
  )
  |> should.be_true
  list.contains(
    finding.check.inputs,
    BuildInput(["instances", "part-a", "placement"]),
  )
  |> should.be_true
  list.filter(geometry.evaluate(value), fn(f) {
    list.contains(f.check.instances, "part-a")
    && string.starts_with(f.check.code, "geometry.fit.")
  })
  |> list.length
  |> should.equal(6)
}

pub fn rotations_preserve_asymmetric_service_faces_and_whole_depth_test() {
  let expected = [
    #("outline.width", "clearance.left", "clearance.top"),
    #("outline.height", "clearance.bottom", "clearance.left"),
    #("outline.width", "clearance.right", "clearance.bottom"),
    #("outline.height", "clearance.top", "clearance.right"),
  ]
  list.index_map(expected, fn(e, i) {
    let value = fixture.resolved(i * 512)
    let assert Ok(part) = r.find_instance(value, "part-a")
    let assert [x, y, z] = envelope.read(part, value).axes
    #(x.outline.key, x.negative.key, y.negative.key) |> should.equal(e)
    z.outline.key |> should.equal("outline.depth")
    #(z.negative.key, z.positive.key)
    |> should.equal(#("clearance.front", "clearance.back"))
  })
}

pub fn exact_contact_passes_and_a_micrometre_overrun_fails_test() {
  let value = fixture.resolved(15)
  check(value, "geometry.fit.x.positive", "part-a").check.outcome
  |> should.equal(Compatible)
  check(fixture.resolved(16), "geometry.fit.x.positive", "part-a").check.outcome
  |> should.equal(Incompatible)
  check(fixture.resolved(2), "geometry.fit.x.negative", "part-a").check.outcome
  |> should.equal(Compatible)
  check(fixture.resolved(1), "geometry.fit.x.negative", "part-a").check.outcome
  |> should.equal(Incompatible)
}

pub fn missing_conflicting_and_wrong_unit_inputs_remain_unknown_test() {
  let value = fixture.resolved(0)
  let missing = facts_without(value, "outline.depth")
  check(missing, "geometry.fit.z.positive", "part-a").check.reason
  |> should.equal("missing_fact")
  check(missing, "geometry.fit.x.negative", "part-a").check.outcome
  |> should.equal(Incompatible)
  let profile = fixture.part_profile()
  let first = profile_fixture.source()
  let modified =
    list.map(profile.facts, fn(f) {
      case f.key {
        "outline.depth" -> p.Fact(..f, unit: "mv")
        "clearance.right" ->
          p.Fact(..f, value: p.Conflicting, sources: [
            first,
            p.Source(..first, locator: "second"),
          ])
        _ -> f
      }
    })
  let value = fixture.replace_part(value, p.Profile(..profile, facts: modified))
  check(value, "geometry.fit.z.positive", "part-a").check.reason
  |> should.equal("unit_mismatch")
  let conflict = check(value, "geometry.fit.x.positive", "part-a")
  conflict.check.reason |> should.equal("conflicting_fact")
  let assert Ok(reading) =
    list.find(conflict.readings, fn(r) { r.status == facts.ConflictingFact })
  list.length(reading.sources) |> should.equal(2)
}

pub fn a_single_known_separating_axis_is_enough_but_overlap_is_unknown_test() {
  // The rotated part separates on X while depth remains unknown.
  let separated = fixture.resolved(512) |> facts_without("outline.depth")
  check(separated, "geometry.separation", "part-a").check.outcome
  |> should.equal(Compatible)
  let overlap = check(fixture.resolved(130), "geometry.separation", "part-a")
  overlap.check.outcome |> should.equal(Unknown)
  overlap.check.reason |> should.equal("overlapping_service_envelopes")
  check(
    facts_without(fixture.resolved(130), "outline.depth"),
    "geometry.separation",
    "part-a",
  ).check.reason
  |> should.equal("missing_fact")
}

pub fn enclosure_topology_never_borrows_an_invalid_cavity_test() {
  let value = fixture.resolved(0)
  let assert [frame, part, other] = value.assembly.instances
  let modify = fn(instances) {
    r.Resolution(..value, assembly: a.Assembly(..value.assembly, instances:))
  }
  let absent = modify([part, other])
  let assert [topology, ..] = geometry.evaluate(absent)
  topology.check.reason |> should.equal("missing_enclosure")
  check(absent, "geometry.fit.x.positive", "part-a").check.outcome
  |> should.equal(Unknown)
  check(absent, "geometry.fit.x.negative", "part-a").check.outcome
  |> should.equal(Incompatible)
  let duplicate = modify([frame, a.Instance(..frame, id: "frame-2"), part])
  let assert [topology, ..] = geometry.evaluate(duplicate)
  topology.check.reason |> should.equal("multiple_enclosures")
  let invalid =
    modify([a.Instance(..frame, placement: a.Placement(90, 0, 0, 0)), part])
  let assert [topology, ..] = geometry.evaluate(invalid)
  topology.check.outcome |> should.equal(Incompatible)
  topology.check.reason |> should.equal("enclosure_transform")
  check(invalid, "geometry.fit.x.positive", "part-a").check.outcome
  |> should.equal(Unknown)
  let missing =
    r.Resolution(
      ..value,
      profiles: list.filter(value.profiles, fn(p) {
        p.identity != frame.profile
      }),
    )
  let assert [topology, ..] = geometry.evaluate(missing)
  topology.check.reason |> should.equal("missing_profile")
}

pub fn external_instances_do_not_consume_cavity_and_maximum_count_is_bounded_test() {
  let value = fixture.resolved(0)
  let assert [frame, part, other] = value.assembly.instances
  let external =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, instances: [
        frame,
        a.Instance(..part, location: "external"),
      ]),
    )
  geometry.evaluate(external) |> list.length |> should.equal(1)
  let parts =
    int.range(0, 64, [], fn(acc, i) {
      [a.Instance(..other, id: "part-" <> int.to_string(i)), ..acc]
    })
  let maximum =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, instances: parts),
    )
  geometry.evaluate(maximum) |> list.length |> should.equal(1 + 384 + 2016)
}

pub fn largest_coordinate_sum_stays_exact_and_does_not_wrap_test() {
  let value = fixture.resolved(0)
  let assert [frame, part, other] = value.assembly.instances
  let profile = fixture.part_profile()
  let profile =
    p.Profile(
      ..profile,
      facts: list.map(profile.facts, fn(f) {
        p.Fact(..f, value: p.KnownRange(5_000_000, 5_000_000))
      }),
    )
  let value = fixture.replace_part(value, profile)
  let value =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, instances: [
        frame,
        a.Instance(
          ..part,
          placement: a.Placement(0, 5_000_000, 5_000_000, 5_000_000),
        ),
        other,
      ]),
    )
  let finding = check(value, "geometry.fit.x.positive", "part-a")
  finding.check.outcome |> should.equal(Incompatible)
  finding.measurement
  |> should.equal(
    Some(Measurement(
      "um",
      AtMost,
      Some(Interval(15_000_000, 15_000_000)),
      Some(Interval(40, 42)),
    )),
  )
}

pub fn wrong_enclosure_kind_cannot_supply_its_numeric_dimensions_test() {
  let value = fixture.resolved(0)
  let value =
    r.Resolution(
      ..value,
      profiles: list.map(value.profiles, fn(resolved) {
        case resolved.profile.kind {
          "frame" ->
            r.ResolvedProfile(
              ..resolved,
              profile: p.Profile(..resolved.profile, kind: "controller"),
            )
          _ -> resolved
        }
      }),
    )
  let assert [topology, ..] = geometry.evaluate(value)
  topology.check.outcome |> should.equal(Incompatible)
  topology.check.reason |> should.equal("enclosure_kind_mismatch")
  check(value, "geometry.fit.x.positive", "part-a").check.outcome
  |> should.equal(Unknown)
}
