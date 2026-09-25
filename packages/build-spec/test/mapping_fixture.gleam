import frameshift_build/mapping/model.{type Document, Document, Pair}
import frameshift_build/model as p
import gleam/int
import gleam/string
import profile_fixture

pub fn document(seed: Int) -> Document {
  let source = profile_fixture.source()
  Document(
    artifact: "fixture-rgb24",
    firmware: "fixture-fw-" <> int.to_string(seed),
    pairs: int.range(0, seed % 8 + 1, [], fn(acc, n) {
      [Pair("in-" <> int.to_string(n % 2), "out-" <> int.to_string(n)), ..acc]
    }),
    profile: "sha256:" <> string.repeat("a", 64),
    protocol: "fixture-protocol",
    schema: 1,
    sources: case seed % 2 {
      0 -> [source]
      _ -> [p.Source(..source, locator: "other-fixture"), source]
    },
  )
}
