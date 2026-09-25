import frameshift_build/assembly/model as a
import frameshift_build/model as p
import frameshift_build/resolution as r
import geometry_fixture
import gleam/int
import gleam/list
import load_fixture
import power_fixture

pub fn port(id: String, direction: String, capacity: Int) -> p.Port {
  p.Port(
    direction,
    [
      load_fixture.number("mount.capacity", "g", capacity, capacity),
      load_fixture.number("fanout.maximum", "count", 64, 64),
      power_fixture.terms("mount.pattern", ["fixture-pattern"]),
      power_fixture.terms("mount.contract", ["fixture-joint"]),
    ],
    id,
    "mechanical",
    False,
  )
}

pub fn resolved() -> r.Resolution {
  let value =
    geometry_fixture.resolved(0)
    |> load_fixture.component(
      "frame",
      power_fixture.terms("mount.mode", ["anchor"]),
    )
    |> load_fixture.component(
      "part-a",
      power_fixture.terms("mount.mode", ["supported"]),
    )
    |> load_fixture.component(
      "frame",
      power_fixture.terms("mount.kind", ["wall"]),
    )
    |> load_fixture.component(
      "frame",
      power_fixture.terms("mount.contract", ["fixture-anchor"]),
    )
    |> load_fixture.component(
      "frame",
      load_fixture.number("mass", "g", 1000, 1100),
    )
    |> load_fixture.component(
      "part-a",
      load_fixture.number("mass", "g", 100, 120),
    )
    |> load_fixture.component(
      "frame",
      load_fixture.number("mount.capacity", "g", 240, 240),
    )
    |> load_fixture.component(
      "part-a",
      load_fixture.number("mount.capacity", "g", 100_000, 100_000),
    )
  let profiles =
    list.map(value.profiles, fn(profile) {
      let ports = case profile.profile.kind {
        "frame" -> [port("out", "source", 240)]
        _ -> [port("in", "sink", 100_000), port("out", "source", 100_000)]
      }
      r.ResolvedProfile(
        ..profile,
        profile: p.Profile(..profile.profile, ports:),
      )
    })
  let connections =
    list.map(["part-a", "part-b"], fn(id) {
      a.Connection(a.Endpoint("frame", "out"), a.Endpoint(id, "in"))
    })
  load_fixture.canonical(
    r.Resolution(
      ..value,
      profiles:,
      assembly: a.Assembly(..value.assembly, connections:),
    ),
  )
}

pub fn tree(count: Int, seed: Int) -> r.Resolution {
  let value = resolved()
  let assert Ok(part) = r.find_instance(value, "part-a")
  let assert Ok(frame) = r.find_instance(value, "frame")
  let instances =
    int.range(0, count, [frame], fn(acc, n) {
      [a.Instance(..part, id: id(n)), ..acc]
    })
  let connections =
    int.range(0, count, [], fn(acc, n) {
      let parent = case n {
        0 -> "frame"
        _ ->
          case seed % 3 {
            0 -> "frame"
            1 -> id(n - 1)
            _ -> id({ seed + n * 3 } % n)
          }
      }
      [a.Connection(a.Endpoint(parent, "out"), a.Endpoint(id(n), "in")), ..acc]
    })
  load_fixture.canonical(
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, instances:, connections:),
    ),
  )
}

pub fn id(n: Int) -> String {
  "part-" <> int.to_string(n)
}

pub fn split(value: r.Resolution, id: String) -> r.Resolution {
  let assert Ok(instance) = r.find_instance(value, id)
  let assert Ok(profile) = r.find_profile(value, instance.profile)
  let pin =
    "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
  load_fixture.canonical(
    r.Resolution(
      ..value,
      profiles: [
        r.ResolvedProfile(pin, p.Profile(..profile, id: "fixture-independent")),
        ..value.profiles
      ],
      assembly: a.Assembly(
        ..value.assembly,
        instances: list.map(value.assembly.instances, fn(i) {
          case i.id == id {
            True -> a.Instance(..i, profile: pin)
            False -> i
          }
        }),
      ),
    ),
  )
}
