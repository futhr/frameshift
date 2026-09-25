/// Feed obligations and passive input ratings for the declared DC flow graph.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/facts
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{BuildInput, Check, ProfileInput}
import frameshift_build/compiler/ports
import frameshift_build/compiler/power_context.{type Context} as ctx
import frameshift_build/compiler/power_current
import frameshift_build/compiler/power_voltage
import frameshift_build/resolution
import frameshift_physical.{type Interval, Compatible, Interval, Unknown}
import gleam/list
import gleam/option.{type Option, None, Some}

pub fn power(
  current: Option(Interval),
  voltage: Option(Interval),
) -> Option(Interval) {
  case current, voltage {
    Some(current), Some(voltage) ->
      Some(Interval(
        current.minimum * voltage.minimum / 1000,
        { current.maximum * voltage.maximum + 999 } / 1000,
      ))
    _, _ -> None
  }
}

pub fn diagnostics(context: Context) -> List(Finding) {
  let connections =
    list.filter(context.value.assembly.connections, fn(c) {
      case
        ports.resolve(c.from, context.value),
        ports.resolve(c.to, context.value)
      {
        Ok(from), Ok(to) -> from.port.kind == "power" || to.port.kind == "power"
        _, _ -> True
      }
    })
  let participants =
    list.flat_map(connections, fn(c) { [c.from.instance, c.to.instance] })
  let modes =
    list.filter(context.modes, fn(m) {
      list.contains(participants, m.instance.id)
      || !list.is_empty(ctx.power_ports(m.instance, context))
    })
  let obligations =
    list.flat_map(modes, fn(m) {
      ctx.power_ports(m.instance, context)
      |> list.filter(fn(p) {
        p.port.direction == "sink"
        && {
          p.port.required
          || list.contains(["converter", "passthrough"], m.kind)
          || !list.is_empty(ctx.incoming(ctx.key(p), context))
        }
      })
      |> list.map(ctx.key)
    })
  let targets =
    list.append(obligations, list.map(connections, fn(c) { c.to }))
    |> list.unique
  let consumers = list.filter(modes, fn(m) { m.kind == "consumer" })
  let passive =
    list.filter(modes, fn(m) {
      m.kind == "passthrough" && m.finding.check.outcome == Compatible
    })
  list.flatten([
    list.map(modes, fn(m) { m.finding }),
    list.map(targets, feed(_, context)),
    list.map(consumers, fn(m) { consumer_feed(m.instance, context) }),
    list.flat_map(passive, fn(m) {
      let voltages =
        ctx.outputs(m.instance, context)
        |> list.filter(fn(p) {
          !list.is_empty(ctx.outgoing(ctx.key(p), context))
        })
        |> list.flat_map(fn(p) {
          power_voltage.inspect(ctx.key(p), context).findings
        })
      list.append(voltages, input_ratings(m.instance, context))
    }),
  ])
}

fn feed(endpoint: a.Endpoint, context: Context) -> Finding {
  let connections = ctx.incoming(endpoint, context)
  let port_input = case
    resolution.find_instance(context.value, endpoint.instance)
  {
    Ok(instance) -> [
      ProfileInput(instance.id, instance.profile, ["ports", endpoint.port]),
    ]
    Error(_) -> []
  }
  let #(outcome, reason) = case connections {
    [_] -> #(Compatible, "single_power_feed")
    [] -> #(Unknown, "missing_power_feed")
    _ -> #(Unknown, "multiple_power_feeds")
  }
  finding.explain(
    Check(
      "power.feed",
      outcome,
      reason,
      [endpoint.instance],
      list.append(port_input, [
        BuildInput(["connections"]),
        ..list.flat_map(connections, ports.inputs(_, context.value))
      ]),
    ),
    [],
  )
}

fn consumer_feed(instance: a.Instance, context: Context) -> Finding {
  let connected =
    ctx.power_ports(instance, context)
    |> list.any(fn(p) {
      p.port.direction == "sink"
      && !list.is_empty(ctx.incoming(ctx.key(p), context))
    })
  finding.explain(
    Check(
      "power.consumer_feed",
      case connected {
        True -> Compatible
        False -> Unknown
      },
      case connected {
        True -> "consumer_feed_present"
        False -> "missing_power_feed"
      },
      [instance.id],
      ctx.topology_inputs(instance),
    ),
    [ctx.mode(instance, context).reading],
  )
}

fn input_ratings(instance: a.Instance, context: Context) -> List(Finding) {
  case ctx.input(instance, context) {
    Error(_) -> []
    Ok(input) -> {
      let current = power_current.demand(ctx.key(input), context)
      let voltage = power_voltage.arriving(ctx.key(input), context)
      let amps =
        facts.port(instance, input.port.id, "current.capacity", context.value)
      let watts =
        facts.port(instance, input.port.id, "power.capacity", context.value)
      let base =
        Check(
          "power.passthrough.input_current",
          Unknown,
          current.reason,
          [instance.id],
          current.inputs,
        )
      [
        finding.at_most(
          base,
          [amps, ..current.readings],
          "ma",
          current.value,
          finding.interval(amps),
        ),
        finding.at_most(
          Check(
            ..base,
            code: "power.passthrough.input_power",
            reason: case current.value {
              None -> current.reason
              Some(_) -> voltage.reason
            },
            inputs: list.append(current.inputs, voltage.inputs),
          ),
          [watts, ..list.append(current.readings, voltage.readings)],
          "mw",
          power(current.value, voltage.value),
          finding.interval(watts),
        ),
      ]
    }
  }
}
