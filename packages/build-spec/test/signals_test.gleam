import contract_fixture
import frameshift_build/assembly/model as a
import frameshift_build/compiler/finding.{type Finding, Measurement, Within}
import frameshift_build/compiler/signals
import frameshift_build/model as p
import frameshift_build/resolution as r
import frameshift_physical.{Compatible, Incompatible, Interval, Unknown}
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleeunit/should
import load_fixture
import power_fixture
import profile_fixture
import signal_fixture as fixture

fn checks(value: r.Resolution) -> List(Finding) {
  let assert Ok(findings) = signals.evaluate(value)
  findings
}

fn check(value: r.Resolution, code: String) -> Finding {
  let assert Ok(f) = list.find(checks(value), fn(f) { f.check.code == code })
  f
}

pub fn sourced_signal_envelopes_and_all_connected_contracts_agree_test() {
  let value = fixture.resolved()
  list.length(checks(value)) |> should.equal(9)
  list.all(checks(value), fn(f) { f.check.outcome == Compatible })
  |> should.be_true
  check(value, "signal.voltage").measurement
  |> should.equal(
    Some(Measurement(
      "mv",
      Within,
      Some(Interval(2700, 3300)),
      Some(Interval(2500, 3600)),
    )),
  )
  list.all(check(value, "signal.voltage").readings, fn(r) {
    r.sources == [profile_fixture.source()]
  })
  |> should.be_true
  check(value, "signal.connected.driver.contract").common_terms
  |> should.equal(["fixture-driver"])
}

pub fn voltage_requires_the_whole_source_envelope_within_the_sink_test() {
  let value = fixture.resolved()
  list.each([#(2499, 3300), #(2700, 3601)], fn(range) {
    let value =
      power_fixture.set_fact(
        value,
        "controller",
        power_fixture.number("logic.voltage", range.0, range.1),
      )
    check(value, "signal.voltage").check.outcome |> should.equal(Incompatible)
  })
  let exact =
    power_fixture.set_fact(
      value,
      "controller",
      power_fixture.number("logic.voltage", 2500, 3600),
    )
  check(exact, "signal.voltage").check.outcome |> should.equal(Compatible)
}

pub fn missing_conflicting_and_wrong_unit_voltage_never_borrows_nominal_test() {
  let value =
    fixture.resolved()
    |> power_fixture.set_fact(
      "controller",
      p.Fact("logic.voltage", [], "mv", p.Missing),
    )
    |> power_fixture.set_fact(
      "controller",
      power_fixture.number("logic.voltage.nominal", 3000, 3000),
    )
  check(value, "signal.voltage").check.reason |> should.equal("missing_fact")
  let wrong =
    power_fixture.set_fact(
      value,
      "controller",
      load_fixture.number("logic.voltage", "ma", 1, 1),
    )
  check(wrong, "signal.voltage").check.reason |> should.equal("unit_mismatch")
  let source = profile_fixture.source()
  let conflict =
    power_fixture.set_fact(
      value,
      "controller",
      p.Fact(
        "logic.voltage",
        [source, p.Source(..source, locator: "other")],
        "mv",
        p.Conflicting,
      ),
    )
  check(conflict, "signal.voltage").check.reason
  |> should.equal("conflicting_fact")
}

pub fn unsupported_polarity_and_missing_driver_cannot_pass_by_family_name_test() {
  let value = fixture.resolved()
  list.each([["negative"], ["ac"], ["negative", "positive"]], fn(terms) {
    let changed =
      power_fixture.set_fact(
        value,
        "controller",
        power_fixture.terms("polarity", terms),
      )
    check(changed, "signal.connected.polarity").check.reason
    |> should.equal("unsupported_signal_polarity")
  })
  let driver =
    value
    |> power_fixture.set_fact(
      "panel",
      p.Fact("driver.contract", [], "token", p.Missing),
    )
    |> power_fixture.set_fact(
      "panel",
      power_fixture.terms("interface.family", ["fixture-driver"]),
    )
  check(driver, "signal.connected.driver.contract").check.outcome
  |> should.equal(Unknown)
  let mismatch =
    power_fixture.set_fact(
      value,
      "panel",
      power_fixture.terms("reference.contract", ["different-reference"]),
    )
  check(mismatch, "signal.connected.reference.contract").check.outcome
  |> should.equal(Incompatible)
}

pub fn connected_alternatives_catch_global_conflict_with_unknown_members_test() {
  let value = fixture.signals(contract_fixture.fanout())
  check(value, "signal.connected.pinout.contract").check.outcome
  |> should.equal(Incompatible)
  let missing =
    power_fixture.set_fact(
      value,
      "controller",
      p.Fact("pinout.contract", [], "token", p.Missing),
    )
  check(missing, "signal.connected.pinout.contract").check.outcome
  |> should.equal(Incompatible)
  let incomplete =
    power_fixture.set_fact(
      value,
      "panel",
      p.Fact("pinout.contract", [], "token", p.Missing),
    )
  check(incomplete, "signal.connected.pinout.contract").check.outcome
  |> should.equal(Unknown)
  check(incomplete, "signal.connected.pinout.contract").common_terms
  |> should.equal([])
}

pub fn invalid_unknown_and_bidirectional_endpoints_preserve_their_scope_test() {
  let value = fixture.resolved()
  let reversed =
    power_fixture.connect(
      value,
      a.Endpoint("panel", "dc"),
      a.Endpoint("controller", "out"),
    )
  check(reversed, "signal.interface").check.reason
  |> should.equal("direction_mismatch")
  let missing =
    power_fixture.connect(
      value,
      a.Endpoint("controller", "absent"),
      a.Endpoint("panel", "dc"),
    )
  check(missing, "signal.interface").check.reason |> should.equal("absent_port")
  let unresolved = r.Resolution(..value, profiles: [])
  check(unresolved, "signal.interface").check.outcome |> should.equal(Unknown)
  let other =
    power_fixture.change(value, "panel", fn(p) { p.Port(..p, kind: "power") })
  check(other, "signal.interface").check.reason
  |> should.equal("port_kind_mismatch")
  let both =
    power_fixture.change(other, "controller", fn(p) {
      p.Port(..p, kind: "power")
    })
  checks(both) |> should.equal([])
  let bidirectional =
    power_fixture.change(value, "panel", fn(p) {
      p.Port(..p, direction: "bidirectional")
    })
  check(bidirectional, "signal.interface").check.reason
  |> should.equal("unsupported_bidirectional_signal")
  let self =
    power_fixture.connect(
      value,
      a.Endpoint("controller", "out"),
      a.Endpoint("controller", "out"),
    )
  check(self, "signal.interface").check.reason
  |> should.equal("self_connection")
}

pub fn maximum_connection_count_checks_every_edge_and_the_whole_group_test() {
  let value = fixture.resolved()
  let numbers = int.range(0, 16, [], fn(acc, n) { [int.to_string(n), ..acc] })
  let profiles =
    list.map(value.profiles, fn(profile) {
      let assert [port] = profile.profile.ports
      r.ResolvedProfile(
        ..profile,
        profile: p.Profile(
          ..profile.profile,
          ports: list.map(numbers, fn(n) {
            p.Port(..port, id: port.id <> "-" <> n)
          }),
        ),
      )
    })
  let connections =
    list.flat_map(numbers, fn(i) {
      list.map(numbers, fn(j) {
        a.Connection(
          a.Endpoint("controller", "out-" <> i),
          a.Endpoint("panel", "dc-" <> j),
        )
      })
    })
  let value =
    load_fixture.canonical(
      r.Resolution(
        ..value,
        profiles:,
        assembly: a.Assembly(..value.assembly, connections:),
      ),
    )
  let findings = checks(value)
  list.length(findings) |> should.equal(519)
  list.all(findings, fn(f) { f.check.outcome == Compatible }) |> should.be_true
}
