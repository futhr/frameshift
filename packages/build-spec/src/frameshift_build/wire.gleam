import frameshift_build/model
import gleam/dynamic/decode

pub fn profile() -> decode.Decoder(model.Profile) {
  use classes <- decode.field("classes", decode.list(decode.string))
  use facts <- decode.field("facts", decode.list(fact()))
  use id <- decode.field("id", decode.string)
  use kind <- decode.field("kind", decode.string)
  use manufacturer <- decode.field("manufacturer", decode.string)
  use part <- decode.field("part", decode.string)
  use part_revision <- decode.field("part_revision", decode.string)
  use ports <- decode.field("ports", decode.list(port()))
  use requires <- decode.field("requires", decode.list(decode.string))
  use revision <- decode.field("revision", decode.string)
  use schema <- decode.field("schema", decode.int)
  decode.success(model.Profile(
    classes:,
    facts:,
    id:,
    kind:,
    manufacturer:,
    part:,
    part_revision:,
    ports:,
    requires:,
    revision:,
    schema:,
  ))
}

fn port() -> decode.Decoder(model.Port) {
  use direction <- decode.field("direction", decode.string)
  use facts <- decode.field("facts", decode.list(fact()))
  use id <- decode.field("id", decode.string)
  use kind <- decode.field("kind", decode.string)
  use required <- decode.field("required", decode.bool)
  decode.success(model.Port(direction:, facts:, id:, kind:, required:))
}

fn fact() -> decode.Decoder(model.Fact) {
  use key <- decode.field("key", decode.string)
  use sources <- decode.field("sources", decode.list(source()))
  use unit <- decode.field("unit", decode.string)
  use value <- decode.field("value", value())
  decode.success(model.Fact(key:, sources:, unit:, value:))
}

pub fn source() -> decode.Decoder(model.Source) {
  use digest <- decode.field("digest", decode.string)
  use evidence <- decode.field("evidence", decode.string)
  use locator <- decode.field("locator", decode.string)
  use revision <- decode.field("revision", decode.string)
  decode.success(model.Source(digest:, evidence:, locator:, revision:))
}

fn value() -> decode.Decoder(model.Value) {
  use state <- decode.field("state", decode.string)
  case state {
    "missing" -> decode.success(model.Missing)
    "conflicting" -> decode.success(model.Conflicting)
    "known" -> decode.one_of(range(), [terms()])
    _ -> decode.failure(model.Missing, "fact state")
  }
}

fn range() -> decode.Decoder(model.Value) {
  use low <- decode.field("min", decode.int)
  use high <- decode.field("max", decode.int)
  decode.success(model.KnownRange(low, high))
}

fn terms() -> decode.Decoder(model.Value) {
  use terms <- decode.field("terms", decode.list(decode.string))
  decode.success(model.KnownTerms(terms))
}
