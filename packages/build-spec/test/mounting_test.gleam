import contract_fixture
import frameshift_build/assembly/model as a
import frameshift_build/compiler/finding.{type Finding, AtMost, Measurement}
import frameshift_build/compiler/mount_context as ctx
import frameshift_build/compiler/mount_flow
import frameshift_build/compiler/mounting
import frameshift_build/model as p
import frameshift_build/resolution as r
import frameshift_physical.{Compatible, Incompatible, Interval, Unknown}
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import load_fixture
import mount_fixture as fixture
import power_fixture
import thermal_fixture

fn checks(value: r.Resolution) -> List(Finding) {
  let assert Ok(findings) = mounting.evaluate(value)
  findings
}

fn check(value: r.Resolution, code: String, id: String) -> Finding {
  let assert Ok(f) =
    list.find(checks(value), fn(f) {
      f.check.code == code && list.contains(f.check.instances, id)
    })
  f
}

fn load(value: r.Resolution, id: String) {
  mount_flow.demand(a.Endpoint(id, "in"), ctx.prepare(value))
}

pub fn repeated_instances_load_their_real_support_and_preserve_evidence_test() {
  let value = fixture.resolved()
  list.all(checks(value), fn(f) { f.check.outcome == Compatible })
  |> should.be_true
  check(value, "mount.shared_capacity", "frame").measurement
  |> should.equal(
    Some(Measurement(
      "g",
      AtMost,
      Some(Interval(200, 240)),
      Some(Interval(240, 240)),
    )),
  )
  load(value, "part-a").mass |> should.equal(Some(Interval(100, 120)))
  let readings = check(value, "mount.shared_capacity", "frame").readings
  list.any(readings, fn(r) { r.instance == "part-a" && r.key == "mass" })
  |> should.be_true
  list.any(readings, fn(r) { r.instance == "part-b" && r.key == "mass" })
  |> should.be_true
}

pub fn adapters_add_their_own_mass_to_every_carried_child_test() {
  let value = fixture.tree(3, 1)
  load(value, "part-0").mass |> should.equal(Some(Interval(300, 360)))
  load(value, "part-1").mass |> should.equal(Some(Interval(200, 240)))
  let own_input =
    contract_fixture.fact(
      value,
      "part-0",
      "in",
      load_fixture.number("mount.capacity", "g", 359, 359),
    )
  check(own_input, "mount.input_capacity", "part-0").check.outcome
  |> should.equal(Incompatible)
  let output =
    contract_fixture.fact(
      value,
      "part-0",
      "out",
      load_fixture.number("mount.capacity", "g", 239, 239),
    )
  check(output, "mount.output_capacity", "part-0").check.outcome
  |> should.equal(Incompatible)
}

pub fn multiple_outputs_share_one_component_payload_limit_test() {
  let value = fixture.resolved()
  let assert Ok(frame) = r.find_instance(value, "frame")
  let profiles =
    list.map(value.profiles, fn(profile) {
      case profile.identity == frame.profile {
        True ->
          r.ResolvedProfile(
            ..profile,
            profile: p.Profile(..profile.profile, ports: [
              fixture.port("out", "source", 120),
              fixture.port("other", "source", 120),
            ]),
          )
        False -> profile
      }
    })
  let connections =
    list.map(value.assembly.connections, fn(c) {
      case c.to.instance == "part-b" {
        True -> a.Connection(..c, from: a.Endpoint("frame", "other"))
        False -> c
      }
    })
  let value =
    load_fixture.canonical(
      r.Resolution(
        ..value,
        profiles:,
        assembly: a.Assembly(..value.assembly, connections:),
      ),
    )
    |> load_fixture.component(
      "frame",
      load_fixture.number("mount.capacity", "g", 239, 300),
    )
  checks(value)
  |> list.filter(fn(f) { f.check.code == "mount.output_capacity" })
  |> list.all(fn(f) { f.check.outcome == Compatible })
  |> should.be_true
  check(value, "mount.shared_capacity", "frame").check.outcome
  |> should.equal(Incompatible)
  let fanout =
    power_fixture.set_fact(
      fixture.resolved(),
      "frame",
      load_fixture.number("fanout.maximum", "count", 1, 1),
    )
  check(fanout, "mount.fanout", "frame").check.outcome
  |> should.equal(Incompatible)
}

pub fn optional_or_multiple_supports_cannot_remove_or_divide_loads_test() {
  let value = fixture.resolved()
  let missing =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, connections: []),
    )
  check(missing, "mount.feed", "part-a").check.reason
  |> should.equal("missing_support")
  check(missing, "mount.path", "part-a").check.outcome |> should.equal(Unknown)
  let multiple =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, connections: [
        a.Connection(a.Endpoint("part-b", "out"), a.Endpoint("part-a", "in")),
        ..value.assembly.connections
      ]),
    )
  load(multiple, "part-a").mass |> should.equal(None)
  check(multiple, "mount.feed", "part-a").check.reason
  |> should.equal("ambiguous_support")
  check(multiple, "mount.shared_capacity", "frame").check.outcome
  |> should.equal(Unknown)
}

pub fn anchorless_cycle_cannot_claim_an_anchor_or_finite_payload_test() {
  let value = fixture.resolved()
  let cyclic =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, connections: [
        a.Connection(a.Endpoint("part-a", "out"), a.Endpoint("part-b", "in")),
        a.Connection(a.Endpoint("part-b", "out"), a.Endpoint("part-a", "in")),
      ]),
    )
  load(cyclic, "part-a").reason |> should.equal("mount_flow_cycle")
  check(cyclic, "mount.path", "part-a").check.reason
  |> should.equal("mount_flow_cycle")
  check(cyclic, "mount.acyclic", "part-a").check.outcome
  |> should.equal(Incompatible)
}

pub fn internal_anchor_and_unsupported_modes_cannot_bypass_support_test() {
  let value =
    fixture.resolved()
    |> load_fixture.component(
      "part-a",
      power_fixture.terms("mount.mode", ["anchor"]),
    )
  check(value, "mount.mode", "part-a").check.reason
  |> should.equal("internal_anchor")
  check(value, "mount.path", "part-a").check.outcome |> should.equal(Unknown)
  let unknown =
    load_fixture.component(
      value,
      "part-a",
      power_fixture.terms("mount.mode", ["magical"]),
    )
  check(unknown, "mount.mode", "part-a").check.outcome |> should.equal(Unknown)
  let ambiguous =
    load_fixture.component(
      value,
      "part-a",
      power_fixture.terms("mount.mode", ["anchor", "supported"]),
    )
  check(ambiguous, "mount.mode", "part-a").check.outcome
  |> should.equal(Unknown)
  let wrong =
    load_fixture.component(
      fixture.resolved(),
      "frame",
      power_fixture.terms("mount.mode", ["supported"]),
    )
  check(wrong, "mount.mode", "frame").check.reason
  |> should.equal("mount_mode_port_mismatch")
}

pub fn installation_kind_and_anchor_contract_remain_separate_obligations_test() {
  let value =
    fixture.resolved()
    |> load_fixture.component(
      "frame",
      power_fixture.terms("mount.kind", ["stand"]),
    )
    |> load_fixture.component(
      "frame",
      p.Fact("mount.contract", [], "token", p.Missing),
    )
  check(value, "mount.installation", "part-a").check.outcome
  |> should.equal(Incompatible)
  check(value, "mount.anchor_contract", "frame").check.outcome
  |> should.equal(Unknown)
  let alternative =
    load_fixture.component(
      value,
      "frame",
      power_fixture.terms("mount.kind", ["stand", "wall"]),
    )
  check(alternative, "mount.installation", "part-a").check.outcome
  |> should.equal(Compatible)
  let external =
    fixture.resolved()
    |> fixture.split("part-b")
    |> thermal_fixture.instance("part-b", fn(i) {
      a.Instance(..i, location: "external")
    })
    |> load_fixture.component(
      "part-b",
      power_fixture.terms("mount.mode", ["anchor"]),
    )
    |> load_fixture.component(
      "part-b",
      power_fixture.terms("mount.kind", ["stand"]),
    )
    |> load_fixture.component(
      "part-b",
      power_fixture.terms("mount.contract", ["fixture-external"]),
    )
  let external =
    r.Resolution(
      ..external,
      profiles: list.map(external.profiles, fn(p) {
        case p.profile.id == "fixture-independent" {
          True ->
            r.ResolvedProfile(..p, profile: p.Profile(..p.profile, ports: []))
          False -> p
        }
      }),
      assembly: a.Assembly(
        ..external.assembly,
        connections: list.filter(external.assembly.connections, fn(c) {
          c.to.instance != "part-b"
        }),
      ),
    )
  list.all(checks(external), fn(f) { f.check.outcome == Compatible })
  |> should.be_true
}

pub fn missing_mass_or_profile_contaminates_all_upstream_payload_test() {
  let value =
    fixture.tree(3, 1)
    |> load_fixture.component("part-0", p.Fact("mass", [], "g", p.Missing))
    |> load_fixture.component(
      "part-0",
      load_fixture.number("mass.nominal", "g", 1, 1),
    )
  load(value, "part-0").mass |> should.equal(None)
  check(value, "mount.shared_capacity", "frame").check.reason
  |> should.equal("missing_fact")
  let value =
    thermal_fixture.instance(fixture.tree(3, 1), "part-2", fn(i) {
      a.Instance(
        ..i,
        profile: "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
      )
    })
    |> load_fixture.canonical
  load(value, "part-0").mass |> should.equal(None)
  check(value, "mount.mass", "part-2").check.reason
  |> should.equal("missing_profile")
}

pub fn shared_pattern_alternatives_require_one_common_joint_choice_test() {
  let value =
    fixture.resolved()
    |> fixture.split("part-b")
    |> contract_fixture.fact(
      "frame",
      "out",
      power_fixture.terms("mount.pattern", ["A", "B"]),
    )
    |> contract_fixture.fact(
      "part-a",
      "in",
      power_fixture.terms("mount.pattern", ["A"]),
    )
    |> contract_fixture.fact(
      "part-b",
      "in",
      power_fixture.terms("mount.pattern", ["B"]),
    )
  check(value, "mount.connected.mount.pattern", "frame").check.outcome
  |> should.equal(Incompatible)
  let missing =
    contract_fixture.fact(
      value,
      "part-b",
      "in",
      p.Fact("mount.pattern", [], "token", p.Missing),
    )
  check(missing, "mount.connected.mount.pattern", "frame").check.outcome
  |> should.equal(Unknown)
}

pub fn invalid_endpoints_directions_and_bidirectional_support_are_explicit_test() {
  let value = fixture.resolved()
  let reversed =
    power_fixture.connect(
      value,
      a.Endpoint("part-a", "in"),
      a.Endpoint("frame", "out"),
    )
  check(reversed, "mount.interface", "part-a").check.reason
  |> should.equal("direction_mismatch")
  let missing =
    power_fixture.connect(
      value,
      a.Endpoint("frame", "absent"),
      a.Endpoint("part-a", "in"),
    )
  check(missing, "mount.interface", "part-a").check.reason
  |> should.equal("absent_port")
  let different =
    power_fixture.change(value, "frame", fn(p) { p.Port(..p, kind: "power") })
  check(different, "mount.interface", "part-a").check.reason
  |> should.equal("port_kind_mismatch")
  let bidirectional =
    power_fixture.change(value, "frame", fn(p) {
      p.Port(..p, direction: "bidirectional")
    })
  check(bidirectional, "mount.interface", "part-a").check.outcome
  |> should.equal(Unknown)
}

pub fn maximum_chain_terminates_and_preserves_each_distinct_unit_mass_test() {
  let value =
    fixture.tree(63, 1)
    |> load_fixture.component(
      "part-0",
      load_fixture.number("mass", "g", 100_000, 100_000),
    )
  load(value, "part-0").mass
  |> should.equal(Some(Interval(6_300_000, 6_300_000)))
  check(value, "mount.path", "part-62").check.outcome
  |> should.equal(Compatible)
  let assert Some(mass) =
    check(value, "mount.shared_capacity", "frame").measurement
  mass.required |> should.equal(Some(Interval(6_300_000, 6_300_000)))
}
