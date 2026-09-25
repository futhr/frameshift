import frameshift_build/assembly/model as a
import frameshift_build/model as p
import frameshift_build/resolution as r
import gleam/list
import load_fixture
import power_fixture

pub fn fact(
  value: r.Resolution,
  instance: String,
  port_id: String,
  fact: p.Fact,
) -> r.Resolution {
  power_fixture.change(value, instance, fn(port) {
    case port.id == port_id {
      True ->
        p.Port(..port, facts: [
          fact,
          ..list.filter(port.facts, fn(f) { f.key != fact.key })
        ])
      False -> port
    }
  })
}

pub fn fanout() -> r.Resolution {
  let value = power_fixture.resolved()
  let assert Ok(panel) = r.find_instance(value, "panel")
  let assert Ok(profile) = r.find_profile(value, panel.profile)
  let pin =
    "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
  let second = a.Instance(..panel, id: "panel-2", profile: pin)
  let value =
    r.Resolution(
      ..value,
      profiles: [
        r.ResolvedProfile(pin, p.Profile(..profile, id: "fixture-second")),
        ..value.profiles
      ],
      assembly: a.Assembly(
        ..value.assembly,
        instances: [second, ..value.assembly.instances],
        connections: [
          a.Connection(
            a.Endpoint("controller", "out"),
            a.Endpoint("panel-2", "dc"),
          ),
          ..value.assembly.connections
        ],
      ),
    )
  value
  |> power_fixture.set_fact(
    "controller",
    power_fixture.terms("pinout.contract", ["A", "B"]),
  )
  |> power_fixture.set_fact(
    "panel",
    power_fixture.terms("pinout.contract", ["A"]),
  )
  |> power_fixture.set_fact(
    "panel-2",
    power_fixture.terms("pinout.contract", ["B"]),
  )
  |> load_fixture.canonical
}

pub fn adapter() -> r.Resolution {
  let value = power_fixture.resolved()
  let assert Ok(panel) = r.find_instance(value, "panel")
  let assert Ok(controller) = r.find_instance(value, "controller")
  let assert Ok(consumer) = r.find_profile(value, panel.profile)
  let assert Ok(source) = r.find_profile(value, controller.profile)
  let assert [input] = consumer.ports
  let assert [output] = source.ports
  let pin =
    "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
  let adapter = a.Instance(..controller, id: "adapter", profile: pin)
  let profile =
    p.Profile(
      ..source,
      id: "fixture-adapter",
      kind: "cable",
      requires: [],
      facts: [power_fixture.terms("power.mode", ["passthrough"])],
      ports: [p.Port(..input, id: "in"), output],
    )
  let value =
    r.Resolution(
      ..value,
      profiles: [r.ResolvedProfile(pin, profile), ..value.profiles],
      assembly: a.Assembly(
        ..value.assembly,
        instances: [adapter, ..value.assembly.instances],
        connections: [
          a.Connection(
            a.Endpoint("controller", "out"),
            a.Endpoint("adapter", "in"),
          ),
          a.Connection(a.Endpoint("adapter", "out"), a.Endpoint("panel", "dc")),
        ],
      ),
    )
  value
  |> fact("adapter", "out", power_fixture.number("voltage.drop", 0, 0))
  |> power_fixture.set_fact(
    "controller",
    power_fixture.terms("reference.contract", ["A"]),
  )
  |> power_fixture.set_fact(
    "adapter",
    power_fixture.terms("reference.contract", ["A", "B"]),
  )
  |> power_fixture.set_fact(
    "panel",
    power_fixture.terms("reference.contract", ["B"]),
  )
  |> load_fixture.canonical
}
