import frameshift_build
import frameshift_build/assembly
import frameshift_build/assembly/model as a
import frameshift_build/model as p
import frameshift_build/resolution as r
import gleam/list
import power_fixture
import profile_fixture

pub fn number(key: String, unit: String, low: Int, high: Int) -> p.Fact {
  p.Fact(key, [profile_fixture.source()], unit, p.KnownRange(low, high))
}

pub fn component(
  value: r.Resolution,
  id: String,
  fact: p.Fact,
) -> r.Resolution {
  let assert Ok(instance) = r.find_instance(value, id)
  r.Resolution(
    ..value,
    profiles: list.map(value.profiles, fn(profile) {
      case profile.identity == instance.profile {
        False -> profile
        True ->
          r.ResolvedProfile(
            ..profile,
            profile: p.Profile(..profile.profile, facts: [
              fact,
              ..list.filter(profile.profile.facts, fn(f) { f.key != fact.key })
            ]),
          )
      }
    }),
  )
}

pub fn resolved() -> r.Resolution {
  power_fixture.resolved()
  |> component("controller", power_fixture.terms("power.mode", ["source"]))
  |> component("panel", power_fixture.terms("power.mode", ["consumer"]))
  |> component(
    "controller",
    number("power.output_capacity", "mw", 10_000, 10_000),
  )
  |> power_fixture.set_fact(
    "controller",
    number("fanout.maximum", "count", 2, 2),
  )
  |> power_fixture.set_fact(
    "controller",
    number("current.capacity", "ma", 2000, 2000),
  )
  |> power_fixture.set_fact(
    "controller",
    number("power.capacity", "mw", 10_000, 10_000),
  )
  |> power_fixture.set_fact(
    "controller",
    number("output.voltage", "mv", 5000, 5000),
  )
  |> power_fixture.set_fact(
    "panel",
    number("current.maximum", "ma", 1000, 1000),
  )
  |> canonical
}

pub fn canonical(value: r.Resolution) -> r.Resolution {
  let assert Ok(bytes) = assembly.encode(value.assembly)
  let profiles =
    list.map(value.profiles, fn(p) {
      let assert Ok(bytes) = frameshift_build.encode(p.profile)
      #(p.identity, bytes)
    })
  let assert Ok(value) = r.resolve(bytes, profiles)
  value
}

pub fn second_load(value: r.Resolution) -> r.Resolution {
  let assert Ok(panel) = r.find_instance(value, "panel")
  let other = a.Instance(..panel, id: "panel-2")
  canonical(
    r.Resolution(
      ..value,
      assembly: a.Assembly(
        ..value.assembly,
        instances: [other, ..value.assembly.instances],
        connections: [
          a.Connection(
            a.Endpoint("controller", "out"),
            a.Endpoint("panel-2", "dc"),
          ),
          ..value.assembly.connections
        ],
      ),
    ),
  )
}

pub fn with_converter() -> r.Resolution {
  let value = resolved()
  let assert Ok(controller) = r.find_instance(value, "controller")
  let assert Ok(profile) = r.find_profile(value, controller.profile)
  let pin =
    "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
  let supply = a.Instance(..controller, id: "psu", profile: pin)
  let source_profile =
    p.Profile(..profile, id: "fixture-psu", kind: "power", requires: [])
  let value =
    r.Resolution(
      ..value,
      profiles: [r.ResolvedProfile(pin, source_profile), ..value.profiles],
      assembly: a.Assembly(
        ..value.assembly,
        instances: [supply, ..value.assembly.instances],
        connections: [
          a.Connection(
            a.Endpoint("psu", "out"),
            a.Endpoint("controller", "supply"),
          ),
          ..value.assembly.connections
        ],
      ),
    )
  let value =
    component(
      value,
      "controller",
      power_fixture.terms("power.mode", ["converter"]),
    )
  let profiles =
    list.map(value.profiles, fn(profile) {
      case profile.identity == controller.profile {
        False -> profile
        True ->
          r.ResolvedProfile(
            ..profile,
            profile: p.Profile(..profile.profile, ports: [
              p.Port(
                "sink",
                [
                  number("current.maximum", "ma", 1000, 1000),
                  number("input.voltage", "mv", 11_000, 13_000),
                ],
                "supply",
                "power",
                True,
              ),
              ..profile.profile.ports
            ]),
          )
      }
    })
  r.Resolution(..value, profiles:)
  |> power_fixture.set_fact(
    "psu",
    number("output.voltage", "mv", 12_000, 12_000),
  )
  |> power_fixture.set_fact("psu", number("current.capacity", "ma", 1000, 1000))
  |> power_fixture.set_fact(
    "psu",
    number("power.capacity", "mw", 12_000, 12_000),
  )
  |> component("psu", number("power.output_capacity", "mw", 12_000, 12_000))
  |> canonical
}
