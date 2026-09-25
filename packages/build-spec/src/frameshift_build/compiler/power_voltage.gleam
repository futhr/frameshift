/// Effective voltage under the declared mode/rating constraints. A passive
/// output cannot reset upstream uncertainty or a cumulative voltage drop.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/facts
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{Check}
import frameshift_build/compiler/ports
import frameshift_build/compiler/power_context.{type Context, type Trace} as ctx
import frameshift_build/compiler/power_modes
import frameshift_physical.{Compatible, Interval, Unknown}
import gleam/list
import gleam/option.{None, Some}

pub type Step {
  Step(trace: Trace, findings: List(Finding))
}

pub fn inspect(endpoint: a.Endpoint, context: Context) -> Step {
  walk(endpoint, [], context, True)
}

pub fn arriving(endpoint: a.Endpoint, context: Context) -> Trace {
  arrival(endpoint, [], context)
}

fn walk(
  endpoint: a.Endpoint,
  visited: List(String),
  context: Context,
  detailed: Bool,
) -> Step {
  case ports.resolve(endpoint, context.value) {
    Error(_) ->
      Step(
        ctx.unresolved(
          endpoint,
          "output.voltage",
          context,
          "unresolved_endpoint",
        ),
        [],
      )
    Ok(source) -> {
      let scope = ctx.mode(source.instance, context)
      case ctx.cycle(source.instance, visited) {
        True ->
          Step(
            ctx.trace(
              None,
              [scope.reading],
              ctx.topology_inputs(source.instance),
              "power_flow_cycle",
            ),
            [],
          )
        False ->
          source_step(
            source,
            scope,
            [source.instance.id, ..visited],
            context,
            detailed,
          )
      }
    }
  }
}

fn source_step(
  source: ports.Endpoint,
  scope: power_modes.Mode,
  visited: List(String),
  context: Context,
  detailed: Bool,
) -> Step {
  let output =
    facts.port(source.instance, source.port.id, "output.voltage", context.value)
  let permitted =
    source.port.kind == "power"
    && source.port.direction == "source"
    && power_modes.supplies(scope)
  case permitted, scope.kind {
    False, _ ->
      Step(
        ctx.trace(
          None,
          [scope.reading, output],
          ctx.topology_inputs(source.instance),
          "unsupported_power_scope",
        ),
        [],
      )
    True, "passthrough" -> passive(source, scope, visited, context, detailed)
    True, _ ->
      Step(
        ctx.trace(
          finding.interval(output),
          [scope.reading, output],
          ctx.topology_inputs(source.instance),
          "incomplete_voltage",
        ),
        [],
      )
  }
}

fn arrival(
  endpoint: a.Endpoint,
  visited: List(String),
  context: Context,
) -> Trace {
  case ctx.incoming(endpoint, context) {
    [connection] -> {
      let upstream = walk(connection.from, visited, context, False).trace
      ctx.trace(
        upstream.value,
        upstream.readings,
        list.append(upstream.inputs, ports.inputs(connection, context.value)),
        upstream.reason,
      )
    }
    [] ->
      ctx.unresolved(endpoint, "input.voltage", context, "missing_power_feed")
    _ ->
      ctx.unresolved(endpoint, "input.voltage", context, "multiple_power_feeds")
  }
}

fn passive(
  source: ports.Endpoint,
  scope: power_modes.Mode,
  visited: List(String),
  context: Context,
  detailed: Bool,
) -> Step {
  case ctx.input(source.instance, context) {
    Error(_) ->
      Step(
        ctx.trace(
          None,
          [scope.reading],
          ctx.topology_inputs(source.instance),
          "unsupported_power_scope",
        ),
        [],
      )
    Ok(input) -> {
      let upstream = arrival(ctx.key(input), visited, context)
      let input_range =
        facts.port(
          input.instance,
          input.port.id,
          "input.voltage",
          context.value,
        )
      let drop =
        facts.port(
          source.instance,
          source.port.id,
          "voltage.drop",
          context.value,
        )
      let output_range =
        facts.port(
          source.instance,
          source.port.id,
          "output.voltage",
          context.value,
        )
      let readings = [
        scope.reading,
        input_range,
        drop,
        output_range,
        ..upstream.readings
      ]
      let inputs =
        list.append(ctx.topology_inputs(source.instance), upstream.inputs)
      let base =
        Check(
          "power.passthrough.input_voltage",
          Unknown,
          upstream.reason,
          [source.instance.id],
          case detailed {
            True -> inputs
            False -> []
          },
        )
      let derived = case upstream.value, finding.interval(drop) {
        Some(voltage), Some(drop) if voltage.minimum >= drop.maximum ->
          Some(Interval(
            voltage.minimum - drop.maximum,
            voltage.maximum - drop.minimum,
          ))
        _, _ -> None
      }
      // Ancestors retain complete trace evidence. Their local diagnostics are
      // emitted once by the stage, rather than materialized at every later hop.
      let check_readings = case detailed {
        True -> readings
        False -> []
      }
      let checks = [
        finding.within(
          base,
          check_readings,
          "mv",
          upstream.value,
          finding.interval(input_range),
        ),
        finding.at_most(
          Check(..base, code: "power.voltage_drop"),
          check_readings,
          "mv",
          finding.interval(drop),
          upstream.value,
        ),
        finding.within(
          Check(
            ..base,
            code: "power.passthrough.output_voltage",
            reason: "unavailable_derived_voltage",
          ),
          check_readings,
          "mv",
          derived,
          finding.interval(output_range),
        ),
      ]
      let value = case
        list.all(checks, fn(f) { f.check.outcome == Compatible })
      {
        True -> derived
        False -> None
      }
      let reason = case
        list.find(checks, fn(f) { f.check.outcome != Compatible })
      {
        Ok(f) -> f.check.reason
        Error(_) -> "unavailable_derived_voltage"
      }
      Step(ctx.trace(value, readings, inputs, reason), case detailed {
        True -> checks
        False -> []
      })
    }
  }
}
