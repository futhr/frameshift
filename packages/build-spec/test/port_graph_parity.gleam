import frameshift_build/assembly/model.{Endpoint}
import frameshift_build/port_graph
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import graph_fixture

pub fn main() {
  let node = fn(id) { Endpoint(id, "power") }
  int.range(0, 512, Nil, fn(_, mask) {
    let edges =
      graph_fixture.edges(mask) |> list.map(fn(e) { #(node(e.0), node(e.1)) })
    let assert Ok(groups) =
      port_graph.components(list.map(["a", "b", "c"], node), edges)
    json.object([
      #("mask", json.int(mask)),
      #(
        "groups",
        json.array(groups, fn(group) {
          json.array(group, fn(node) { json.string(node.instance) })
        }),
      ),
    ])
    |> json.to_string
    |> io.println
  })
}
