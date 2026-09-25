import frameshift_build/artifact/model.{type Document}
import frameshift_build/bounds
import frameshift_build/model.{type Refusal, InvalidRange, UnsupportedVersion} as _
import gleam/list
import gleam/result

pub fn document(doc: Document) -> Result(Nil, Refusal) {
  use _ <- result.try(case doc.schema {
    1 -> Ok(Nil)
    _ -> Error(UnsupportedVersion)
  })
  use _ <- result.try(list.try_each(
    [doc.artifact, doc.controller, doc.encoding, doc.firmware, doc.protocol],
    bounds.identifier,
  ))
  use _ <- result.try(integer(doc.width, 1, 32_768))
  use _ <- result.try(integer(doc.height, 1, 32_768))
  use _ <- result.try(bounds.count(doc.tiles, 1, 64))
  use _ <- result.try(bounds.unique(list.map(doc.tiles, fn(t) { t.display })))
  list.try_each(doc.tiles, fn(tile) {
    use _ <- result.try(bounds.identifier(tile.display))
    use _ <- result.try(integer(tile.x, 0, 32_768))
    use _ <- result.try(integer(tile.y, 0, 32_768))
    case list.contains([0, 90, 180, 270], tile.rotation) {
      True -> Ok(Nil)
      False -> Error(InvalidRange)
    }
  })
}

fn integer(value: Int, low: Int, high: Int) -> Result(Nil, Refusal) {
  case value >= low && value <= high {
    True -> Ok(Nil)
    False -> Error(InvalidRange)
  }
}
