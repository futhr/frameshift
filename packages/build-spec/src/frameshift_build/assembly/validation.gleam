import frameshift_build/assembly/canonical
import frameshift_build/assembly/model as m
import frameshift_build/bounds
import frameshift_build/model.{
  type Refusal, InvalidIdentity, InvalidRange, InvalidReference,
  UnsupportedSemantics, UnsupportedVersion,
}
import frameshift_build/validation as profiles
import gleam/list
import gleam/result
import gleam/string

pub fn assembly(value: m.Assembly) -> Result(Nil, Refusal) {
  use _ <- result.try(case value.schema {
    1 -> Ok(Nil)
    _ -> Error(UnsupportedVersion)
  })
  use _ <- result.try(case value.semantics {
    "frameshift-physical-1" -> Ok(Nil)
    _ -> Error(UnsupportedSemantics)
  })
  use _ <- result.try(bounds.enum(value.class, ["paper", "photo", "pixel"]))
  use _ <- result.try(bounds.count(value.instances, 1, 64))
  let ids = list.map(value.instances, fn(v) { v.id })
  use _ <- result.try(bounds.unique(ids))
  use _ <- result.try(list.try_each(value.instances, instance))
  use _ <- result.try(bounds.count(value.connections, 0, 256))
  use _ <- result.try(bounds.count(value.dependencies, 0, 256))
  use _ <- result.try(
    bounds.unique(list.map(value.connections, canonical.connection_key)),
  )
  use _ <- result.try(
    bounds.unique(list.map(value.dependencies, canonical.dependency_key)),
  )
  use _ <- result.try(list.try_each(value.connections, connection(_, ids)))
  use _ <- result.try(list.try_each(value.dependencies, dependency(_, ids)))
  intent(value.intent)
}

fn instance(value: m.Instance) -> Result(Nil, Refusal) {
  use _ <- result.try(bounds.identifier(value.id))
  use _ <- result.try(
    bounds.enum(value.location, ["enclosure", "internal", "external"]),
  )
  use _ <- result.try(identity(value.profile))
  placement(value.placement)
}

fn identity(value: String) -> Result(Nil, Refusal) {
  case value {
    "sha256:" <> digest -> {
      case
        string.byte_size(digest) == 64
        && list.all(string.to_graphemes(digest), fn(c) {
          string.contains("0123456789abcdef", c)
        })
      {
        True -> Ok(Nil)
        False -> Error(InvalidIdentity)
      }
    }
    _ -> Error(InvalidIdentity)
  }
}

fn placement(value: m.Placement) -> Result(Nil, Refusal) {
  use _ <- result.try(case list.contains([0, 90, 180, 270], value.rotation) {
    True -> Ok(Nil)
    False -> Error(InvalidRange)
  })
  list.try_each([value.x_um, value.y_um, value.z_um], integer(_, 0, 5_000_000))
}

fn connection(value: m.Connection, ids: List(String)) -> Result(Nil, Refusal) {
  use _ <- result.try(endpoint(value.from, ids))
  endpoint(value.to, ids)
}

fn endpoint(value: m.Endpoint, ids: List(String)) -> Result(Nil, Refusal) {
  use _ <- result.try(reference(value.instance, ids))
  bounds.identifier(value.port)
}

fn dependency(value: m.Dependency, ids: List(String)) -> Result(Nil, Refusal) {
  use _ <- result.try(reference(value.consumer, ids))
  use _ <- result.try(reference(value.provider, ids))
  bounds.enum(value.role, profiles.kinds())
}

fn reference(value: String, ids: List(String)) -> Result(Nil, Refusal) {
  case list.contains(ids, value) {
    True -> Ok(Nil)
    False -> Error(InvalidReference)
  }
}

fn intent(value: m.Intent) -> Result(Nil, Refusal) {
  use _ <- result.try(list.try_each(
    [value.artifact, value.firmware, value.protocol],
    bounds.identifier,
  ))
  use _ <- result.try(bounds.enum(value.mounting, ["wall", "stand"]))
  use _ <- result.try(integer(value.dwell_ms, 1, 604_800_000))
  use _ <- result.try(integer(value.storage_bytes, 1, 1_099_511_627_776))
  use _ <- result.try(integer(value.ambient_mc.minimum, -100_000, 300_000))
  integer(value.ambient_mc.maximum, value.ambient_mc.minimum, 300_000)
}

fn integer(value: Int, min: Int, max: Int) -> Result(Nil, Refusal) {
  case value >= min && value <= max {
    True -> Ok(Nil)
    False -> Error(InvalidRange)
  }
}
