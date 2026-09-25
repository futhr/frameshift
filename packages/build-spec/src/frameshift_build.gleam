/// Canonical profile boundary. Validity preserves evidence; it never grants
/// build compatibility or purchasing eligibility.
import frameshift_build/bounds
import frameshift_build/canonical
import frameshift_build/model.{type Profile, type Refusal}
import frameshift_build/validation
import frameshift_build/wire
import gleam/json
import gleam/list
import gleam/result
import gleam/string

pub type Inspection {
  Inspection(
    identity_payload: String,
    id: String,
    revision: String,
    kind: String,
    classes: List(String),
    citations: List(Citation),
  )
}

pub type Citation {
  Citation(port_id: String, fact_key: String, source: model.Source)
}

/// Public boundary projection. Separate port and fact keys prevent ambiguous
/// dotted paths when either identifier itself contains a dot.
pub fn inspect_profile(text: String) -> Result(Inspection, Refusal) {
  use profile <- result.try(decode(text))
  let citations =
    list.append(
      fact_citations("", profile.facts),
      list.flat_map(profile.ports, fn(port) {
        fact_citations(port.id, port.facts)
      }),
    )
  Ok(Inspection(
    "frameshift.profile.v1\n" <> text,
    profile.id,
    profile.revision,
    profile.kind,
    profile.classes,
    citations,
  ))
}

fn fact_citations(port_id: String, facts: List(model.Fact)) -> List(Citation) {
  list.flat_map(facts, fn(fact) {
    list.map(fact.sources, fn(source) { Citation(port_id, fact.key, source) })
  })
}

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
    model.InvalidIdentity -> "invalid_identity"
    model.InvalidReference -> "invalid_reference"
    model.UnsupportedSemantics -> "unsupported_semantics"
    model.UnreferencedProfile -> "unreferenced_profile"
  }
}
