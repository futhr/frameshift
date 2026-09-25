import frameshift_build/assembly/model as a
import frameshift_build/compiler/finding.{type Finding, AtMost, Measurement}
import frameshift_build/compiler/power_loads
import frameshift_build/model as p
import frameshift_build/resolution as r
import frameshift_physical.{Compatible, Incompatible, Interval, Unknown}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import load_fixture as fixture
import power_fixture

fn check(value: r.Resolution, code: String) -> Finding {
  let assert Ok(finding) =
    list.find(power_loads.evaluate(value), fn(f) { f.check.code == code })
  finding
}

pub fn repeated_profile_instances_each_contribute_to_current_and_power_test() {
  let value = fixture.resolved() |> fixture.second_load
  let current = check(value, "power.current_capacity")
  current.check.outcome |> should.equal(Compatible)
  current.measurement
  |> should.equal(
    Some(Measurement(
      "ma",
      AtMost,
      Some(Interval(2000, 2000)),
      Some(Interval(2000, 2000)),
    )),
  )
  check(value, "power.shared_capacity").measurement
  |> should.equal(
    Some(Measurement(
      "mw",
      AtMost,
      Some(Interval(10_000, 10_000)),
      Some(Interval(10_000, 10_000)),
    )),
  )
  let exceeded =
    power_fixture.set_fact(
      value,
      "controller",
      fixture.number("current.capacity", "ma", 1999, 2000),
    )
  check(exceeded, "power.current_capacity").check.outcome
  |> should.equal(Incompatible)
}

pub fn multiple_rails_must_fit_the_shared_supply_limit_test() {
  let value = fixture.resolved() |> fixture.second_load
  let profiles =
    list.map(value.profiles, fn(profile) {
      case profile.profile.kind {
        "controller" -> {
          let assert [port] = profile.profile.ports
          r.ResolvedProfile(
            ..profile,
            profile: p.Profile(..profile.profile, ports: [
              port,
              p.Port(..port, id: "other"),
            ]),
          )
        }
        _ -> profile
      }
    })
  let connections = [
    a.Connection(a.Endpoint("controller", "out"), a.Endpoint("panel", "dc")),
    a.Connection(a.Endpoint("controller", "other"), a.Endpoint("panel-2", "dc")),
  ]
  let value =
    fixture.canonical(
      r.Resolution(
        ..value,
        profiles:,
        assembly: a.Assembly(..value.assembly, connections:),
      ),
    )
    |> fixture.component(
      "controller",
      fixture.number("power.output_capacity", "mw", 9999, 9999),
    )
  let findings = power_loads.evaluate(value)
  findings
  |> list.filter(fn(f) { f.check.code == "power.output_capacity" })
  |> list.all(fn(f) { f.check.outcome == Compatible })
  |> should.be_true
  check(value, "power.shared_capacity").check.outcome
  |> should.equal(Incompatible)
}

pub fn fractional_milliwatts_round_up_once_after_summing_current_test() {
  let value =
    fixture.resolved()
    |> fixture.second_load
    |> power_fixture.set_fact(
      "controller",
      fixture.number("output.voltage", "mv", 1, 1),
    )
    |> power_fixture.set_fact(
      "panel",
      fixture.number("current.maximum", "ma", 1, 1),
    )
  check(value, "power.output_capacity").measurement
  |> should.equal(
    Some(Measurement(
      "mw",
      AtMost,
      Some(Interval(0, 1)),
      Some(Interval(10_000, 10_000)),
    )),
  )
}

pub fn unknown_target_or_draw_contaminates_the_whole_source_budget_test() {
  let value = fixture.resolved() |> fixture.second_load
  let assert Ok(panel) = r.find_instance(value, "panel")
  let missing =
    r.Resolution(
      ..value,
      profiles: list.filter(value.profiles, fn(p) {
        p.identity != panel.profile
      }),
    )
  check(missing, "power.current_capacity").check.outcome
  |> should.equal(Unknown)
  check(missing, "power.shared_capacity").check.outcome |> should.equal(Unknown)
  let no_draw =
    power_fixture.set_fact(
      value,
      "panel",
      p.Fact("current.maximum", [], "ma", p.Missing),
    )
    |> power_fixture.set_fact(
      "panel",
      fixture.number("current.nominal", "ma", 1, 1),
    )
  check(no_draw, "power.current_capacity").check.reason
  |> should.equal("missing_fact")
  let fanout =
    power_fixture.set_fact(
      no_draw,
      "controller",
      fixture.number("fanout.maximum", "count", 1, 1),
    )
  check(fanout, "power.fanout").check.outcome |> should.equal(Incompatible)
}

pub fn zero_static_draw_cannot_hide_passthrough_or_unknown_modes_test() {
  let value =
    fixture.resolved()
    |> fixture.component(
      "panel",
      power_fixture.terms("power.mode", ["passthrough"]),
    )
    |> power_fixture.set_fact(
      "panel",
      fixture.number("current.maximum", "ma", 0, 0),
    )
  check(value, "power.current_capacity").check.outcome |> should.equal(Unknown)
  let no_mode =
    fixture.component(
      value,
      "panel",
      p.Fact("power.mode", [], "token", p.Missing),
    )
  check(no_mode, "power.current_capacity").check.reason
  |> should.equal("missing_fact")
  let wrong =
    fixture.component(
      value,
      "panel",
      power_fixture.terms("power.mode", ["source"]),
    )
  list.any(power_loads.evaluate(wrong), fn(f) {
    f.check.code == "power.mode" && f.check.outcome == Incompatible
  })
  |> should.be_true
}

pub fn multiple_feeds_do_not_turn_into_independent_known_demand_test() {
  let value = fixture.resolved()
  let assert Ok(source) = r.find_instance(value, "controller")
  let other = a.Instance(..source, id: "source-2")
  let value =
    fixture.canonical(
      r.Resolution(
        ..value,
        assembly: a.Assembly(
          ..value.assembly,
          instances: [other, ..value.assembly.instances],
          connections: [
            a.Connection(
              a.Endpoint("source-2", "out"),
              a.Endpoint("panel", "dc"),
            ),
            ..value.assembly.connections
          ],
        ),
      ),
    )
  check(value, "power.feed").check.reason
  |> should.equal("multiple_power_feeds")
  check(value, "power.current_capacity").check.outcome |> should.equal(Unknown)
}

pub fn source_power_consumption_cannot_replace_its_shared_output_rating_test() {
  let value =
    fixture.resolved()
    |> fixture.component(
      "controller",
      p.Fact("power.output_capacity", [], "mw", p.Missing),
    )
    |> fixture.component(
      "controller",
      fixture.number("power.maximum", "mw", 100_000, 100_000),
    )
  check(value, "power.shared_capacity").check.outcome |> should.equal(Unknown)
  check(value, "power.shared_capacity").measurement
  |> should.equal(
    Some(Measurement("mw", AtMost, Some(Interval(5000, 5000)), None)),
  )
}

pub fn maximum_unique_load_count_preserves_large_intermediates_exactly_test() {
  let value =
    fixture.resolved()
    |> power_fixture.set_fact(
      "controller",
      fixture.number("output.voltage", "mv", 300_000, 300_000),
    )
    |> power_fixture.set_fact(
      "panel",
      fixture.number("current.maximum", "ma", 100_000, 100_000),
    )
    |> power_fixture.set_fact(
      "controller",
      fixture.number("fanout.maximum", "count", 256, 256),
    )
  let assert Ok(panel) = r.find_instance(value, "panel")
  let assert Ok(source) = r.find_instance(value, "controller")
  let profiles =
    list.map(value.profiles, fn(profile) {
      case profile.profile.kind {
        "display" -> {
          let assert [port] = profile.profile.ports
          let ports =
            int.range(0, 32, [], fn(acc, n) {
              [p.Port(..port, id: "in-" <> int.to_string(n)), ..acc]
            })
          r.ResolvedProfile(
            ..profile,
            profile: p.Profile(..profile.profile, ports:),
          )
        }
        _ -> profile
      }
    })
  let panels =
    int.range(0, 8, [], fn(acc, n) {
      [a.Instance(..panel, id: "panel-" <> int.to_string(n)), ..acc]
    })
  let connections =
    list.flat_map(panels, fn(panel) {
      int.range(0, 32, [], fn(acc, n) {
        [
          a.Connection(
            a.Endpoint("controller", "out"),
            a.Endpoint(panel.id, "in-" <> int.to_string(n)),
          ),
          ..acc
        ]
      })
    })
  let value =
    fixture.canonical(
      r.Resolution(
        ..value,
        profiles:,
        assembly: a.Assembly(
          ..value.assembly,
          instances: [source, ..panels],
          connections:,
          dependencies: [],
        ),
      ),
    )
  check(value, "power.current_capacity").measurement
  |> should.equal(
    Some(Measurement(
      "ma",
      AtMost,
      Some(Interval(25_600_000, 25_600_000)),
      Some(Interval(2000, 2000)),
    )),
  )
  check(value, "power.shared_capacity").measurement
  |> should.equal(
    Some(Measurement(
      "mw",
      AtMost,
      Some(Interval(7_680_000_000, 7_680_000_000)),
      Some(Interval(10_000, 10_000)),
    )),
  )
}

pub fn converter_uses_its_declared_full_input_envelope_test() {
  let value = fixture.with_converter()
  let upstream = fn(value) {
    let assert Ok(finding) =
      list.find(power_loads.evaluate(value), fn(f) {
        f.check.code == "power.current_capacity"
        && list.contains(f.check.instances, "psu")
      })
    finding
  }
  upstream(value).measurement
  |> should.equal(
    Some(Measurement(
      "ma",
      AtMost,
      Some(Interval(1000, 1000)),
      Some(Interval(1000, 1000)),
    )),
  )
  let reduced_output_load =
    power_fixture.set_fact(
      value,
      "panel",
      fixture.number("current.maximum", "ma", 1, 1),
    )
  upstream(reduced_output_load).measurement
  |> should.equal(upstream(value).measurement)
  list.all(power_loads.evaluate(value), fn(f) { f.check.outcome == Compatible })
  |> should.be_true
  let missing =
    power_fixture.set_fact(
      value,
      "controller",
      p.Fact("current.maximum", [], "ma", p.Missing),
    )
  upstream(missing).check.outcome |> should.equal(Unknown)
  let malformed =
    fixture.resolved()
    |> fixture.component(
      "controller",
      power_fixture.terms("power.mode", ["converter"]),
    )
  check(malformed, "power.mode").check.reason
  |> should.equal("power_mode_port_mismatch")
}
