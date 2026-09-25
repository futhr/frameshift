import frameshift_build/assembly/model as m
import gleam/int
import gleam/list
import gleam/string

// Synthetic graph only; these digests are not manufacturer or catalog evidence.
pub fn assembly(seed: Int) -> m.Assembly {
  let first =
    m.Instance(
      "panel",
      "internal",
      m.Placement(90 * { seed % 4 }, seed, 0, 100),
      "sha256:" <> string.repeat("a", 64),
    )
  let second =
    m.Instance(
      "controller",
      "external",
      m.Placement(0, 0, seed * 10, 0),
      "sha256:" <> string.repeat("b", 64),
    )
  let connections = [
    m.Connection(m.Endpoint("controller", "out"), m.Endpoint("panel", "in")),
  ]
  let dependencies = [m.Dependency("panel", "controller", "controller")]
  m.Assembly(
    class: case seed % 3 {
      0 -> "paper"
      1 -> "photo"
      _ -> "pixel"
    },
    connections: case seed % 2 {
      0 -> connections
      _ -> [
        m.Connection(
          m.Endpoint("panel", "reply"),
          m.Endpoint("controller", "reply"),
        ),
        ..connections
      ]
    },
    dependencies: case seed % 2 {
      0 -> dependencies
      _ -> [m.Dependency("controller", "panel", "display"), ..dependencies]
    },
    instances: [first, second],
    intent: m.Intent(
      m.Range(-1000 - seed, 35_000 + seed),
      "fixture-rgb24",
      600_000 + seed,
      "fixture-v1",
      "wall",
      "fixture-protocol",
      1_000_000 + seed,
    ),
    schema: 1,
    semantics: "frameshift-physical-1",
  )
}

pub fn sequences() -> List(m.Assembly) {
  int.range(0, 256, [], fn(acc, seed) { [assembly(seed), ..acc] })
  |> list.reverse
}
