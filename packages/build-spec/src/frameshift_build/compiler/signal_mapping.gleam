/// Internal mapping selection. Structural validation does not authenticate its
/// supplied identity or admit its evidence; the external registry must do both.
import frameshift_build/assembly/validation
import frameshift_build/bounds
import frameshift_build/mapping/model.{type Pair} as _
import frameshift_build/model.{type Refusal, InvalidReference}
import frameshift_build/resolution.{type Resolution}
import gleam/list
import gleam/result

pub type Mapping {
  Mapping(
    identity: String,
    profile: String,
    artifact: String,
    firmware: String,
    protocol: String,
    pairs: List(Pair),
  )
}

pub fn validate(
  mappings: List(Mapping),
  value: Resolution,
) -> Result(Nil, Refusal) {
  use _ <- result.try(bounds.count(mappings, 0, 64))
  use _ <- result.try(bounds.count(
    list.flat_map(mappings, fn(m) { m.pairs }),
    0,
    256,
  ))
  use _ <- result.try(bounds.count(
    list.flat_map(value.assembly.instances, fn(i) {
      list.filter(mappings, fn(m) { m.profile == i.profile })
      |> list.flat_map(fn(m) { m.pairs })
    }),
    0,
    256,
  ))
  use _ <- result.try(bounds.unique(list.map(mappings, fn(m) { m.identity })))
  use _ <- result.try(bounds.unique(list.map(mappings, fn(m) { m.profile })))
  list.try_each(mappings, validate_one(_, value))
}

fn validate_one(mapping: Mapping, value: Resolution) -> Result(Nil, Refusal) {
  use _ <- result.try(validation.identity(mapping.identity))
  use _ <- result.try(validation.identity(mapping.profile))
  use _ <- result.try(list.try_each(
    [mapping.artifact, mapping.firmware, mapping.protocol],
    bounds.identifier,
  ))
  let intent = value.assembly.intent
  use _ <- result.try(require(
    mapping.artifact == intent.artifact
    && mapping.firmware == intent.firmware
    && mapping.protocol == intent.protocol
    && list.any(value.assembly.instances, fn(i) { i.profile == mapping.profile }),
  ))
  use profile <- result.try(
    resolution.find_profile(value, mapping.profile)
    |> result.replace_error(InvalidReference),
  )
  use _ <- result.try(bounds.count(mapping.pairs, 1, 256))
  // Unique outputs also rule out duplicate pairs and implicit stream merging.
  use _ <- result.try(
    bounds.unique(list.map(mapping.pairs, fn(p) { p.output })),
  )
  list.try_each(mapping.pairs, fn(pair) {
    use _ <- result.try(bounds.identifier(pair.input))
    use _ <- result.try(bounds.identifier(pair.output))
    require(
      list.any(profile.ports, fn(p) {
        p.id == pair.input && p.kind == "signal" && p.direction == "sink"
      })
      && list.any(profile.ports, fn(p) {
        p.id == pair.output && p.kind == "signal" && p.direction == "source"
      }),
    )
  })
}

fn require(condition: Bool) -> Result(Nil, Refusal) {
  case condition {
    True -> Ok(Nil)
    False -> Error(InvalidReference)
  }
}
