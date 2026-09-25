/// Internal pure resolution. Identity/byte pairs must come from the standard
/// hashing adapters; this module cannot authenticate a caller-supplied digest.
import frameshift_build
import frameshift_build/assembly
import frameshift_build/assembly/model as planning
import frameshift_build/bounds
import frameshift_build/model.{
  type Profile, type Refusal, TooLarge, UnreferencedProfile,
}
import gleam/list
import gleam/result
import gleam/string

pub type Resolution {
  Resolution(
    assembly: planning.Assembly,
    profiles: List(ResolvedProfile),
    missing: List(String),
  )
}

pub type ResolvedProfile {
  ResolvedProfile(identity: String, profile: Profile)
}

pub fn find_profile(
  value: Resolution,
  identity: String,
) -> Result(Profile, Nil) {
  use found <- result.try(
    list.find(value.profiles, fn(profile) { profile.identity == identity }),
  )
  Ok(found.profile)
}

pub fn find_instance(
  value: Resolution,
  id: String,
) -> Result(planning.Instance, Nil) {
  list.find(value.assembly.instances, fn(instance) { instance.id == id })
}

/// Shared resource gate runs before standard crypto or native JSON decoding.
pub fn budget(bytes: String, profiles: List(String)) -> Result(Nil, Refusal) {
  use _ <- result.try(bounds.count(profiles, 0, 64))
  remaining([bytes, ..profiles], 4_194_304)
}

fn remaining(documents: List(String), available: Int) -> Result(Nil, Refusal) {
  case documents {
    [] -> Ok(Nil)
    [bytes, ..rest] -> {
      let size = string.byte_size(bytes)
      case size > 262_144 || size > available {
        True -> Error(TooLarge)
        False -> remaining(rest, available - size)
      }
    }
  }
}

pub fn resolve(
  bytes: String,
  verified: List(#(String, String)),
) -> Result(Resolution, Refusal) {
  use _ <- result.try(budget(bytes, list.map(verified, fn(v) { v.1 })))
  use plan <- result.try(assembly.decode(bytes))
  let pins =
    list.map(plan.instances, fn(v) { v.profile })
    |> list.unique
    |> list.sort(string.compare)
  let available = list.map(verified, fn(v) { v.0 })
  use _ <- result.try(bounds.unique(available))
  use _ <- result.try(
    case list.all(available, fn(pin) { list.contains(pins, pin) }) {
      True -> Ok(Nil)
      False -> Error(UnreferencedProfile)
    },
  )
  use profiles <- result.try(
    list.try_map(verified, fn(pair) {
      use profile <- result.try(frameshift_build.decode(pair.1))
      Ok(ResolvedProfile(pair.0, profile))
    }),
  )
  Ok(Resolution(
    plan,
    list.sort(profiles, fn(a, b) { string.compare(a.identity, b.identity) }),
    list.filter(pins, fn(pin) { !list.contains(available, pin) }),
  ))
}
