import assembly_fixture
import frameshift_build
import frameshift_build/assembly
import frameshift_build/assembly/model as a
import frameshift_build/model as p
import frameshift_build/resolution as r
import gleam/list
import profile_fixture

// Synthetic millimetre-scale boxes, never manufacturer evidence.
pub fn part_profile() -> p.Profile {
  p.Profile(..profile_fixture.profile(0), ports: [], requires: [], facts: [
    fact("outline.width", 20, 22),
    fact("outline.height", 12, 14),
    fact("outline.depth", 5, 6),
    fact("clearance.left", 1, 2),
    fact("clearance.right", 2, 3),
    fact("clearance.top", 3, 4),
    fact("clearance.bottom", 4, 5),
    fact("clearance.front", 1, 1),
    fact("clearance.back", 2, 2),
  ])
}

pub fn frame_profile() -> p.Profile {
  p.Profile(
    ..profile_fixture.profile(1),
    kind: "frame",
    ports: [],
    requires: [],
    facts: [
      fact("inner.width", 40, 42),
      fact("inner.height", 40, 42),
      fact("inner.depth", 20, 22),
    ],
  )
}

pub fn fact(key: String, low: Int, high: Int) -> p.Fact {
  p.Fact(key, [profile_fixture.source()], "um", p.KnownRange(low, high))
}

pub fn resolved(seed: Int) -> r.Resolution {
  let plan = assembly_fixture.assembly(0)
  let assert [first, second] = plan.instances
  let part =
    a.Instance(
      ..first,
      id: "part-a",
      placement: a.Placement(
        90 * { seed / 512 },
        seed % 32,
        seed / 32 % 16,
        seed % 13,
      ),
    )
  let frame =
    a.Instance(
      ..second,
      id: "frame",
      location: "enclosure",
      placement: a.Placement(0, 0, 0, 0),
    )
  let other =
    a.Instance(..part, id: "part-b", placement: a.Placement(0, 25, 10, 0))
  let assert Ok(bytes) =
    assembly.encode(
      a.Assembly(
        ..plan,
        instances: [part, other, frame],
        connections: [],
        dependencies: [],
      ),
    )
  let assert Ok(body) = frameshift_build.encode(part_profile())
  let assert Ok(cavity) = frameshift_build.encode(frame_profile())
  let assert Ok(value) =
    r.resolve(bytes, [#(part.profile, body), #(frame.profile, cavity)])
  value
}

pub fn replace_part(value: r.Resolution, profile: p.Profile) -> r.Resolution {
  r.Resolution(
    ..value,
    profiles: list.map(value.profiles, fn(found) {
      case found.profile.kind {
        "display" -> r.ResolvedProfile(..found, profile:)
        _ -> found
      }
    }),
  )
}
