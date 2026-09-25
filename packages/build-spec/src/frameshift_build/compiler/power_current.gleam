/// Backward demand propagation through single-feed passive branches.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/facts
import frameshift_build/compiler/finding
import frameshift_build/compiler/ports
import frameshift_build/compiler/power_context.{type Context, type Trace} as ctx
import frameshift_build/compiler/power_modes
import frameshift_physical.{Compatible}
import gleam/list
import gleam/option.{None}

pub fn demand(endpoint: a.Endpoint, context: Context) -> Trace {
  walk(endpoint, [], context)
}

fn walk(
  endpoint: a.Endpoint,
  visited: List(String),
  context: Context,
) -> Trace {
  case ports.resolve(endpoint, context.value) {
    Error(_) ->
      ctx.unresolved(
        endpoint,
        "current.maximum",
        context,
        "unresolved_endpoint",
      )
    Ok(input) -> {
      let scope = ctx.mode(input.instance, context)
      let inputs = ctx.topology_inputs(input.instance)
      case ctx.cycle(input.instance, visited) {
        True -> ctx.trace(None, [scope.reading], inputs, "power_flow_cycle")
        False ->
          case ctx.incoming(endpoint, context) {
            [connection] ->
              input_demand(
                input,
                scope,
                [input.instance.id, ..visited],
                connection,
                context,
              )
            [] -> ctx.trace(None, [scope.reading], inputs, "missing_power_feed")
            _ ->
              ctx.trace(None, [scope.reading], inputs, "multiple_power_feeds")
          }
      }
    }
  }
}

fn input_demand(
  input: ports.Endpoint,
  scope: power_modes.Mode,
  visited: List(String),
  connection: a.Connection,
  context: Context,
) -> Trace {
  let inputs =
    list.append(
      ctx.topology_inputs(input.instance),
      ports.inputs(connection, context.value),
    )
  let permitted =
    input.port.kind == "power"
    && input.port.direction == "sink"
    && scope.finding.check.outcome == Compatible
  case permitted, scope.kind {
    True, "passthrough" -> {
      let connections =
        ctx.outputs(input.instance, context)
        |> list.flat_map(fn(p) { ctx.outgoing(ctx.key(p), context) })
      let traces =
        list.map(connections, fn(c) {
          let trace = walk(c.to, visited, context)
          ctx.trace(
            trace.value,
            trace.readings,
            list.append(trace.inputs, ports.inputs(c, context.value)),
            trace.reason,
          )
        })
      ctx.merge(traces, [scope.reading], inputs, "incomplete_passive_demand")
    }
    True, _ -> {
      let reading =
        facts.port(
          input.instance,
          input.port.id,
          "current.maximum",
          context.value,
        )
      let current = case power_modes.consumes(scope) {
        True -> finding.interval(reading)
        False -> None
      }
      ctx.trace(
        current,
        [scope.reading, reading],
        inputs,
        "unsupported_power_scope",
      )
    }
    _, _ -> ctx.trace(None, [scope.reading], inputs, "unsupported_power_scope")
  }
}
