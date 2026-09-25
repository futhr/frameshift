import artifact_fixture
import frameshift_build/artifact/model.{type Document, Document, Tile}
import gleam/int

pub fn document(seed: Int) -> Document {
  let #(_, layout) = artifact_fixture.one()
  case seed {
    0 -> layout.document
    _ ->
      Document(
        ..layout.document,
        width: seed + 1,
        height: seed % 16 + 1,
        encoding: case seed % 3 {
          0 -> "future-encoding"
          _ -> "rgb24-srgb-v1"
        },
        tiles: int.range(0, seed % 64 + 1, [], fn(acc, n) {
          [Tile("panel-" <> int.to_string(n), n % 4 * 90, n * 2, seed), ..acc]
        }),
      )
  }
}
