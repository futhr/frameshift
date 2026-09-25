/// Portable sourced signal mappings. Valid bytes do not grant registry admission
/// or establish that their ports exist on a particular resolved physical build.
import frameshift_build/bounds
import frameshift_build/mapping/canonical
import frameshift_build/mapping/model.{type Document} as _
import frameshift_build/mapping/validation
import frameshift_build/mapping/wire
import frameshift_build/model.{type Refusal, InvalidDocument, NonCanonical}
import gleam/json
import gleam/result

pub fn encode(value: Document) -> Result(String, Refusal) {
  use _ <- result.try(validation.document(value))
  let bytes = canonical.document(value)
  use _ <- result.try(bounds.document(bytes))
  Ok(bytes)
}

pub fn decode(bytes: String) -> Result(Document, Refusal) {
  use _ <- result.try(bounds.document(bytes))
  use value <- result.try(
    json.parse(bytes, wire.document()) |> result.replace_error(InvalidDocument),
  )
  use encoded <- result.try(encode(value))
  case encoded == bytes {
    True -> Ok(value)
    False -> Error(NonCanonical)
  }
}

pub fn identity_payload(bytes: String) -> Result(String, Refusal) {
  use _ <- result.try(decode(bytes))
  Ok("frameshift.signal-mapping.v1\n" <> bytes)
}
