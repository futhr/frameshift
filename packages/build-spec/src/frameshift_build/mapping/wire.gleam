import frameshift_build/mapping/model.{type Document, type Pair, Document, Pair}
import frameshift_build/wire as sources
import gleam/dynamic/decode

pub fn document() -> decode.Decoder(Document) {
  use artifact <- decode.field("artifact", decode.string)
  use firmware <- decode.field("firmware", decode.string)
  use pairs <- decode.field("pairs", decode.list(pair()))
  use profile <- decode.field("profile", decode.string)
  use protocol <- decode.field("protocol", decode.string)
  use schema <- decode.field("schema", decode.int)
  use sources <- decode.field("sources", decode.list(sources.source()))
  decode.success(Document(
    artifact:,
    firmware:,
    pairs:,
    profile:,
    protocol:,
    schema:,
    sources:,
  ))
}

fn pair() -> decode.Decoder(Pair) {
  use input <- decode.field("input", decode.string)
  use output <- decode.field("output", decode.string)
  decode.success(Pair(input, output))
}
