import frameshift_build/graph
import frameshift_build/model
import gleam/int
import gleam/list
import gleam/string
import gleeunit/should

pub fn cycle_members_exclude_incoming_and_outgoing_tails_test() {
  graph.cyclic_nodes(["tail", "a", "b", "out"], [
    #("tail", "a"),
    #("a", "b"),
    #("b", "a"),
    #("b", "out"),
  ])
  |> should.equal(Ok(["a", "b"]))
  graph.cyclic_nodes(["a", "b"], [#("a", "a"), #("a", "b")])
  |> should.equal(Ok(["a"]))
  graph.cyclic_nodes([], []) |> should.equal(Ok([]))
  graph.cyclic_nodes(["a", "b"], [#("a", "b"), #("a", "b")])
  |> should.equal(Ok([]))
}

pub fn graph_input_limits_and_references_are_checked_test() {
  graph.cyclic_nodes(["a", "a"], [])
  |> should.equal(Error(model.DuplicateIdentifier))
  graph.cyclic_nodes(["a"], [#("a", "b")])
  |> should.equal(Error(model.InvalidReference))
  graph.cyclic_nodes(["a"], list.repeat(#("a", "a"), 257))
  |> should.equal(Error(model.InvalidCount))
  graph.cyclic_nodes(list.repeat("a", 65), [])
  |> should.equal(Error(model.InvalidCount))
}

pub fn maximum_chain_and_ring_terminate_with_exact_members_test() {
  let nodes =
    int.range(0, 64, [], fn(acc, i) { ["n" <> int.to_string(i), ..acc] })
    |> list.reverse
  let edges =
    int.range(0, 63, [], fn(acc, i) {
      [#("n" <> int.to_string(i), "n" <> int.to_string(i + 1)), ..acc]
    })
  graph.cyclic_nodes(nodes, edges) |> should.equal(Ok([]))
  graph.cyclic_nodes(nodes, [#("n63", "n0"), ..edges])
  |> should.equal(Ok(list.sort(nodes, string.compare)))
}
