/// Bounded cycle membership. Parallel semantic edges do not multiply traversal.
import frameshift_build/bounds
import frameshift_build/model.{type Refusal, InvalidReference}
import gleam/list
import gleam/result
import gleam/string

pub fn cyclic_nodes(
  nodes: List(String),
  edges: List(#(String, String)),
) -> Result(List(String), Refusal) {
  use _ <- result.try(bounds.identifiers(nodes, 0, 64))
  use _ <- result.try(bounds.count(edges, 0, 256))
  use _ <- result.try(
    case
      list.all(edges, fn(edge) {
        list.contains(nodes, edge.0) && list.contains(nodes, edge.1)
      })
    {
      True -> Ok(Nil)
      False -> Error(InvalidReference)
    },
  )
  let edges = list.unique(edges)
  nodes
  |> list.filter(fn(node) { reaches(node, neighbors(node, edges), [], edges) })
  |> list.sort(string.compare)
  |> Ok
}

fn neighbors(node: String, edges: List(#(String, String))) -> List(String) {
  edges
  |> list.filter(fn(edge) { edge.0 == node })
  |> list.map(fn(edge) { edge.1 })
}

fn reaches(
  target: String,
  pending: List(String),
  seen: List(String),
  edges: List(#(String, String)),
) -> Bool {
  case pending {
    [] -> False
    [node, ..] if node == target -> True
    [node, ..rest] -> {
      case list.contains(seen, node) {
        True -> reaches(target, rest, seen, edges)
        False ->
          reaches(
            target,
            list.append(neighbors(node, edges), rest),
            [node, ..seen],
            edges,
          )
      }
    }
  }
}
