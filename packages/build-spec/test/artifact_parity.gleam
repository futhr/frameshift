import artifact_fixture
import frameshift_build/artifact/model.{Document, Tile}
import frameshift_build/assembly/model as a
import frameshift_build/compiler/artifact_layout.{Layout}
import frameshift_build/compiler/artifacts
import frameshift_build/resolution as r
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/int
import gleam/io
import gleam/json as j
import gleam/list
import gleam/option.{Some}
import load_fixture

pub fn main() {
  int.range(0, 256, Nil, fn(_, seed) {
    let w = seed % 4 + 1
    let h = seed / 4 % 4 + 1
    let rotation = seed / 16 % 4 * 90
    let count = seed / 64 % 4 + 1
    let #(value, layout) = artifact_fixture.tiled(count, w, h)
    let #(rw, rh) = case rotation {
      90 | 270 -> #(h, w)
      _ -> #(w, h)
    }
    let tiles =
      list.index_map(layout.document.tiles, fn(t, n) {
        Tile(..t, rotation:, x: n * { rw + seed % 3 - 1 }, y: seed / 11 % 2)
      })
    let layout =
      Layout(
        ..layout,
        document: Document(
          ..layout.document,
          tiles:,
          width: rw * count + seed / 3 % 2,
          height: rh + seed / 7 % 2,
        ),
      )
    let slots = #(3 + seed % 3, 5 + seed % 3)
    let budget =
      layout.document.width
      * layout.document.height
      * 3
      * slots.1
      + seed
      % 3
      - 1
    let value =
      load_fixture.component(
        value,
        "controller",
        load_fixture.number(
          "storage.retained_artifacts",
          "count",
          slots.0,
          slots.1,
        ),
      )
    let value =
      r.Resolution(
        ..value,
        assembly: a.Assembly(
          ..value.assembly,
          intent: a.Intent(..value.assembly.intent, storage_bytes: budget),
        ),
      )
    let assert Ok(findings) = artifacts.evaluate(value, [layout])
    let selected =
      list.filter(findings, fn(f) {
        list.contains(
          [
            "artifact.tile_width",
            "artifact.tile_height",
            "artifact.coverage",
            "artifact.tile_separation",
            "artifact.payload_limit",
            "artifact.retained_payload",
          ],
          f.check.code,
        )
      })
    j.object([
      #("seed", j.int(seed)),
      #(
        "canvas",
        j.array([layout.document.width, layout.document.height], j.int),
      ),
      #("native", j.array([w, h], j.int)),
      #(
        "tiles",
        j.array(tiles, fn(t) {
          j.object([
            #("id", j.string(t.display)),
            #("rotation", j.int(t.rotation)),
            #("x", j.int(t.x)),
            #("y", j.int(t.y)),
          ])
        }),
      ),
      #("slots", j.array([slots.0, slots.1], j.int)),
      #("budget", j.int(budget)),
      #(
        "actual",
        j.array(selected, fn(f) {
          j.object([
            #("code", j.string(f.check.code)),
            #("instances", j.array(f.check.instances, j.string)),
            #(
              "outcome",
              j.string(case f.check.outcome {
                Compatible -> "compatible"
                Incompatible -> "incompatible"
                Unknown -> "unknown"
              }),
            ),
            #("required", case f.measurement {
              Some(m) ->
                case m.required {
                  Some(i) -> j.array([i.minimum, i.maximum], j.int)
                  _ -> j.null()
                }
              _ -> j.null()
            }),
          ])
        }),
      ),
    ])
    |> j.to_string
    |> io.println
  })
}
