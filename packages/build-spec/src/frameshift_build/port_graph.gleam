/// Bounded undirected connectivity with structured port keys and stable output.
import frameshift_build/assembly/model.{type Endpoint} as _
import frameshift_build/bounds
import frameshift_build/model.{
  type Refusal, DuplicateIdentifier, InvalidReference,
} as _
import gleam/list
import gleam/result
import gleam/string

pub fn components(
  nodes: List(Endpoint),
  edges: List(#(Endpoint, Endpoint)),
) -> Result(List(List(Endpoint)), Refusal) {
  use _ <- result.try(bounds.count(nodes, 0, 576))
  use _ <- result.try(bounds.count(edges, 0, 512))
  use _ <- result.try(
    case list.length(list.unique(nodes)) == list.length(nodes) {
      True -> Ok(Nil)
      False -> Error(DuplicateIdentifier)
    },
  )
  use _ <- result.try(
    list.try_each(nodes, fn(n) {
      use _ <- result.try(bounds.identifier(n.instance))
      bounds.identifier(n.port)
    }),
  )
  use _ <- result.try(
    case
      list.all(edges, fn(e) {
        list.contains(nodes, e.0) && list.contains(nodes, e.1)
      })
    {
      True -> Ok(Nil)
      False -> Error(InvalidReference)
    },
  )
  let nodes = list.sort(nodes, compare)
  let edges =
    list.map(edges, fn(e) {
      let assert [first, second] = list.sort([e.0, e.1], compare)
      #(first, second)
    })
    |> list.unique
  Ok(groups(nodes, edges, []))
}

fn compare(a: Endpoint, b: Endpoint) {
  case a.instance == b.instance {
    True -> string.compare(a.port, b.port)
    False -> string.compare(a.instance, b.instance)
  }
}

fn groups(
  pending: List(Endpoint),
  edges: List(#(Endpoint, Endpoint)),
  complete: List(List(Endpoint)),
) -> List(List(Endpoint)) {
  case pending {
    [] -> list.reverse(complete)
    [first, ..] -> {
      let reached = visit([first], [], edges)
      let group = list.filter(pending, list.contains(reached, _))
      groups(list.filter(pending, fn(n) { !list.contains(reached, n) }), edges, [
        group,
        ..complete
      ])
    }
  }
}

fn visit(
  pending: List(Endpoint),
  seen: List(Endpoint),
  edges: List(#(Endpoint, Endpoint)),
) -> List(Endpoint) {
  case pending {
    [] -> seen
    [node, ..rest] ->
      case list.contains(seen, node) {
        True -> visit(rest, seen, edges)
        False -> {
          let next =
            list.flat_map(edges, fn(e) {
              case e {
                #(a, b) if a == node -> [b]
                #(a, b) if b == node -> [a]
                _ -> []
              }
            })
          visit(list.append(next, rest), [node, ..seen], edges)
        }
      }
  }
}
