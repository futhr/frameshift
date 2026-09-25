/// DC budgets derived from complete downstream demand and effective voltage.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/facts.{type Reading}
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{type Input, Check}
import frameshift_build/compiler/ports
import frameshift_build/compiler/power_context.{type Context} as ctx
import frameshift_build/compiler/power_current
import frameshift_build/compiler/power_flow
import frameshift_build/compiler/power_modes
import frameshift_build/compiler/power_voltage
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{type Interval, Unknown}
import gleam/list
import gleam/option.{type Option, None, Some}

type Group {
  Group(source: ports.Endpoint, connections: List(a.Connection))
}

type Budget {
  Budget(
    group: Group,
    power: Option(Interval),
    readings: List(Reading),
    inputs: List(Input),
    reason: String,
    findings: List(Finding),
  )
}

pub fn evaluate(value: Resolution) -> List(Finding) {
  let context = ctx.prepare(value)
  let groups = list.flat_map(value.assembly.instances, groups(_, context))
  let budgets = list.map(groups, budget(_, context))
  let owners = list.map(groups, fn(g) { g.source.instance }) |> list.unique
  list.flatten([
    power_flow.diagnostics(context),
    list.flat_map(budgets, fn(b) { b.findings }),
    list.map(owners, shared(_, budgets, value)),
  ])
}

fn groups(instance: a.Instance, context: Context) -> List(Group) {
  ctx.power_ports(instance, context)
  |> list.filter(fn(p) { p.port.direction != "sink" })
  |> list.map(fn(p) { Group(p, ctx.outgoing(ctx.key(p), context)) })
  |> list.filter(fn(g) { !list.is_empty(g.connections) })
}

fn budget(group: Group, context: Context) -> Budget {
  let source = group.source
  let scope = ctx.mode(source.instance, context)
  let demands =
    list.map(group.connections, fn(c) { power_current.demand(c.to, context) })
  let current =
    ctx.merge(
      demands,
      [scope.reading],
      ctx.topology_inputs(source.instance),
      "incomplete_current",
    )
  let current = case power_modes.supplies(scope) {
    True -> current
    False ->
      ctx.Trace(..current, value: None, reason: "unsupported_power_scope")
  }
  let voltage = power_voltage.inspect(ctx.key(source), context).trace
  let power = power_flow.power(current.value, voltage.value)
  let reason = case current.value {
    None -> current.reason
    Some(_) -> voltage.reason
  }
  let fanout =
    facts.port(source.instance, source.port.id, "fanout.maximum", context.value)
  let amps =
    facts.port(
      source.instance,
      source.port.id,
      "current.capacity",
      context.value,
    )
  let watts =
    facts.port(source.instance, source.port.id, "power.capacity", context.value)
  let base =
    Check(
      "power.fanout",
      Unknown,
      current.reason,
      list.unique([
        source.instance.id,
        ..list.map(group.connections, fn(c) { c.to.instance })
      ]),
      current.inputs,
    )
  let power_readings = list.append(voltage.readings, current.readings)
  let power_inputs = list.append(voltage.inputs, current.inputs)
  Budget(group, power, power_readings, power_inputs, reason, [
    finding.at_most(
      base,
      [fanout],
      "count",
      finding.constant(list.length(group.connections)),
      finding.interval(fanout),
    ),
    finding.at_most(
      Check(..base, code: "power.current_capacity"),
      [amps, ..current.readings],
      "ma",
      current.value,
      finding.interval(amps),
    ),
    finding.at_most(
      Check(
        ..base,
        code: "power.output_capacity",
        reason:,
        inputs: power_inputs,
      ),
      [watts, ..power_readings],
      "mw",
      power,
      finding.interval(watts),
    ),
  ])
}

fn shared(
  instance: a.Instance,
  budgets: List(Budget),
  value: Resolution,
) -> Finding {
  let budgets =
    list.filter(budgets, fn(b) { b.group.source.instance.id == instance.id })
  let capacity = facts.component(instance, "power.output_capacity", value)
  let readings = [capacity, ..list.flat_map(budgets, fn(b) { b.readings })]
  let inputs = list.flat_map(budgets, fn(b) { b.inputs })
  let reason = case list.find(budgets, fn(b) { b.power == None }) {
    Ok(b) -> b.reason
    Error(_) -> "incomplete_power"
  }
  finding.at_most(
    Check("power.shared_capacity", Unknown, reason, [instance.id], inputs),
    readings,
    "mw",
    finding.sum(list.map(budgets, fn(b) { b.power })),
    finding.interval(capacity),
  )
}
