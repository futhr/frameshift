import frameshift_build/graph
import gleam/int
import gleam/io
import gleam/json
import graph_fixture

pub fn main() {
  int.range(0, 512, Nil, fn(_, mask) {
    let assert Ok(cycles) =
      graph.cyclic_nodes(["a", "b", "c"], graph_fixture.edges(mask))
    json.object([
      #("mask", json.int(mask)),
      #("cycles", json.array(cycles, json.string)),
    ])
    |> json.to_string
    |> io.println
  })
}
