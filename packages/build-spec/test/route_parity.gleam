import frameshift_build/assembly/model as a
import frameshift_build/compiler/model.{
  BuildInput, LayoutInput, MappingInput, ProfileInput,
}
import frameshift_build/compiler/signal_routes
import frameshift_build/resolution as r
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import route_fixture

pub fn main() {
  let value = route_fixture.chain(2)
  let mapping = route_fixture.mapping(route_fixture.adapted())
  let sources = ["controller", "adapter-0", "adapter-1"]
  let sinks = ["adapter-0", "adapter-1", "panel"]
  let possible =
    list.flat_map(sources, fn(source) {
      list.map(sinks, fn(sink) {
        a.Connection(
          a.Endpoint(source, "out"),
          a.Endpoint(sink, case sink {
            "panel" -> "dc"
            _ -> "in"
          }),
        )
      })
    })
  int.range(0, 512, Nil, fn(_, mask) {
    let #(_, edges) =
      list.fold(possible, #(1, []), fn(state, edge) {
        #(state.0 * 2, case mask / state.0 % 2 {
          1 -> [edge, ..state.1]
          _ -> state.1
        })
      })
    let value =
      r.Resolution(
        ..value,
        assembly: a.Assembly(..value.assembly, connections: edges),
      )
    let assert Ok([finding]) = signal_routes.evaluate(value, [mapping])
    json.object([
      #("mask", json.int(mask)),
      #(
        "outcome",
        json.string(case finding.check.outcome {
          Compatible -> "compatible"
          Incompatible -> "incompatible"
          Unknown -> "unknown"
        }),
      ),
      #("reason", json.string(finding.check.reason)),
      #(
        "inputs",
        json.array(finding.check.inputs, fn(input) {
          json.array(
            case input {
              BuildInput(path) -> ["build", ..path]
              ProfileInput(instance, identity, path) -> [
                "profile",
                instance,
                identity,
                ..path
              ]
              MappingInput(instance, identity, path) -> [
                "mapping",
                instance,
                identity,
                ..path
              ]
              LayoutInput(instance, identity, path) -> [
                "layout",
                instance,
                identity,
                ..path
              ]
            },
            json.string,
          )
        }),
      ),
    ])
    |> json.to_string
    |> io.println
  })
}
