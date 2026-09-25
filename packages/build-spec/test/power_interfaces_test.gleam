import frameshift_build
import frameshift_build/assembly
import frameshift_build/assembly/model as a
import frameshift_build/compiler/finding.{type Finding, Measurement, Within}
import frameshift_build/compiler/model.{ProfileInput}
import frameshift_build/compiler/power_interfaces
import frameshift_build/model as p
import frameshift_build/resolution as r
import frameshift_physical.{Compatible, Incompatible, Interval, Unknown}
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleeunit/should
import power_fixture as fixture
import profile_fixture

fn check(value: r.Resolution, code: String) -> Finding {
  let assert Ok(finding) =
    list.find(power_interfaces.evaluate(value), fn(f) { f.check.code == code })
  finding
}

pub fn paired_declarations_preserve_exact_ports_citations_and_voltage_operands_test() {
  let value = fixture.resolved()
  let findings = power_interfaces.evaluate(value)
  list.length(findings) |> should.equal(7)
  list.all(findings, fn(f) { f.check.outcome == Compatible }) |> should.be_true
  let voltage = check(value, "power.voltage")
  voltage.measurement
  |> should.equal(
    Some(Measurement(
      "mv",
      Within,
      Some(Interval(4750, 5250)),
      Some(Interval(4500, 5500)),
    )),
  )
  let assert Ok(controller) = r.find_instance(value, "controller")
  list.contains(
    voltage.check.inputs,
    ProfileInput("controller", controller.profile, [
      "ports",
      "out",
      "facts",
      "output.voltage",
    ]),
  )
  |> should.be_true
  list.all(voltage.readings, fn(r) { r.sources == [profile_fixture.source()] })
  |> should.be_true
}

pub fn partial_voltage_overlap_is_insufficient_at_either_end_test() {
  let value = fixture.resolved()
  check(
    fixture.set_fact(
      value,
      "controller",
      fixture.number("output.voltage", 4499, 5250),
    ),
    "power.voltage",
  ).check.outcome
  |> should.equal(Incompatible)
  check(
    fixture.set_fact(
      value,
      "controller",
      fixture.number("output.voltage", 4750, 5501),
    ),
    "power.voltage",
  ).check.outcome
  |> should.equal(Incompatible)
  check(
    fixture.set_fact(
      value,
      "controller",
      fixture.number("output.voltage", 4500, 5500),
    ),
    "power.voltage",
  ).check.outcome
  |> should.equal(Compatible)
}

pub fn negative_rail_magnitudes_require_matching_unambiguous_polarity_test() {
  let value =
    fixture.resolved()
    |> fixture.set_fact("controller", fixture.terms("polarity", ["negative"]))
  check(value, "power.polarity").check.outcome |> should.equal(Incompatible)
  check(
    fixture.set_fact(value, "panel", fixture.terms("polarity", ["negative"])),
    "power.polarity",
  ).check.outcome
  |> should.equal(Compatible)
  check(
    fixture.set_fact(value, "panel", fixture.terms("polarity", ["ac"])),
    "power.polarity",
  ).check.reason
  |> should.equal("unsupported_polarity")
  check(
    fixture.set_fact(
      value,
      "panel",
      fixture.terms("polarity", ["negative", "positive"]),
    ),
    "power.polarity",
  ).check.outcome
  |> should.equal(Unknown)
}

pub fn exact_contract_alternatives_cannot_be_replaced_by_generic_family_names_test() {
  let value =
    fixture.resolved()
    |> fixture.set_fact(
      "controller",
      fixture.terms("pinout.contract", ["alternate", "fixture-pinout.contract"]),
    )
  check(value, "power.pinout.contract").check.outcome
  |> should.equal(Compatible)
  let mismatch =
    fixture.set_fact(
      value,
      "panel",
      fixture.terms("pinout.contract", ["different"]),
    )
    |> fixture.set_fact("panel", fixture.terms("interface.family", ["dc"]))
    |> fixture.set_fact("controller", fixture.terms("interface.family", ["dc"]))
  check(mismatch, "power.pinout.contract").check.outcome
  |> should.equal(Incompatible)
  let missing =
    fixture.set_fact(
      mismatch,
      "panel",
      p.Fact("pinout.contract", [], "token", p.Missing),
    )
  check(missing, "power.pinout.contract").check.outcome |> should.equal(Unknown)
}

pub fn missing_conflicting_wrong_unit_and_nominal_voltage_never_substitute_test() {
  let first = profile_fixture.source()
  let value =
    fixture.resolved()
    |> fixture.set_fact(
      "controller",
      p.Fact("output.voltage", [], "mv", p.Missing),
    )
    |> fixture.set_fact(
      "controller",
      fixture.number("output.voltage.nominal", 5000, 5000),
    )
  check(value, "power.voltage").check.reason |> should.equal("missing_fact")
  let wrong =
    fixture.set_fact(
      value,
      "controller",
      p.Fact("output.voltage", [first], "ma", p.KnownRange(4750, 5250)),
    )
  check(wrong, "power.voltage").check.reason |> should.equal("unit_mismatch")
  let conflict =
    fixture.set_fact(
      value,
      "controller",
      p.Fact(
        "output.voltage",
        [first, p.Source(..first, locator: "other")],
        "mv",
        p.Conflicting,
      ),
    )
  let reading = check(conflict, "power.voltage")
  reading.check.reason |> should.equal("conflicting_fact")
  let assert Ok(reading) =
    list.find(reading.readings, fn(r) { r.key == "output.voltage" })
  list.length(reading.sources) |> should.equal(2)
}

pub fn unresolved_absent_kind_direction_and_self_connections_fail_explicitly_test() {
  let value = fixture.resolved()
  let missing = r.Resolution(..value, profiles: [])
  check(missing, "power.interface").check.outcome |> should.equal(Unknown)
  let absent =
    fixture.connect(
      value,
      a.Endpoint("controller", "absent"),
      a.Endpoint("panel", "dc"),
    )
  check(absent, "power.interface").check.reason |> should.equal("absent_port")
  let different =
    fixture.change(value, "panel", fn(port) { p.Port(..port, kind: "signal") })
  check(different, "power.interface").check.reason
  |> should.equal("port_kind_mismatch")
  let reversed =
    fixture.connect(
      value,
      a.Endpoint("panel", "dc"),
      a.Endpoint("controller", "out"),
    )
  check(reversed, "power.interface").check.reason
  |> should.equal("direction_mismatch")
  let self =
    fixture.connect(value, a.Endpoint("panel", "dc"), a.Endpoint("panel", "dc"))
  check(self, "power.interface").check.reason |> should.equal("self_connection")
}

pub fn bidirectional_power_is_unknown_and_known_nonpower_edges_are_outside_scope_test() {
  let value = fixture.resolved()
  list.each(["controller", "panel"], fn(id) {
    let bidirectional =
      fixture.change(value, id, fn(port) {
        p.Port(..port, direction: "bidirectional")
      })
    let finding = check(bidirectional, "power.interface")
    finding.check.outcome |> should.equal(Unknown)
    finding.check.reason |> should.equal("unsupported_bidirectional_power")
  })
  let signal =
    value
    |> fixture.change("controller", fn(port) { p.Port(..port, kind: "signal") })
    |> fixture.change("panel", fn(port) { p.Port(..port, kind: "signal") })
  power_interfaces.evaluate(signal) |> should.equal([])
}

pub fn maximum_canonical_connection_count_produces_all_pair_obligations_test() {
  let value = fixture.resolved()
  let numbers = int.range(0, 16, [], fn(acc, i) { [int.to_string(i), ..acc] })
  let profiles =
    list.map(value.profiles, fn(profile) {
      let assert [port] = profile.profile.ports
      r.ResolvedProfile(
        ..profile,
        profile: p.Profile(
          ..profile.profile,
          ports: list.map(numbers, fn(i) {
            p.Port(..port, id: port.id <> "-" <> i)
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
  let assert Ok(bytes) =
    assembly.encode(a.Assembly(..value.assembly, connections:))
  let profiles =
    list.map(profiles, fn(p) {
      let assert Ok(bytes) = frameshift_build.encode(p.profile)
      #(p.identity, bytes)
    })
  let assert Ok(value) = r.resolve(bytes, profiles)
  let findings = power_interfaces.evaluate(value)
  list.length(findings) |> should.equal(1792)
  list.all(findings, fn(f) { f.check.outcome == Compatible }) |> should.be_true
}
