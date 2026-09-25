import frameshift_build/assembly/model as a
import frameshift_build/model as p
import frameshift_build/resolution as r
import gleam/int
import gleam/list
import load_fixture
import power_fixture

pub fn id(index: Int) -> String {
  "passive-" <> int.to_string(index)
}

pub fn chain(length: Int) -> r.Resolution {
  let value = load_fixture.resolved()
  let assert Ok(controller) = r.find_instance(value, "controller")
  let assert Ok(panel) = r.find_instance(value, "panel")
  let assert Ok(source) = r.find_profile(value, controller.profile)
  let assert Ok(consumer) = r.find_profile(value, panel.profile)
  let assert [output] = source.ports
  let assert [input] = consumer.ports
  let pin =
    "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
  let common = [
    load_fixture.number("current.capacity", "ma", 100_000, 100_000),
    load_fixture.number("power.capacity", "mw", 1_000_000, 1_000_000),
  ]
  let adapter =
    p.Profile(
      ..source,
      id: "fixture-passive",
      kind: "cable",
      requires: [],
      facts: [
        power_fixture.terms("power.mode", ["passthrough"]),
        load_fixture.number("power.output_capacity", "mw", 1_000_000, 1_000_000),
      ],
      ports: [
        p.Port(..input, id: "in", facts: [
          power_fixture.number("input.voltage", 0, 300_000),
          // This zero must never replace propagated downstream current.
          load_fixture.number("current.maximum", "ma", 0, 0),
          ..common
        ]),
        p.Port(..output, facts: [
          power_fixture.number("output.voltage", 0, 300_000),
          power_fixture.number("voltage.drop", 50, 100),
          load_fixture.number("fanout.maximum", "count", 256, 256),
          ..common
        ]),
      ],
    )
  let adapters =
    int.range(0, length, [], fn(acc, i) {
      [a.Instance(..controller, id: id(i), profile: pin), ..acc]
    })
  let connections =
    int.range(0, length, [], fn(acc, i) {
      let from = case i {
        0 -> "controller"
        _ -> id(i - 1)
      }
      [a.Connection(a.Endpoint(from, "out"), a.Endpoint(id(i), "in")), ..acc]
    })
  r.Resolution(
    ..value,
    profiles: [r.ResolvedProfile(pin, adapter), ..value.profiles],
    assembly: a.Assembly(
      ..value.assembly,
      instances: list.append(adapters, value.assembly.instances),
      connections: [
        a.Connection(
          a.Endpoint(id(length - 1), "out"),
          a.Endpoint("panel", "dc"),
        ),
        ..connections
      ],
    ),
  )
  |> load_fixture.canonical
}

pub fn branches(value: r.Resolution, tail: String, count: Int) -> r.Resolution {
  let assert Ok(panel) = r.find_instance(value, "panel")
  let panels =
    int.range(0, count, [], fn(acc, i) {
      [a.Instance(..panel, id: "load-" <> int.to_string(i)), ..acc]
    })
  let connections =
    list.map(panels, fn(p) {
      a.Connection(a.Endpoint(tail, "out"), a.Endpoint(p.id, "dc"))
    })
  r.Resolution(
    ..value,
    assembly: a.Assembly(
      ..value.assembly,
      instances: list.append(
        panels,
        list.filter(value.assembly.instances, fn(i) { i.id != "panel" }),
      ),
      connections: list.append(
        connections,
        list.filter(value.assembly.connections, fn(c) {
          c.to.instance != "panel"
        }),
      ),
      dependencies: [],
    ),
  )
  |> load_fixture.canonical
}
