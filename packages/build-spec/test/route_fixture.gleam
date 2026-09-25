import contract_fixture
import frameshift_build/assembly/model as a
import frameshift_build/compiler/signal_mapping.{type Mapping, Mapping}
import frameshift_build/mapping/model.{Pair}
import frameshift_build/model as p
import frameshift_build/resolution as r
import gleam/int
import gleam/list
import load_fixture
import signal_fixture

pub fn adapted() -> r.Resolution {
  contract_fixture.adapter() |> signal_fixture.signals
}

pub fn mapping(value: r.Resolution) -> Mapping {
  let assert Ok(adapter) = r.find_instance(value, "adapter")
  let intent = value.assembly.intent
  Mapping(
    "sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
    adapter.profile,
    intent.artifact,
    intent.firmware,
    intent.protocol,
    [Pair("in", "out")],
  )
}

/// Repeat one profile over distinct physical units; each unit has a local map.
pub fn chain(count: Int) -> r.Resolution {
  let value = adapted()
  let assert Ok(adapter) = r.find_instance(value, "adapter")
  let adapters =
    int.range(0, count, [], fn(acc, n) {
      list.append(acc, [
        a.Instance(..adapter, id: "adapter-" <> int.to_string(n)),
      ])
    })
  let inputs = list.map(adapters, fn(i) { a.Endpoint(i.id, "in") })
  let outputs = list.map(adapters, fn(i) { a.Endpoint(i.id, "out") })
  let connections =
    list.zip(
      [a.Endpoint("controller", "out"), ..outputs],
      list.append(inputs, [a.Endpoint("panel", "dc")]),
    )
    |> list.map(fn(pair) { a.Connection(pair.0, pair.1) })
  load_fixture.canonical(
    r.Resolution(
      ..value,
      assembly: a.Assembly(
        ..value.assembly,
        instances: list.append(
          list.filter(value.assembly.instances, fn(i) { i.id != "adapter" }),
          adapters,
        ),
        connections:,
      ),
    ),
  )
}

/// 256 wire edges visit 255 distinct local pairs, revisiting components through
/// separate ports. The expanded mapping contains 256 pairs across 32 units.
pub fn maximal() -> #(r.Resolution, Mapping) {
  let base = adapted()
  let mapping = mapping(base)
  let value = chain(32)
  let assert Ok(profile) = r.find_profile(value, mapping.profile)
  let assert Ok(input) = list.find(profile.ports, fn(p) { p.id == "in" })
  let assert Ok(output) = list.find(profile.ports, fn(p) { p.id == "out" })
  let pairs =
    int.range(0, 8, [], fn(acc, n) {
      [Pair("in-" <> int.to_string(n), "out-" <> int.to_string(n)), ..acc]
    })
  let ports =
    list.flat_map(pairs, fn(pair) {
      [p.Port(..input, id: pair.input), p.Port(..output, id: pair.output)]
    })
  let stops =
    int.range(0, 255, [], fn(acc, n) {
      list.append(acc, [
        #("adapter-" <> int.to_string(n % 32), int.to_string(n / 32)),
      ])
    })
  let connections =
    list.zip(
      [
        a.Endpoint("controller", "out"),
        ..list.map(stops, fn(s) { a.Endpoint(s.0, "out-" <> s.1) })
      ],
      list.append(list.map(stops, fn(s) { a.Endpoint(s.0, "in-" <> s.1) }), [
        a.Endpoint("panel", "dc"),
      ]),
    )
    |> list.map(fn(pair) { a.Connection(pair.0, pair.1) })
  #(
    load_fixture.canonical(
      r.Resolution(
        ..value,
        profiles: list.map(value.profiles, fn(resolved) {
          case resolved.identity == mapping.profile {
            True ->
              r.ResolvedProfile(
                ..resolved,
                profile: p.Profile(..profile, ports:),
              )
            False -> resolved
          }
        }),
        assembly: a.Assembly(..value.assembly, connections:),
      ),
    ),
    Mapping(..mapping, pairs:),
  )
}
