import frameshift_build/bounds
import frameshift_build/canonical
import frameshift_build/model.{
  type Fact, type Port, type Profile, type Refusal, type Source, Conflicting,
  InvalidFact, InvalidRange, InvalidSource, KnownRange, KnownTerms, Missing,
  UnsupportedVersion,
}
import frameshift_physical as physical
import gleam/list
import gleam/result
import gleam/string

pub fn profile(profile: Profile) -> Result(Nil, Refusal) {
  use _ <- result.try(case profile.schema {
    1 -> Ok(Nil)
    _ -> Error(UnsupportedVersion)
  })
  use _ <- result.try(list.try_each(
    [
      profile.id, profile.manufacturer, profile.part, profile.part_revision,
      profile.revision,
    ],
    bounds.identifier,
  ))
  use _ <- result.try(bounds.identifiers(profile.classes, 1, 3))
  use _ <- result.try(
    list.try_each(profile.classes, fn(value) {
      bounds.enum(value, ["paper", "photo", "pixel"])
    }),
  )
  use _ <- result.try(bounds.enum(profile.kind, kinds()))
  use _ <- result.try(bounds.identifiers(profile.requires, 0, 12))
  use _ <- result.try(
    list.try_each(profile.requires, fn(value) { bounds.enum(value, kinds()) }),
  )
  use _ <- result.try(facts(profile.facts, 128))
  use _ <- result.try(bounds.count(profile.ports, 0, 32))
  use _ <- result.try(
    bounds.unique(list.map(profile.ports, fn(port) { port.id })),
  )
  list.try_each(profile.ports, port)
}

fn kinds() -> List(String) {
  [
    "display",
    "controller",
    "driver",
    "frame",
    "mat",
    "carrier",
    "mount",
    "power",
    "connector",
    "cable",
    "storage",
    "assembly",
  ]
}

fn port(port: Port) -> Result(Nil, Refusal) {
  use _ <- result.try(bounds.identifier(port.id))
  use _ <- result.try(
    bounds.enum(port.direction, ["source", "sink", "bidirectional"]),
  )
  use _ <- result.try(bounds.enum(port.kind, ["power", "signal", "mechanical"]))
  facts(port.facts, 64)
}

fn facts(facts: List(Fact), maximum: Int) -> Result(Nil, Refusal) {
  use _ <- result.try(bounds.count(facts, 1, maximum))
  use _ <- result.try(bounds.unique(list.map(facts, fn(fact) { fact.key })))
  list.try_each(facts, fact)
}

fn fact(fact: Fact) -> Result(Nil, Refusal) {
  use _ <- result.try(bounds.identifier(fact.key))
  use _ <- result.try(
    bounds.enum(fact.unit, [
      "um", "mv", "ma", "mw", "g", "mc", "byte", "ms", "count", "token",
    ]),
  )
  use _ <- result.try(bounds.count(fact.sources, 0, 8))
  use _ <- result.try(list.try_each(fact.sources, source))
  use _ <- result.try(
    bounds.unique(list.map(fact.sources, canonical.source_key)),
  )
  value(fact)
}

fn value(fact: Fact) -> Result(Nil, Refusal) {
  case fact.value {
    Missing -> bounds.count(fact.sources, 0, 0)
    Conflicting -> bounds.count(fact.sources, 2, 8)
    KnownTerms(terms) -> {
      use _ <- result.try(bounds.enum(fact.unit, ["token"]))
      use _ <- result.try(bounds.count(fact.sources, 1, 8))
      bounds.identifiers(terms, 1, 32)
    }
    KnownRange(low, high) -> {
      use _ <- result.try(bounds.count(fact.sources, 1, 8))
      use limits <- result.try(limits(fact.unit))
      case low >= limits.0 && high <= limits.1 && low <= high {
        True -> Ok(Nil)
        False -> Error(InvalidRange)
      }
    }
  }
}

fn limits(unit: String) -> Result(#(Int, Int), Refusal) {
  case unit {
    "um" -> Ok(#(0, physical.ceiling(physical.Micrometre)))
    "mv" -> Ok(#(0, physical.ceiling(physical.Millivolt)))
    "ma" -> Ok(#(0, physical.ceiling(physical.Milliampere)))
    "mw" -> Ok(#(0, physical.ceiling(physical.Milliwatt)))
    "g" -> Ok(#(0, physical.ceiling(physical.Gram)))
    "mc" -> Ok(#(-100_000, 300_000))
    "byte" -> Ok(#(0, 1_099_511_627_776))
    "ms" -> Ok(#(0, 604_800_000))
    "count" -> Ok(#(0, 1_000_000))
    _ -> Error(InvalidFact)
  }
}

fn source(source: Source) -> Result(Nil, Refusal) {
  use _ <- result.try(
    case
      string.byte_size(source.digest) == 64
      && list.all(string.to_graphemes(source.digest), fn(c) {
        string.contains("0123456789abcdef", c)
      })
    {
      True -> Ok(Nil)
      False -> Error(InvalidSource)
    },
  )
  use _ <- result.try(
    bounds.enum(source.evidence, ["manufacturer", "measurement", "custom"]),
  )
  use _ <- result.try(bounds.identifier(source.locator))
  bounds.identifier(source.revision)
}
