import frameshift_build/artifact/model.{Document, Tile}
import frameshift_build/assembly/model as a
import frameshift_build/compiler/artifact_layout.{type Layout, Layout}
import frameshift_build/model as p
import frameshift_build/resolution as r
import gleam/int
import gleam/list
import load_fixture
import operation_fixture

pub fn one() -> #(r.Resolution, Layout) {
  let value =
    operation_fixture.resolved()
    |> load_fixture.component(
      "panel",
      load_fixture.number("raster.width", "count", 2, 2),
    )
    |> load_fixture.component(
      "panel",
      load_fixture.number("raster.height", "count", 3, 3),
    )
    |> load_fixture.component(
      "controller",
      load_fixture.number("artifact.maximum", "byte", 1_000_000, 1_000_000),
    )
    |> load_fixture.component(
      "controller",
      load_fixture.number("storage.retained_artifacts", "count", 3, 5),
    )
  let intent = value.assembly.intent
  #(
    value,
    Layout(
      "sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
      Document(
        intent.artifact,
        "controller",
        "rgb24-srgb-v1",
        intent.firmware,
        3,
        intent.protocol,
        1,
        [Tile("panel", 0, 0, 0)],
        2,
      ),
    ),
  )
}

pub fn tiled(count: Int, width: Int, height: Int) -> #(r.Resolution, Layout) {
  let #(value, layout) = one()
  let value =
    value
    |> load_fixture.component(
      "panel",
      load_fixture.number("raster.width", "count", width, width),
    )
    |> load_fixture.component(
      "panel",
      load_fixture.number("raster.height", "count", height, height),
    )
  let assert Ok(panel) = r.find_instance(value, "panel")
  let others = list.filter(value.assembly.instances, fn(i) { i.id != "panel" })
  let panels =
    int.range(0, count, [], fn(acc, n) {
      list.append(acc, [a.Instance(..panel, id: "panel-" <> int.to_string(n))])
    })
  let tiles =
    list.index_map(panels, fn(p, index) { Tile(p.id, 0, width * index, 0) })
  #(
    load_fixture.canonical(
      r.Resolution(
        ..value,
        assembly: a.Assembly(
          ..value.assembly,
          instances: list.append(others, panels),
          dependencies: list.map(panels, fn(p) {
            a.Dependency(p.id, "controller", "controller")
          }),
          connections: [],
        ),
      ),
    ),
    Layout(
      ..layout,
      document: Document(
        ..layout.document,
        width: width * count,
        height:,
        tiles:,
      ),
    ),
  )
}

pub fn kind(value: r.Resolution, id: String, kind: String) -> r.Resolution {
  let assert Ok(instance) = r.find_instance(value, id)
  r.Resolution(
    ..value,
    profiles: list.map(value.profiles, fn(profile) {
      case profile.identity == instance.profile {
        True ->
          r.ResolvedProfile(
            ..profile,
            profile: p.Profile(..profile.profile, kind:),
          )
        False -> profile
      }
    }),
  )
}
