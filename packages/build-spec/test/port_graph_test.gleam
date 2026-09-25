import frameshift_build/assembly/model.{Endpoint}
import frameshift_build/model.{
  DuplicateIdentifier, InvalidCount, InvalidIdentifier, InvalidReference,
} as _
import frameshift_build/port_graph
import gleam/int
import gleam/list
import gleeunit/should

pub fn structured_keys_loops_and_reverse_edges_preserve_distinct_nodes_test() {
  let a = Endpoint("a.b", "c")
  let b = Endpoint("a", "b.c")
  let c = Endpoint("a", "c")
  port_graph.components([a, c, b], [#(a, a), #(b, c), #(c, b)])
  |> should.equal(Ok([[b, c], [a]]))
  port_graph.components([], []) |> should.equal(Ok([]))
}

pub fn malformed_keys_duplicate_nodes_dangling_edges_and_limits_are_refused_test() {
  let a = Endpoint("a", "power")
  port_graph.components([a, a], []) |> should.equal(Error(DuplicateIdentifier))
  port_graph.components([Endpoint("a", "bad:port")], [])
  |> should.equal(Error(InvalidIdentifier))
  port_graph.components([a], [#(a, Endpoint("b", "power"))])
  |> should.equal(Error(InvalidReference))
  let edges = int.range(0, 513, [], fn(acc, _) { [#(a, a), ..acc] })
  port_graph.components([a], edges) |> should.equal(Error(InvalidCount))
  let nodes =
    int.range(0, 577, [], fn(acc, n) {
      [Endpoint("n" <> int.to_string(n), "power"), ..acc]
    })
  port_graph.components(nodes, []) |> should.equal(Error(InvalidCount))
}

pub fn maximum_chain_and_isolated_nodes_terminate_and_order_independently_test() {
  let node = fn(n) { Endpoint("n" <> int.to_string(n), "power") }
  let nodes = int.range(0, 576, [], fn(acc, n) { [node(n), ..acc] })
  let edges =
    int.range(0, 512, [], fn(acc, n) { [#(node(n), node(n + 1)), ..acc] })
  let assert Ok(groups) = port_graph.components(nodes, edges)
  list.length(groups) |> should.equal(64)
  let assert [chain, ..] = groups
  list.length(chain) |> should.equal(513)
  list.length(list.flatten(groups)) |> should.equal(576)
  port_graph.components(list.reverse(nodes), list.reverse(edges))
  |> should.equal(Ok(groups))
}
