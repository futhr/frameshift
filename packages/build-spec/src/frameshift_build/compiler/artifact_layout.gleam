/// Bounded typed layout selection. Identities need independent canonical-byte
/// verification before public use; this stage grants no source authority.
import frameshift_build/artifact/model.{type Document}
import frameshift_build/artifact/validation
import frameshift_build/assembly/validation as identities
import frameshift_build/bounds
import frameshift_build/model.{type Refusal, InvalidReference} as _
import frameshift_build/resolution.{type Resolution}
import gleam/list
import gleam/result

pub type Layout {
  Layout(identity: String, document: Document)
}

pub fn validate(
  layouts: List(Layout),
  value: Resolution,
) -> Result(Nil, Refusal) {
  use _ <- result.try(bounds.count(layouts, 0, 64))
  use _ <- result.try(
    list.try_each(layouts, fn(l) { bounds.count(l.document.tiles, 1, 64) }),
  )
  let tiles = list.flat_map(layouts, fn(l) { l.document.tiles })
  use _ <- result.try(bounds.count(tiles, 0, 64))
  use _ <- result.try(bounds.unique(list.map(layouts, fn(l) { l.identity })))
  use _ <- result.try(
    bounds.unique(list.map(layouts, fn(l) { l.document.controller })),
  )
  use _ <- result.try(bounds.unique(list.map(tiles, fn(t) { t.display })))
  list.try_each(layouts, validate_one(_, value))
}

fn validate_one(layout: Layout, value: Resolution) -> Result(Nil, Refusal) {
  let doc = layout.document
  use _ <- result.try(identities.identity(layout.identity))
  use _ <- result.try(validation.document(doc))
  let intent = value.assembly.intent
  use _ <- result.try(
    case
      doc.artifact == intent.artifact
      && doc.firmware == intent.firmware
      && doc.protocol == intent.protocol
    {
      True -> Ok(Nil)
      False -> Error(InvalidReference)
    },
  )
  use _ <- result.try(reference(doc.controller, value))
  list.try_each(doc.tiles, fn(tile) { reference(tile.display, value) })
}

fn reference(id: String, value: Resolution) -> Result(Nil, Refusal) {
  resolution.find_instance(value, id)
  |> result.map(fn(_) { Nil })
  |> result.replace_error(InvalidReference)
}
