import frameshift_build/model.{type Fact, type Port, type Profile, type Source}
import gleam/json
import gleam/list
import gleam/string

// Internal encoding primitives. Public export validates first.
pub fn profile(profile: Profile) -> String {
  json.object([
    #("classes", terms(profile.classes)),
    #("facts", facts(profile.facts)),
    #("id", json.string(profile.id)),
    #("kind", json.string(profile.kind)),
    #("manufacturer", json.string(profile.manufacturer)),
    #("part", json.string(profile.part)),
    #("part_revision", json.string(profile.part_revision)),
    #(
      "ports",
      json.array(
        list.sort(profile.ports, fn(a, b) { string.compare(a.id, b.id) }),
        port,
      ),
    ),
    #("requires", terms(profile.requires)),
    #("revision", json.string(profile.revision)),
    #("schema", json.int(profile.schema)),
  ])
  |> json.to_string
  |> string.append("\n")
}

fn port(port: Port) -> json.Json {
  json.object([
    #("direction", json.string(port.direction)),
    #("facts", facts(port.facts)),
    #("id", json.string(port.id)),
    #("kind", json.string(port.kind)),
    #("required", json.bool(port.required)),
  ])
}

fn facts(facts: List(Fact)) -> json.Json {
  facts
  |> list.sort(fn(a, b) { string.compare(a.key, b.key) })
  |> json.array(fact)
}

fn fact(fact: Fact) -> json.Json {
  json.object([
    #("key", json.string(fact.key)),
    #(
      "sources",
      json.array(
        list.sort(fact.sources, fn(a, b) {
          string.compare(source_key(a), source_key(b))
        }),
        source,
      ),
    ),
    #("unit", json.string(fact.unit)),
    #("value", value(fact.value)),
  ])
}

pub fn source_key(value: Source) -> String {
  source(value) |> json.to_string
}

pub fn source(source: Source) -> json.Json {
  json.object([
    #("digest", json.string(source.digest)),
    #("evidence", json.string(source.evidence)),
    #("locator", json.string(source.locator)),
    #("revision", json.string(source.revision)),
  ])
}

fn value(value: model.Value) -> json.Json {
  case value {
    model.KnownRange(low, high) ->
      json.object([
        #("max", json.int(high)),
        #("min", json.int(low)),
        #("state", json.string("known")),
      ])
    model.KnownTerms(values) ->
      json.object([
        #("state", json.string("known")),
        #("terms", terms(values)),
      ])
    model.Missing -> json.object([#("state", json.string("missing"))])
    model.Conflicting -> json.object([#("state", json.string("conflicting"))])
  }
}

fn terms(values: List(String)) -> json.Json {
  json.array(list.sort(values, string.compare), json.string)
}
