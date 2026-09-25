import frameshift_build/artifact/model.{type Document}
import gleam/json as j
import gleam/list
import gleam/string

// Internal serialization. Public export validates before encoding.
pub fn document(value: Document) -> String {
  j.object([
    #("artifact", j.string(value.artifact)),
    #("controller", j.string(value.controller)),
    #("encoding", j.string(value.encoding)),
    #("firmware", j.string(value.firmware)),
    #("height", j.int(value.height)),
    #("protocol", j.string(value.protocol)),
    #("schema", j.int(value.schema)),
    #(
      "tiles",
      j.array(
        list.sort(value.tiles, fn(a, b) { string.compare(a.display, b.display) }),
        fn(tile) {
          j.object([
            #("display", j.string(tile.display)),
            #("rotation", j.int(tile.rotation)),
            #("x", j.int(tile.x)),
            #("y", j.int(tile.y)),
          ])
        },
      ),
    ),
    #("width", j.int(value.width)),
  ])
  |> j.to_string
  |> string.append("\n")
}
