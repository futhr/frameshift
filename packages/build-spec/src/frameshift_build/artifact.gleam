/// Portable artifact layouts. These are intended assignments, not artwork,
/// verified device capabilities or runtime qualification.
import frameshift_build/artifact/canonical
import frameshift_build/artifact/model.{type Document}
import frameshift_build/artifact/validation
import frameshift_build/artifact/wire
import frameshift_build/bounds
import frameshift_build/model.{type Refusal, InvalidDocument, NonCanonical} as _
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
  Ok("frameshift.artifact-layout.v1\n" <> bytes)
}
