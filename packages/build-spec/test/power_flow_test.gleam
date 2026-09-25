import contract_fixture
import flow_fixture as fixture
import frameshift_build/assembly/model as a
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{ProfileInput}
import frameshift_build/compiler/power_context as ctx
import frameshift_build/compiler/power_current
import frameshift_build/compiler/power_interfaces
import frameshift_build/compiler/power_loads
import frameshift_build/compiler/power_voltage
import frameshift_build/model as p
import frameshift_build/resolution as r
import frameshift_physical.{Compatible, Incompatible, Interval, Unknown}
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import load_fixture
import power_fixture

fn check(value: r.Resolution, instance: String, code: String) -> Finding {
  let assert Ok(f) =
    list.find(power_loads.evaluate(value), fn(f) {
      f.check.code == code && list.first(f.check.instances) == Ok(instance)
    })
  f
}

fn voltage(value: r.Resolution, id: String) {
  power_voltage.inspect(a.Endpoint(id, "out"), ctx.prepare(value)).trace
}

fn demand(value: r.Resolution, id: String) {
  power_current.demand(a.Endpoint(id, "in"), ctx.prepare(value))
}

pub fn chained_uncertain_drops_preserve_upstream_evidence_and_pair_operands_test() {
  let value = fixture.chain(2)
  voltage(value, "passive-1").value |> should.equal(Some(Interval(4800, 4900)))
  let assert Ok(source) = r.find_instance(value, "controller")
  let readings = voltage(value, "passive-1").readings
  list.any(readings, fn(r) {
    r.instance == "controller" && r.key == "output.voltage"
  })
  |> should.be_true
  let assert Ok(pair) =
    list.find(power_interfaces.evaluate(value), fn(f) {
      f.check.code == "power.voltage"
      && list.contains(f.check.instances, "panel")
    })
  let assert Some(measurement) = pair.measurement
  measurement.required |> should.equal(Some(Interval(4800, 4900)))
  list.contains(
    pair.check.inputs,
    ProfileInput("controller", source.profile, [
      "ports",
      "out",
      "facts",
      "output.voltage",
    ]),
  )
  |> should.be_true
  list.all(power_loads.evaluate(value), fn(f) { f.check.outcome == Compatible })
  |> should.be_true
}

pub fn passive_output_label_cannot_reset_arriving_voltage_or_hide_input_failure_test() {
  let value = fixture.chain(2)
  let output =
    contract_fixture.fact(
      value,
      "passive-0",
      "out",
      power_fixture.number("output.voltage", 5000, 5000),
    )
  voltage(output, "passive-1").value |> should.equal(None)
  check(output, "passive-0", "power.passthrough.output_voltage").check.outcome
  |> should.equal(Incompatible)
  let input =
    contract_fixture.fact(
      value,
      "passive-0",
      "in",
      power_fixture.number("input.voltage", 5001, 6000),
    )
  voltage(input, "passive-1").value |> should.equal(None)
  check(input, "passive-0", "power.passthrough.input_voltage").check.outcome
  |> should.equal(Incompatible)
}

pub fn voltage_drop_requires_evidence_units_and_sufficient_headroom_test() {
  let value = fixture.chain(2)
  let too_large =
    contract_fixture.fact(
      value,
      "passive-0",
      "out",
      power_fixture.number("voltage.drop", 0, 5001),
    )
  check(too_large, "passive-0", "power.voltage_drop").check.outcome
  |> should.equal(Incompatible)
  voltage(too_large, "passive-1").value |> should.equal(None)
  let missing =
    contract_fixture.fact(
      value,
      "passive-0",
      "out",
      p.Fact("voltage.drop", [], "mv", p.Missing),
    )
  voltage(missing, "passive-1").value |> should.equal(None)
  voltage(missing, "passive-1").reason |> should.equal("missing_fact")
  let wrong =
    contract_fixture.fact(
      value,
      "passive-0",
      "out",
      load_fixture.number("voltage.drop", "ma", 1, 1),
    )
  voltage(wrong, "passive-1").reason |> should.equal("unit_mismatch")
  let upstream =
    power_fixture.set_fact(
      value,
      "controller",
      p.Fact("output.voltage", [], "mv", p.Missing),
    )
  voltage(upstream, "passive-1").value |> should.equal(None)
}

pub fn downstream_branches_override_zero_static_draw_and_check_both_input_ratings_test() {
  let value = fixture.chain(2) |> fixture.branches("passive-1", 2)
  demand(value, "passive-0").value |> should.equal(Some(Interval(2000, 2000)))
  let amps =
    contract_fixture.fact(
      value,
      "passive-0",
      "in",
      load_fixture.number("current.capacity", "ma", 1999, 1999),
    )
  check(amps, "passive-0", "power.passthrough.input_current").check.outcome
  |> should.equal(Incompatible)
  let watts =
    contract_fixture.fact(
      value,
      "passive-0",
      "in",
      load_fixture.number("power.capacity", "mw", 9999, 9999),
    )
  check(watts, "passive-0", "power.passthrough.input_power").check.outcome
  |> should.equal(Incompatible)
  let assert Some(output) =
    check(value, "passive-1", "power.output_capacity").measurement
  output.required |> should.equal(Some(Interval(9600, 9800)))
  let missing =
    power_fixture.set_fact(
      value,
      "load-0",
      p.Fact("current.maximum", [], "ma", p.Missing),
    )
  demand(missing, "passive-0").value |> should.equal(None)
  check(missing, "controller", "power.current_capacity").check.outcome
  |> should.equal(Unknown)
}

pub fn unused_passive_output_is_zero_load_but_its_input_is_still_required_test() {
  let value = fixture.chain(1)
  let unloaded =
    r.Resolution(
      ..value,
      assembly: a.Assembly(
        ..value.assembly,
        connections: list.filter(value.assembly.connections, fn(c) {
          c.from.instance != "passive-0"
        }),
      ),
    )
  demand(unloaded, "passive-0").value |> should.equal(Some(Interval(0, 0)))
  let unpowered =
    r.Resolution(
      ..unloaded,
      assembly: a.Assembly(..unloaded.assembly, connections: []),
    )
  demand(unpowered, "passive-0").value |> should.equal(None)
  check(unpowered, "passive-0", "power.feed").check.reason
  |> should.equal("missing_power_feed")
}

pub fn optional_flags_cannot_disable_converter_passive_or_consumer_feeds_test() {
  list.each(
    [
      #(fixture.chain(1), "passive-0"),
      #(load_fixture.with_converter(), "controller"),
    ],
    fn(pair) {
      let value =
        power_fixture.change(pair.0, pair.1, fn(p) {
          p.Port(..p, required: False)
        })
      let value =
        r.Resolution(
          ..value,
          assembly: a.Assembly(
            ..value.assembly,
            connections: list.filter(value.assembly.connections, fn(c) {
              c.to.instance != pair.1
            }),
          ),
        )
      check(value, pair.1, "power.feed").check.reason
      |> should.equal("missing_power_feed")
    },
  )
  let value =
    power_fixture.change(load_fixture.resolved(), "panel", fn(p) {
      p.Port(..p, required: False)
    })
  let value =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, connections: []),
    )
  check(value, "panel", "power.consumer_feed").check.reason
  |> should.equal("missing_power_feed")
}

pub fn multiple_feeds_and_cycles_terminate_without_inventing_flow_test() {
  let value = fixture.chain(2)
  let multi =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, connections: [
        a.Connection(
          a.Endpoint("controller", "out"),
          a.Endpoint("passive-1", "in"),
        ),
        ..value.assembly.connections
      ]),
    )
  demand(multi, "passive-0").value |> should.equal(None)
  voltage(multi, "passive-1").value |> should.equal(None)
  let cyclic =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, connections: [
        a.Connection(
          a.Endpoint("passive-1", "out"),
          a.Endpoint("passive-0", "in"),
        ),
        ..list.filter(value.assembly.connections, fn(c) {
          c.from.instance != "controller"
        })
      ]),
    )
  demand(cyclic, "passive-0").value |> should.equal(None)
  demand(cyclic, "passive-0").reason |> should.equal("power_flow_cycle")
  voltage(cyclic, "passive-1").value |> should.equal(None)
  voltage(cyclic, "passive-1").reason |> should.equal("power_flow_cycle")
}

pub fn maximum_chain_preserves_arithmetic_and_terminates_test() {
  let value =
    fixture.chain(62)
    |> power_fixture.set_fact(
      "controller",
      power_fixture.number("output.voltage", 20_000, 21_000),
    )
  voltage(value, "passive-61").value
  |> should.equal(Some(Interval(13_800, 17_900)))
  demand(value, "passive-0").value |> should.equal(Some(Interval(1000, 1000)))
  // Evaluate the whole bounded graph, including every local rating and budget.
  power_loads.evaluate(value) |> list.length |> should.equal(690)
}

pub fn separate_outputs_and_intermediate_branches_each_contribute_once_test() {
  let value = fixture.chain(2) |> fixture.branches("passive-1", 2)
  let assert Ok(passive) = r.find_instance(value, "passive-0")
  let profiles =
    list.map(value.profiles, fn(profile) {
      case profile.identity == passive.profile {
        False -> profile
        True -> {
          let assert Ok(output) =
            list.find(profile.profile.ports, fn(p) { p.id == "out" })
          r.ResolvedProfile(
            ..profile,
            profile: p.Profile(..profile.profile, ports: [
              p.Port(..output, id: "other"),
              ..profile.profile.ports
            ]),
          )
        }
      }
    })
  let connections =
    list.map(value.assembly.connections, fn(c) {
      case c.to.instance == "load-0" {
        True -> a.Connection(..c, from: a.Endpoint("passive-0", "other"))
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
  demand(value, "passive-0").value |> should.equal(Some(Interval(2000, 2000)))
  demand(value, "passive-1").value |> should.equal(Some(Interval(1000, 1000)))
  let assert Some(power) =
    check(value, "passive-0", "power.shared_capacity").measurement
  power.required |> should.equal(Some(Interval(9800, 9900)))
}
