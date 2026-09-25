/// Directed reachability under explicit internal mappings. Conditional topology
/// evidence only; mapping identity, authority and device qualification are external.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{
  type Input, BuildInput, Check, MappingInput, ProfileInput,
}
import frameshift_build/compiler/ownership
import frameshift_build/compiler/ports
import frameshift_build/compiler/signal_mapping.{type Mapping}
import frameshift_build/model.{type Refusal} as _
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{type Outcome, Compatible, Incompatible, Unknown}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

type Context {
  Context(value: Resolution, mappings: List(Mapping))
}

type Path {
  Path(
    outcome: Outcome,
    reason: String,
    root: Option(String),
    inputs: List(Input),
  )
}

pub fn evaluate(
  value: Resolution,
  mappings: List(Mapping),
) -> Result(List(Finding), Refusal) {
  use _ <- result.try(signal_mapping.validate(mappings, value))
  let context = Context(value, mappings)
  Ok(
    list.flat_map(value.assembly.instances, fn(instance) {
      case resolution.find_profile(value, instance.profile) {
        Ok(profile) if profile.kind == "display" -> {
          let sinks =
            list.filter(profile.ports, fn(p) {
              p.kind == "signal"
              && p.direction == "sink"
              && {
                p.required
                || list.any(value.assembly.connections, fn(c) {
                  c.to == a.Endpoint(instance.id, p.id)
                })
              }
            })
          case sinks {
            [] -> [display(instance, None, context)]
            _ ->
              list.map(sinks, fn(p) { display(instance, Some(p.id), context) })
          }
        }
        _ -> []
      }
    }),
  )
}

fn display(
  instance: a.Instance,
  sink: Option(String),
  context: Context,
) -> Finding {
  let #(owner_check, owner) = ownership.controller(instance, context.value)
  let path = case owner, sink {
    None, _ ->
      Path(owner_check.check.outcome, owner_check.check.reason, None, [])
    _, None -> Path(Unknown, "missing_display_signal_input", None, [])
    Some(owner), Some(sink) -> {
      let path = walk(a.Endpoint(instance.id, sink), [], [], context)
      case path.root {
        Some(root) if root != owner.id ->
          Path(..path, outcome: Incompatible, reason: "wrong_controller_route")
        _ -> path
      }
    }
  }
  let sink_inputs = case sink {
    None -> [ProfileInput(instance.id, instance.profile, ["ports"])]
    Some(id) -> [ProfileInput(instance.id, instance.profile, ["ports", id])]
  }
  finding.explain(
    Check(
      "signal.route",
      path.outcome,
      path.reason,
      list.unique(
        list.append(owner_check.check.instances, case path.root {
          Some(id) -> [id]
          None -> []
        }),
      ),
      list.flatten([
        owner_check.check.inputs,
        sink_inputs,
        [
          BuildInput(["intent", "artifact"]),
          BuildInput(["intent", "firmware"]),
          BuildInput(["intent", "protocol"]),
        ],
        path.inputs,
      ]),
    ),
    [],
  )
}

fn walk(
  endpoint: a.Endpoint,
  seen: List(a.Endpoint),
  inputs: List(List(Input)),
  context: Context,
) -> Path {
  case list.contains(seen, endpoint) {
    True -> finish(Incompatible, "signal_route_cycle", None, inputs)
    False -> {
      case ports.resolve(endpoint, context.value) {
        Error(ports.MissingPort) ->
          finish(Incompatible, "missing_port", None, inputs)
        Error(_) -> finish(Unknown, "missing_route_profile", None, inputs)
        Ok(port) -> {
          let inputs = [
            [
              ProfileInput(port.instance.id, port.instance.profile, [
                "ports",
                port.port.id,
              ]),
            ],
            ..inputs
          ]
          let seen = [endpoint, ..seen]
          case port.port.kind, port.port.direction {
            "signal", "sink" -> incoming(endpoint, seen, inputs, context)
            "signal", "source" -> output(port, seen, inputs, context)
            _, _ ->
              finish(Unknown, "unsupported_signal_route_port", None, inputs)
          }
        }
      }
    }
  }
}

fn incoming(
  endpoint: a.Endpoint,
  seen: List(a.Endpoint),
  inputs: List(List(Input)),
  context: Context,
) -> Path {
  let edges =
    list.filter(context.value.assembly.connections, fn(c) { c.to == endpoint })
  let inputs = [[BuildInput(["connections"])], ..inputs]
  case edges {
    [] -> finish(Unknown, "missing_signal_feed", None, inputs)
    [edge] -> {
      let inputs = [ports.inputs(edge, context.value), ..inputs]
      case
        ports.resolve(edge.from, context.value),
        ports.resolve(edge.to, context.value)
      {
        Ok(from), Ok(to) -> {
          case
            ports.ordinary(from, to, "signal", "bidirectional_signal_route")
          {
            Error(#(outcome, reason)) -> finish(outcome, reason, None, inputs)
            Ok(_) -> walk(edge.from, seen, inputs, context)
          }
        }
        Error(ports.MissingPort), _ ->
          finish(Incompatible, "missing_port", None, inputs)
        _, _ -> finish(Unknown, "missing_route_profile", None, inputs)
      }
    }
    _ ->
      finish(Unknown, "multiple_signal_feeds", None, [
        list.flat_map(edges, ports.inputs(_, context.value)),
        ..inputs
      ])
  }
}

fn output(
  port: ports.Endpoint,
  seen: List(a.Endpoint),
  inputs: List(List(Input)),
  context: Context,
) -> Path {
  let assert Ok(profile) =
    resolution.find_profile(context.value, port.instance.profile)
  let inputs = [
    [ProfileInput(port.instance.id, port.instance.profile, ["kind"])],
    ..inputs
  ]
  case profile.kind {
    "controller" ->
      finish(
        Compatible,
        "controller_route_present",
        Some(port.instance.id),
        inputs,
      )
    _ -> mapped(port, seen, inputs, context)
  }
}

fn mapped(
  port: ports.Endpoint,
  seen: List(a.Endpoint),
  inputs: List(List(Input)),
  context: Context,
) -> Path {
  let mapping =
    list.find(context.mappings, fn(m) { m.profile == port.instance.profile })
  case mapping {
    Error(_) -> finish(Unknown, "missing_internal_signal_mapping", None, inputs)
    Ok(mapping) -> {
      let inputs = [
        list.map(
          ["profile", "artifact", "firmware", "protocol", "pairs"],
          fn(field) {
            MappingInput(port.instance.id, mapping.identity, [field])
          },
        ),
        ..inputs
      ]
      case list.find(mapping.pairs, fn(p) { p.output == port.port.id }) {
        Error(_) -> finish(Unknown, "unmapped_signal_output", None, inputs)
        Ok(pair) ->
          walk(
            a.Endpoint(port.instance.id, pair.input),
            seen,
            [
              [
                MappingInput(port.instance.id, mapping.identity, [
                  "pairs",
                  pair.input,
                  pair.output,
                ]),
              ],
              ..inputs
            ],
            context,
          )
      }
    }
  }
}

fn finish(
  outcome: Outcome,
  reason: String,
  root: Option(String),
  inputs: List(List(Input)),
) -> Path {
  Path(outcome, reason, root, list.flatten(list.reverse(inputs)))
}
