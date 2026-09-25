import frameshift_build
import frameshift_build/assembly
import frameshift_build/assembly/model as a
import frameshift_build/model as p
import frameshift_build/resolution as r
import geometry_fixture
import gleam/list
import gleam/string

// Synthetic dimensions and source claims only, never admitted hardware.
pub fn fact(key: String, value: Int) -> p.Fact {
  geometry_fixture.fact(key, value, value)
}

pub fn resolved() -> r.Resolution {
  let value = geometry_fixture.resolved(0)
  let assert [frame, panel, _] = value.assembly.instances
  let panel = a.Instance(..panel, placement: a.Placement(0, 10, 10, 10))
  let profiles =
    list.map(value.profiles, fn(resolved) {
      let facts = case resolved.profile.kind {
        "frame" -> [
          fact("inner.width", 120),
          fact("inner.height", 100),
          fact("inner.depth", 40),
          fact("opening.x", 10),
          fact("opening.y", 10),
          fact("opening.width", 100),
          fact("opening.height", 80),
        ]
        _ -> [
          fact("outline.width", 110),
          fact("outline.height", 90),
          fact("outline.depth", 5),
          fact("active.offset.x", 0),
          fact("active.offset.y", 0),
          fact("active.width", 100),
          fact("active.height", 80),
        ]
      }
      r.ResolvedProfile(
        ..resolved,
        profile: p.Profile(..resolved.profile, classes: ["paper"], facts:),
      )
    })
  canonical(
    r.Resolution(
      ..value,
      profiles:,
      assembly: a.Assembly(..value.assembly, instances: [frame, panel]),
    ),
  )
}

pub fn canonical(value: r.Resolution) -> r.Resolution {
  let assert Ok(bytes) = assembly.encode(value.assembly)
  let profiles =
    list.map(value.profiles, fn(profile) {
      let assert Ok(bytes) = frameshift_build.encode(profile.profile)
      #(profile.identity, bytes)
    })
  let assert Ok(value) = r.resolve(bytes, profiles)
  value
}

pub fn set_fact(
  value: r.Resolution,
  kind: String,
  key: String,
  fact: p.Fact,
) -> r.Resolution {
  r.Resolution(
    ..value,
    profiles: list.map(value.profiles, fn(profile) {
      case profile.profile.kind == kind {
        False -> profile
        True ->
          r.ResolvedProfile(
            ..profile,
            profile: p.Profile(..profile.profile, facts: [
              fact,
              ..list.filter(profile.profile.facts, fn(f) { f.key != key })
            ]),
          )
      }
    }),
  )
}

pub fn place(
  value: r.Resolution,
  id: String,
  placement: a.Placement,
) -> r.Resolution {
  r.Resolution(
    ..value,
    assembly: a.Assembly(
      ..value.assembly,
      instances: list.map(value.assembly.instances, fn(instance) {
        case instance.id == id {
          True -> a.Instance(..instance, placement:)
          False -> instance
        }
      }),
    ),
  )
}

pub fn mat(value: r.Resolution, second: Bool) -> r.Resolution {
  let assert Ok(panel) =
    list.find(value.profiles, fn(p) { p.profile.kind == "display" })
  let template = panel.profile
  let #(id, pin, x, y, z, w, h, ox, oy, ow, oh) = case second {
    False -> #("mat-1", "c", 0, 0, 1, 120, 100, 20, 20, 80, 60)
    True -> #("mat-2", "d", 5, 5, 4, 110, 90, 20, 20, 70, 50)
  }
  let pin = "sha256:" <> string.repeat(pin, 64)
  let profile =
    p.Profile(..template, id:, kind: "mat", facts: [
      fact("outline.width", w),
      fact("outline.height", h),
      fact("outline.depth", 2),
      fact("opening.x", ox),
      fact("opening.y", oy),
      fact("opening.width", ow),
      fact("opening.height", oh),
    ])
  r.Resolution(
    ..value,
    profiles: [r.ResolvedProfile(pin, profile), ..value.profiles],
    assembly: a.Assembly(..value.assembly, instances: [
      a.Instance(id, "internal", a.Placement(0, x, y, z), pin),
      ..value.assembly.instances
    ]),
  )
}
