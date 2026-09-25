import frameshift_build/assembly/model as a
import frameshift_build/compiler/facts
import frameshift_build/compiler/mount_context as ctx
import frameshift_build/compiler/mount_flow
import frameshift_build/compiler/mounting
import frameshift_physical.{type Interval}
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import load_fixture
import mount_fixture

fn interval(value: Option(Interval)) -> json.Json {
  case value {
    None -> json.null()
    Some(i) -> json.array([i.minimum, i.maximum], json.int)
  }
}

pub fn main() {
  int.range(0, 256, Nil, fn(_, seed) {
    let count = seed % 16 + 1
    let value =
      mount_fixture.tree(count, seed)
      |> load_fixture.component(
        "part-0",
        load_fixture.number("mass", "g", seed + 1, seed + 17),
      )
    let context = ctx.prepare(value)
    let assert Ok(findings) = mounting.evaluate(value)
    let nodes =
      list.map(value.assembly.instances, fn(i) {
        let assert Ok(#(low, high)) =
          facts.numeric(facts.component(i, "mass", value))
        json.object([
          #("id", json.string(i.id)),
          #("mass", json.array([low, high], json.int)),
        ])
      })
    let actual =
      list.map(value.assembly.instances, fn(i) {
        let input = case i.id {
          "frame" -> None
          _ -> mount_flow.demand(a.Endpoint(i.id, "in"), context).mass
        }
        let payload = case
          list.find(findings, fn(f) {
            f.check.code == "mount.shared_capacity"
            && f.check.instances == [i.id]
          })
        {
          Error(_) -> None
          Ok(f) ->
            case f.measurement {
              Some(m) -> m.required
              None -> None
            }
        }
        let root = case mount_flow.path(i, context).anchor {
          Some(root) -> json.string(root.id)
          None -> json.null()
        }
        json.object([
          #("id", json.string(i.id)),
          #("input", interval(input)),
          #("payload", interval(payload)),
          #("root", root),
        ])
      })
    json.object([
      #("seed", json.int(seed)),
      #("nodes", json.array(nodes, fn(n) { n })),
      #(
        "edges",
        json.array(value.assembly.connections, fn(c) {
          json.array([c.from.instance, c.to.instance], json.string)
        }),
      ),
      #("actual", json.array(actual, fn(a) { a })),
    ])
    |> json.to_string
    |> io.println
  })
}
