import contract_fixture as fixture
import frameshift_build/assembly/model as a
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/power_contracts
import frameshift_build/compiler/power_interfaces
import frameshift_build/model as p
import frameshift_build/resolution as r
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/list
import gleeunit/should
import load_fixture
import power_fixture

fn check(value: r.Resolution, key: String) -> Finding {
  let assert Ok(findings) = power_contracts.evaluate(value)
  let assert Ok(finding) =
    list.find(findings, fn(f) { f.check.code == "power.connected." <> key })
  finding
}

pub fn pairwise_fanout_agreement_does_not_imply_one_shared_choice_test() {
  let value = fixture.fanout()
  list.all(power_interfaces.evaluate(value), fn(f) {
    f.check.outcome == Compatible
  })
  |> should.be_true
  let global = check(value, "pinout.contract")
  global.check.outcome |> should.equal(Incompatible)
  global.check.reason |> should.equal("no_common_declared_contract")
  global.common_terms |> should.equal([])
}

pub fn passive_adapters_cannot_switch_reference_or_polarity_mid_rail_test() {
  let value = fixture.adapter()
  list.all(power_interfaces.evaluate(value), fn(f) {
    f.check.outcome == Compatible
  })
  |> should.be_true
  let global = check(value, "reference.contract")
  global.check.outcome |> should.equal(Incompatible)
  list.any(global.readings, fn(r) {
    r.instance == "adapter" && r.key == "power.mode"
  })
  |> should.be_true
  let reversed =
    value
    |> fixture.fact(
      "adapter",
      "out",
      power_fixture.terms("polarity", ["negative"]),
    )
    |> fixture.fact(
      "panel",
      "dc",
      power_fixture.terms("polarity", ["negative"]),
    )
  list.all(power_interfaces.evaluate(reversed), fn(f) {
    f.check.code != "power.polarity" || f.check.outcome == Compatible
  })
  |> should.be_true
  check(reversed, "polarity").check.outcome |> should.equal(Incompatible)
}

pub fn known_conflict_survives_missing_members_but_missing_prevents_agreement_test() {
  let value =
    fixture.adapter()
    |> power_fixture.set_fact(
      "adapter",
      p.Fact("reference.contract", [], "token", p.Missing),
    )
  check(value, "reference.contract").check.outcome |> should.equal(Incompatible)
  let otherwise_agree =
    power_fixture.set_fact(
      value,
      "panel",
      power_fixture.terms("reference.contract", ["A"]),
    )
  check(otherwise_agree, "reference.contract").check.outcome
  |> should.equal(Unknown)
  check(otherwise_agree, "reference.contract").common_terms |> should.equal([])
}

pub fn complete_intersection_is_sorted_and_converter_domains_remain_separate_test() {
  let value =
    fixture.fanout()
    |> power_fixture.set_fact(
      "panel",
      power_fixture.terms("pinout.contract", ["A", "B"]),
    )
    |> power_fixture.set_fact(
      "panel-2",
      power_fixture.terms("pinout.contract", ["A", "B"]),
    )
    |> load_fixture.canonical
  check(value, "pinout.contract").common_terms |> should.equal(["A", "B"])
  let converter =
    fixture.adapter()
    |> load_fixture.component(
      "adapter",
      power_fixture.terms("power.mode", ["converter"]),
    )
  let assert Ok(findings) = power_contracts.evaluate(converter)
  let references =
    list.filter(findings, fn(f) {
      f.check.code == "power.connected.reference.contract"
    })
  list.length(references) |> should.equal(2)
  list.all(references, fn(f) { f.check.outcome == Compatible })
  |> should.be_true
  list.map(references, fn(f) { f.common_terms }) |> should.equal([["A"], ["B"]])
}

pub fn unresolved_ports_and_unsupported_polarity_remain_unknown_test() {
  let value = power_fixture.resolved()
  let assert Ok(panel) = r.find_instance(value, "panel")
  let missing =
    r.Resolution(
      ..value,
      profiles: list.filter(value.profiles, fn(p) {
        p.identity != panel.profile
      }),
    )
  check(missing, "reference.contract").check.outcome |> should.equal(Unknown)
  let ac =
    power_fixture.set_fact(
      value,
      "panel",
      power_fixture.terms("polarity", ["ac"]),
    )
  check(ac, "polarity").check.outcome |> should.equal(Unknown)
  check(ac, "polarity").check.reason |> should.equal("unsupported_polarity")
}

pub fn canonical_permutations_preserve_findings_and_common_alternatives_test() {
  let value = fixture.adapter()
  let reversed =
    r.Resolution(
      ..value,
      profiles: list.reverse(value.profiles),
      assembly: a.Assembly(
        ..value.assembly,
        instances: list.reverse(value.assembly.instances),
        connections: list.reverse(value.assembly.connections),
      ),
    )
  power_contracts.evaluate(load_fixture.canonical(reversed))
  |> should.equal(power_contracts.evaluate(value))
}
