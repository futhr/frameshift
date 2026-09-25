import frameshift_build/artifact/model.{type Document, type Tile, Document, Tile}
import gleam/dynamic/decode

pub fn document() -> decode.Decoder(Document) {
  use artifact <- decode.field("artifact", decode.string)
  use controller <- decode.field("controller", decode.string)
  use encoding <- decode.field("encoding", decode.string)
  use firmware <- decode.field("firmware", decode.string)
  use height <- decode.field("height", decode.int)
  use protocol <- decode.field("protocol", decode.string)
  use schema <- decode.field("schema", decode.int)
  use tiles <- decode.field("tiles", decode.list(tile()))
  use width <- decode.field("width", decode.int)
  decode.success(Document(
    artifact:,
    controller:,
    encoding:,
    firmware:,
    height:,
    protocol:,
    schema:,
    tiles:,
    width:,
  ))
}

fn tile() -> decode.Decoder(Tile) {
  use display <- decode.field("display", decode.string)
  use rotation <- decode.field("rotation", decode.int)
  use x <- decode.field("x", decode.int)
  use y <- decode.field("y", decode.int)
  decode.success(Tile(display:, rotation:, x:, y:))
}
