import frameshift_build/assembly/model as a
import frameshift_build/compiler/finding.{
  type Finding, AtMost, Measurement, Within,
}
import frameshift_build/compiler/model.{BuildInput}
import frameshift_build/compiler/thermal
import frameshift_build/model as p
import frameshift_build/resolution as r
import frameshift_physical.{Compatible, Incompatible, Interval, Unknown}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import load_fixture
import power_fixture
import profile_fixture
import thermal_fixture as fixture

fn check(value: r.Resolution, code: String) -> Finding {
  let assert Ok(f) =
    list.find(thermal.evaluate(value), fn(f) { f.check.code == code })
  f
}

fn operating(value: r.Resolution, id: String) -> Finding {
  let assert Ok(f) =
    list.find(thermal.evaluate(value), fn(f) {
      f.check.code == "thermal.operating" && f.check.instances == [id]
    })
  f
}

pub fn temperatures_and_complete_heat_budget_retain_operands_and_scope_test() {
  let value = fixture.resolved()
  let findings = thermal.evaluate(value)
  list.length(findings) |> should.equal(7)
  list.all(findings, fn(f) { f.check.outcome == Compatible }) |> should.be_true
  operating(value, "part-a").measurement
  |> should.equal(
    Some(Measurement(
      "mc",
      Within,
      Some(Interval(0, 40_000)),
      Some(Interval(-20_000, 40_000)),
    )),
  )
  check(value, "thermal.capacity").measurement
  |> should.equal(
    Some(Measurement(
      "mw",
      AtMost,
      Some(Interval(2000, 2400)),
      Some(Interval(2400, 2600)),
    )),
  )
  check(value, "thermal.scope").common_terms |> should.equal(["fixture-v1"])
  list.contains(
    operating(value, "part-a").check.inputs,
    BuildInput(["instances", "part-a", "placement"]),
  )
  |> should.be_true
  list.all(check(value, "thermal.capacity").readings, fn(r) {
    r.sources == [profile_fixture.source()]
  })
  |> should.be_true
}

pub fn negative_ambient_and_exact_rise_boundaries_cannot_hide_temperature_excess_test() {
  let value = fixture.resolved() |> fixture.ambient(-21_000, 35_000)
  operating(value, "part-a").check.outcome |> should.equal(Compatible)
  operating(value, "frame").check.outcome |> should.equal(Incompatible)
  check(value, "thermal.ambient").check.outcome |> should.equal(Incompatible)
  let low = fixture.ambient(value, -21_001, 35_000)
  operating(low, "part-a").check.outcome |> should.equal(Incompatible)
  let high = fixture.ambient(value, -21_000, 35_001)
  operating(high, "part-a").check.outcome |> should.equal(Incompatible)
}

pub fn missing_wrong_unit_conflicting_and_negative_rise_never_become_zero_test() {
  let value = fixture.resolved()
  let missing =
    value
    |> load_fixture.component(
      "part-a",
      p.Fact("temperature.ambient_rise", [], "mc", p.Missing),
    )
    |> load_fixture.component(
      "part-a",
      load_fixture.number("temperature.ambient_rise.typical", "mc", 0, 0),
    )
  operating(missing, "part-a").check.reason |> should.equal("missing_fact")
  let assert Some(m) = operating(missing, "part-a").measurement
  m.required |> should.equal(None)
  let wrong =
    load_fixture.component(
      value,
      "part-a",
      load_fixture.number("temperature.ambient_rise", "mw", 0, 0),
    )
  operating(wrong, "part-a").check.reason |> should.equal("unit_mismatch")
  let negative =
    load_fixture.component(
      value,
      "part-a",
      load_fixture.number("temperature.ambient_rise", "mc", -1, 0),
    )
  operating(negative, "part-a").check.reason |> should.equal("invalid_value")
  let source = profile_fixture.source()
  let conflict =
    load_fixture.component(
      value,
      "part-a",
      p.Fact(
        "temperature.ambient_rise",
        [source, p.Source(..source, locator: "second")],
        "mc",
        p.Conflicting,
      ),
    )
  operating(conflict, "part-a").check.reason |> should.equal("conflicting_fact")
  let no_operating =
    value
    |> load_fixture.component(
      "part-a",
      p.Fact("temperature.operating", [], "mc", p.Missing),
    )
    |> load_fixture.component(
      "part-a",
      load_fixture.number("temperature.absolute", "mc", -100_000, 300_000),
    )
  operating(no_operating, "part-a").check.outcome |> should.equal(Unknown)
}

pub fn repeated_loads_and_missing_heat_cannot_borrow_electrical_power_test() {
  let value = fixture.resolved()
  let exceeded =
    load_fixture.component(
      value,
      "frame",
      load_fixture.number("thermal.capacity", "mw", 2399, 2600),
    )
  check(exceeded, "thermal.capacity").check.outcome
  |> should.equal(Incompatible)
  let missing =
    value
    |> load_fixture.component(
      "part-a",
      p.Fact("heat.maximum", [], "mw", p.Missing),
    )
    |> load_fixture.component(
      "part-a",
      load_fixture.number("power.maximum", "mw", 1, 1),
    )
  check(missing, "thermal.capacity").check.outcome |> should.equal(Unknown)
  let frame =
    load_fixture.component(
      value,
      "frame",
      p.Fact("heat.maximum", [], "mw", p.Missing),
    )
  check(frame, "thermal.capacity").check.reason |> should.equal("missing_fact")
}

pub fn external_parts_keep_operating_checks_without_enclosure_heat_or_rise_test() {
  let value =
    fixture.resolved()
    |> fixture.instance("part-b", fn(i) {
      a.Instance(..i, location: "external")
    })
  check(value, "thermal.capacity").measurement
  |> should.equal(
    Some(Measurement(
      "mw",
      AtMost,
      Some(Interval(1000, 1200)),
      Some(Interval(2400, 2600)),
    )),
  )
  operating(value, "part-b").measurement
  |> should.equal(
    Some(Measurement(
      "mc",
      Within,
      Some(Interval(-1000, 35_000)),
      Some(Interval(-20_000, 40_000)),
    )),
  )
  list.any(operating(value, "part-b").readings, fn(r) {
    r.key == "temperature.ambient_rise"
  })
  |> should.be_false
}

pub fn known_scope_conflict_dominates_an_unknown_contributor_test() {
  let value =
    fixture.resolved()
    |> load_fixture.component(
      "frame",
      power_fixture.terms("assembly.thermal", ["A"]),
    )
    |> load_fixture.component(
      "part-a",
      power_fixture.terms("assembly.thermal", ["B"]),
    )
    |> fixture.instance("part-b", fn(i) {
      a.Instance(
        ..i,
        profile: "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
      )
    })
    |> load_fixture.canonical
  check(value, "thermal.scope").check.outcome |> should.equal(Incompatible)
  check(value, "thermal.scope").common_terms |> should.equal([])
  check(value, "thermal.capacity").check.reason
  |> should.equal("missing_profile")
  let agree =
    load_fixture.component(
      value,
      "frame",
      power_fixture.terms("assembly.thermal", ["B"]),
    )
  check(agree, "thermal.scope").check.outcome |> should.equal(Unknown)
  check(agree, "thermal.scope").common_terms |> should.equal([])
}

pub fn absent_ambiguous_or_wrong_enclosure_cannot_supply_a_capacity_test() {
  let value = fixture.resolved()
  let absent =
    fixture.instance(value, "frame", fn(i) {
      a.Instance(..i, location: "external")
    })
  check(absent, "thermal.capacity").check.reason
  |> should.equal("missing_enclosure")
  check(absent, "thermal.scope").check.outcome |> should.equal(Unknown)
  let incomplete =
    load_fixture.component(
      absent,
      "part-a",
      p.Fact("heat.maximum", [], "mw", p.Missing),
    )
  check(incomplete, "thermal.capacity").check.reason
  |> should.equal("missing_enclosure")
  let ambiguous =
    fixture.instance(value, "part-a", fn(i) {
      a.Instance(..i, location: "enclosure")
    })
  check(ambiguous, "thermal.capacity").check.reason
  |> should.equal("multiple_enclosures")
  let wrong =
    fixture.instance(value, "frame", fn(i) {
      a.Instance(..i, placement: a.Placement(90, 0, 0, 0))
    })
  check(wrong, "thermal.enclosure").check.outcome |> should.equal(Incompatible)
  let assert Some(capacity) = check(wrong, "thermal.capacity").measurement
  capacity.available |> should.equal(None)
}

pub fn maximum_contributors_and_temperature_intermediates_stay_exact_test() {
  let value =
    fixture.resolved()
    |> fixture.ambient(-100_000, 300_000)
    |> load_fixture.component(
      "part-a",
      load_fixture.number("temperature.ambient_rise", "mc", 300_000, 300_000),
    )
    |> load_fixture.component(
      "part-a",
      load_fixture.number("heat.maximum", "mw", 1_000_000, 1_000_000),
    )
    |> load_fixture.component(
      "frame",
      load_fixture.number("heat.maximum", "mw", 1_000_000, 1_000_000),
    )
  let assert Ok(part) = r.find_instance(value, "part-a")
  let assert Ok(frame) = r.find_instance(value, "frame")
  let instances =
    int.range(0, 63, [frame], fn(acc, n) {
      [a.Instance(..part, id: "part-" <> int.to_string(n)), ..acc]
    })
  let value =
    load_fixture.canonical(
      r.Resolution(..value, assembly: a.Assembly(..value.assembly, instances:)),
    )
  let assert Some(heat) = check(value, "thermal.capacity").measurement
  heat.required |> should.equal(Some(Interval(64_000_000, 64_000_000)))
  let assert Some(temp) = operating(value, "part-0").measurement
  temp.required |> should.equal(Some(Interval(200_000, 600_000)))
  operating(value, "part-0").check.outcome |> should.equal(Incompatible)
  list.length(thermal.evaluate(value)) |> should.equal(68)
}
