/// Canonical profile boundary. Validity preserves evidence; it never grants
/// build compatibility or purchasing eligibility.
import frameshift_build/bounds
import frameshift_build/canonical
import frameshift_build/model.{type Profile, type Refusal}
import frameshift_build/validation
import frameshift_build/wire
import gleam/json
import gleam/result
import gleam/string

pub fn encode(profile: Profile) -> Result(String, Refusal) {
  use _ <- result.try(validation.profile(profile))
  let text = canonical.profile(profile)
  use _ <- result.try(bounds.document(text))
  Ok(text)
}

pub fn decode(text: String) -> Result(Profile, Refusal) {
  use _ <- result.try(bounds.document(text))
  use profile <- result.try(
    json.parse(text, wire.profile())
    |> result.replace_error(model.InvalidDocument),
  )
  use canonical <- result.try(encode(profile))
  case canonical == text {
    True -> Ok(profile)
    False -> Error(model.NonCanonical)
  }
}

pub fn identity_payload(text: String) -> Result(String, Refusal) {
  use _ <- result.try(decode(text))
  Ok(string.append("frameshift.profile.v1\n", text))
}

pub fn refusal_code(refusal: Refusal) -> String {
  case refusal {
    model.TooLarge -> "too_large"
    model.TooDeep -> "too_deep"
    model.InvalidDocument -> "invalid_document"
    model.UnsupportedVersion -> "unsupported_version"
    model.InvalidIdentifier -> "invalid_identifier"
    model.InvalidEnum -> "invalid_enum"
    model.InvalidRange -> "invalid_range"
    model.InvalidCount -> "invalid_count"
    model.DuplicateIdentifier -> "duplicate_identifier"
    model.InvalidSource -> "invalid_source"
    model.InvalidFact -> "invalid_fact"
    model.NonCanonical -> "noncanonical"
  }
}
