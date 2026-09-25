import frameshift_build/assembly/validation as identities
import frameshift_build/bounds
import frameshift_build/canonical as profiles
import frameshift_build/mapping/model.{type Document} as _
import frameshift_build/model.{
  type Refusal, InvalidReference, UnsupportedVersion,
}
import frameshift_build/validation as sources
import gleam/list
import gleam/result

pub fn document(value: Document) -> Result(Nil, Refusal) {
  use _ <- result.try(case value.schema {
    1 -> Ok(Nil)
    _ -> Error(UnsupportedVersion)
  })
  use _ <- result.try(identities.identity(value.profile))
  use _ <- result.try(list.try_each(
    [value.artifact, value.firmware, value.protocol],
    bounds.identifier,
  ))
  use _ <- result.try(bounds.count(value.pairs, 1, 256))
  use _ <- result.try(bounds.unique(list.map(value.pairs, fn(p) { p.output })))
  use _ <- result.try(
    list.try_each(value.pairs, fn(pair) {
      use _ <- result.try(bounds.identifier(pair.input))
      use _ <- result.try(bounds.identifier(pair.output))
      case pair.input == pair.output {
        True -> Error(InvalidReference)
        False -> Ok(Nil)
      }
    }),
  )
  use _ <- result.try(bounds.count(value.sources, 1, 8))
  use _ <- result.try(list.try_each(value.sources, sources.source))
  bounds.unique(list.map(value.sources, profiles.source_key))
}
