import frameshift_build/model as m
import gleam/int
import gleam/list
import gleam/string

pub fn source() -> m.Source {
  m.Source(string.repeat("a", 64), "custom", "fixture-only", "test-1")
}

// Synthetic facts only. These are never catalog or manufacturer evidence.
pub fn profile(seed: Int) -> m.Profile {
  let class = case seed % 3 {
    0 -> "paper"
    1 -> "photo"
    _ -> "pixel"
  }
  m.Profile(
    classes: [class],
    facts: [
      m.Fact(
        "outline.width",
        [source()],
        "um",
        m.KnownRange(1000 + seed, 1010 + seed),
      ),
      m.Fact("thermal", [], "mc", m.Missing),
    ],
    id: "fixture-" <> int.to_string(seed),
    kind: "display",
    manufacturer: "synthetic",
    part: "test-part",
    part_revision: "R1",
    revision: "1",
    schema: 1,
    ports: [
      m.Port(
        "sink",
        [m.Fact("voltage", [source()], "mv", m.KnownRange(4750, 5250))],
        "dc",
        "power",
        True,
      ),
    ],
    requires: ["controller", "power"],
  )
}

pub fn with_fact(fact: m.Fact) -> m.Profile {
  m.Profile(..profile(0), facts: [fact])
}

pub fn sequences() -> List(m.Profile) {
  int.range(0, 256, [], fn(acc, index) { [profile(index), ..acc] })
  |> list.reverse
}
