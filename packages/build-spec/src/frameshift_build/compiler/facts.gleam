/// Reads exact scoped facts from a validated resolution, retaining all evidence.
/// Unusable observed values are preserved for explanation, never substituted.
import frameshift_build/assembly/model.{type Instance} as _
import frameshift_build/compiler/model.{type Input, ProfileInput}
import frameshift_build/compiler/properties
import frameshift_build/model.{
  type Fact, type Source, type Value, Conflicting, KnownRange, KnownTerms,
  Missing,
} as _
import frameshift_build/resolution.{type Resolution}
import gleam/list
import gleam/result

pub type Status {
  Usable
  MissingProfile
  MissingPort
  MissingFact
  ConflictingFact
  UnsupportedProperty
  UnitMismatch
  InvalidValue
}

pub type Reading {
  Reading(
    instance: String,
    profile: String,
    port: String,
    key: String,
    expected_unit: String,
    actual_unit: String,
    value: Value,
    sources: List(Source),
    status: Status,
  )
}

pub fn component(
  instance: Instance,
  key: String,
  value: Resolution,
) -> Reading {
  let property = properties.lookup(properties.Component, key)
  let base = empty(instance, "", key, property)
  case resolution.find_profile(value, instance.profile) {
    Error(_) -> Reading(..base, status: MissingProfile)
    Ok(profile) -> inspect(base, profile.facts, property)
  }
}

pub fn port(
  instance: Instance,
  id: String,
  key: String,
  value: Resolution,
) -> Reading {
  let base = empty(instance, id, key, Error(Nil))
  case resolution.find_profile(value, instance.profile) {
    Error(_) -> Reading(..base, status: MissingProfile)
    Ok(profile) ->
      case list.find(profile.ports, fn(p) { p.id == id }) {
        Error(_) -> Reading(..base, status: MissingPort)
        Ok(port) -> {
          let property = port_property(port.kind, key)
          inspect(empty(instance, id, key, property), port.facts, property)
        }
      }
  }
}

pub fn input(reading: Reading) -> Input {
  let path = case reading.port {
    "" -> ["facts", reading.key]
    id -> ["ports", id, "facts", reading.key]
  }
  ProfileInput(reading.instance, reading.profile, path)
}

/// Comparison inputs must use these selectors, not the observed display value.
pub fn numeric(reading: Reading) -> Result(#(Int, Int), Status) {
  case reading.status, reading.value {
    Usable, KnownRange(low, high) -> Ok(#(low, high))
    Usable, _ -> Error(InvalidValue)
    status, _ -> Error(status)
  }
}

pub fn terms(reading: Reading) -> Result(List(String), Status) {
  case reading.status, reading.value {
    Usable, KnownTerms(terms) -> Ok(terms)
    Usable, _ -> Error(InvalidValue)
    status, _ -> Error(status)
  }
}

pub fn status_code(status: Status) -> String {
  case status {
    Usable -> "usable"
    MissingProfile -> "missing_profile"
    MissingPort -> "missing_port"
    MissingFact -> "missing_fact"
    ConflictingFact -> "conflicting_fact"
    UnsupportedProperty -> "unsupported_property"
    UnitMismatch -> "unit_mismatch"
    InvalidValue -> "invalid_value"
  }
}

fn port_property(
  kind: String,
  key: String,
) -> Result(properties.Property, Nil) {
  case kind {
    "power" -> properties.lookup(properties.PowerPort, key)
    "signal" -> properties.lookup(properties.SignalPort, key)
    "mechanical" -> properties.lookup(properties.MechanicalPort, key)
    _ -> Error(Nil)
  }
}

fn empty(
  instance: Instance,
  port: String,
  key: String,
  property: Result(properties.Property, Nil),
) -> Reading {
  let unit = property |> result.map(properties.unit) |> result.unwrap("")
  Reading(
    instance.id,
    instance.profile,
    port,
    key,
    unit,
    "",
    Missing,
    [],
    MissingFact,
  )
}

fn inspect(
  base: Reading,
  facts: List(Fact),
  property: Result(properties.Property, Nil),
) -> Reading {
  let observed = case list.find(facts, fn(f) { f.key == base.key }) {
    Error(_) -> base
    Ok(fact) ->
      Reading(
        ..base,
        actual_unit: fact.unit,
        value: fact.value,
        sources: fact.sources,
      )
  }
  Reading(..observed, status: status(observed, property))
}

fn status(
  reading: Reading,
  property: Result(properties.Property, Nil),
) -> Status {
  case property {
    Error(_) -> UnsupportedProperty
    Ok(property) ->
      case reading.value {
        Missing -> MissingFact
        Conflicting -> ConflictingFact
        _ ->
          case reading.actual_unit == properties.unit(property) {
            False -> UnitMismatch
            True -> shape(reading.value, property)
          }
      }
  }
}

fn shape(value: Value, property: properties.Property) -> Status {
  case value, property {
    KnownRange(low, high), properties.Number(_, minimum)
      if low >= minimum && high >= low
    -> Usable
    KnownTerms([_, ..]), properties.Terms -> Usable
    _, _ -> InvalidValue
  }
}
