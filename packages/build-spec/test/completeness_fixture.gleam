import frameshift_build/assembly/model as a
import frameshift_build/model as p
import frameshift_build/resolution as r
import gleam/list
import load_fixture
import power_fixture

pub fn resolved() -> r.Resolution {
  let value = load_fixture.with_converter()
  let value =
    list.fold(value.assembly.instances, value, fn(value, i) {
      list.fold(["width", "height", "depth"], value, fn(value, axis) {
        load_fixture.component(
          value,
          i.id,
          load_fixture.number("outline." <> axis, "um", 1000, 1100),
        )
      })
    })
  let profiles =
    list.map(value.profiles, fn(profile) {
      let extra = case profile.profile.kind {
        "controller" -> [
          p.Port(
            "source",
            [power_fixture.number("logic.voltage", 0, 3300)],
            "data",
            "signal",
            False,
          ),
        ]
        "display" -> [
          p.Port(
            "sink",
            [power_fixture.number("logic.voltage", 0, 3600)],
            "data",
            "signal",
            False,
          ),
        ]
        _ -> []
      }
      r.ResolvedProfile(
        ..profile,
        profile: p.Profile(
          ..profile.profile,
          requires: [],
          ports: list.append(
            extra,
            list.map(profile.profile.ports, fn(p) {
              p.Port(..p, required: False)
            }),
          ),
        ),
      )
    })
  r.Resolution(
    ..value,
    profiles:,
    assembly: a.Assembly(..value.assembly, connections: [
      a.Connection(
        a.Endpoint("controller", "data"),
        a.Endpoint("panel", "data"),
      ),
      ..value.assembly.connections
    ]),
  )
  |> load_fixture.component(
    "panel",
    load_fixture.number("raster.width", "count", 1024, 1024),
  )
  |> load_fixture.component(
    "panel",
    load_fixture.number("raster.height", "count", 768, 768),
  )
  |> load_fixture.canonical
}

pub fn frame(value: r.Resolution) -> r.Resolution {
  let assert Ok(psu) = r.find_instance(value, "psu")
  let assert Ok(profile) = r.find_profile(value, psu.profile)
  let pin =
    "sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
  let frame =
    a.Instance(
      id: "frame",
      profile: pin,
      location: "enclosure",
      placement: a.Placement(0, 0, 0, 0),
    )
  let facts =
    list.flat_map(["width", "height", "depth"], fn(axis) {
      [
        load_fixture.number("outline." <> axis, "um", 2000, 2200),
        load_fixture.number("inner." <> axis, "um", 1500, 1900),
      ]
    })
  load_fixture.canonical(
    r.Resolution(
      ..value,
      profiles: [
        r.ResolvedProfile(
          pin,
          p.Profile(
            ..profile,
            id: "fixture-frame",
            kind: "frame",
            facts:,
            ports: [],
            requires: [],
          ),
        ),
        ..value.profiles
      ],
      assembly: a.Assembly(..value.assembly, instances: [
        frame,
        ..value.assembly.instances
      ]),
    ),
  )
}
