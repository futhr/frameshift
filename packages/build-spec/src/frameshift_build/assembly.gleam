/// Bounded immutable assembly structure. The codec preserves incomplete plans;
/// only profile resolution and complete constraints can assess compatibility.
import frameshift_build/assembly/canonical
import frameshift_build/assembly/model.{type Assembly} as _
import frameshift_build/assembly/validation
import frameshift_build/assembly/wire
import frameshift_build/bounds
import frameshift_build/model.{type Refusal, InvalidDocument, NonCanonical}
import gleam/json
import gleam/list
import gleam/result
import gleam/string

pub fn encode(value: Assembly) -> Result(String, Refusal) {
  use _ <- result.try(validation.assembly(value))
  let bytes = canonical.assembly(value)
  use _ <- result.try(bounds.document(bytes))
  Ok(bytes)
}

pub fn decode(bytes: String) -> Result(Assembly, Refusal) {
  use _ <- result.try(bounds.document(bytes))
  use value <- result.try(
    json.parse(bytes, wire.assembly()) |> result.replace_error(InvalidDocument),
  )
  use canonical <- result.try(encode(value))
  case canonical == bytes {
    True -> Ok(value)
    False -> Error(NonCanonical)
  }
}

pub fn identity_payload(bytes: String) -> Result(String, Refusal) {
  use _ <- result.try(decode(bytes))
  Ok("frameshift.build.v1\n" <> bytes)
}

/// Exact unique pins for external resolution, never a latest-version query.
pub fn profile_pins(bytes: String) -> Result(List(String), Refusal) {
  use value <- result.try(decode(bytes))
  value.instances
  |> list.map(fn(v) { v.profile })
  |> list.unique
  |> list.sort(string.compare)
  |> Ok
}
