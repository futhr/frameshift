/// Immutable mode cache and evidence traces shared by DC flow stages.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/evidence
import frameshift_build/compiler/facts.{type Reading}
import frameshift_build/compiler/finding
import frameshift_build/compiler/model.{type Input, BuildInput, ProfileInput}
import frameshift_build/compiler/ports
import frameshift_build/compiler/power_modes.{type Mode}
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{type Interval}
import gleam/list
import gleam/option.{type Option, None, Some}

pub type Context {
  Context(value: Resolution, modes: List(Mode))
}

pub type Trace {
  Trace(
    value: Option(Interval),
    readings: List(Reading),
    inputs: List(Input),
    reason: String,
  )
}

pub fn prepare(value: Resolution) -> Context {
  Context(value, list.map(value.assembly.instances, power_modes.read(_, value)))
}

pub fn mode(instance: a.Instance, context: Context) -> Mode {
  case list.find(context.modes, fn(m) { m.instance.id == instance.id }) {
    Ok(mode) -> mode
    Error(_) -> power_modes.read(instance, context.value)
  }
}

pub fn trace(
  value: Option(Interval),
  readings: List(Reading),
  inputs: List(Input),
  fallback: String,
) -> Trace {
  Trace(
    value,
    evidence.readings(readings),
    evidence.inputs(inputs),
    case value {
      Some(_) -> "known_flow"
      None -> finding.unknown_reason(readings, fallback)
    },
  )
}

pub fn merge(
  traces: List(Trace),
  readings: List(Reading),
  inputs: List(Input),
  fallback: String,
) -> Trace {
  let value = finding.sum(list.map(traces, fn(t) { t.value }))
  let reason = case list.find(traces, fn(t) { option.is_none(t.value) }) {
    Ok(trace) -> trace.reason
    Error(_) -> fallback
  }
  trace(
    value,
    list.append(readings, list.flat_map(traces, fn(t) { t.readings })),
    list.append(inputs, list.flat_map(traces, fn(t) { t.inputs })),
    reason,
  )
}

pub fn topology_inputs(instance: a.Instance) -> List(Input) {
  [
    BuildInput(["connections"]),
    ProfileInput(instance.id, instance.profile, ["ports"]),
  ]
}

pub fn incoming(endpoint: a.Endpoint, context: Context) -> List(a.Connection) {
  list.filter(context.value.assembly.connections, fn(c) { c.to == endpoint })
}

pub fn outgoing(endpoint: a.Endpoint, context: Context) -> List(a.Connection) {
  list.filter(context.value.assembly.connections, fn(c) { c.from == endpoint })
}

pub fn power_ports(
  instance: a.Instance,
  context: Context,
) -> List(ports.Endpoint) {
  case resolution.find_profile(context.value, instance.profile) {
    Error(_) -> []
    Ok(profile) ->
      profile.ports
      |> list.filter(fn(p) { p.kind == "power" })
      |> list.map(ports.Endpoint(instance, _))
  }
}

pub fn input(
  instance: a.Instance,
  context: Context,
) -> Result(ports.Endpoint, Nil) {
  case
    power_ports(instance, context)
    |> list.filter(fn(p) { p.port.direction == "sink" })
  {
    [input] -> Ok(input)
    _ -> Error(Nil)
  }
}

pub fn outputs(instance: a.Instance, context: Context) -> List(ports.Endpoint) {
  power_ports(instance, context)
  |> list.filter(fn(p) { p.port.direction == "source" })
}

pub fn key(endpoint: ports.Endpoint) -> a.Endpoint {
  a.Endpoint(endpoint.instance.id, endpoint.port.id)
}

pub fn unresolved(
  endpoint: a.Endpoint,
  property: String,
  context: Context,
  reason: String,
) -> Trace {
  case resolution.find_instance(context.value, endpoint.instance) {
    Error(_) -> trace(None, [], [BuildInput(["instances"])], reason)
    Ok(instance) ->
      trace(
        None,
        [facts.port(instance, endpoint.port, property, context.value)],
        topology_inputs(instance),
        reason,
      )
  }
}

pub fn cycle(instance: a.Instance, visited: List(String)) -> Bool {
  list.length(visited) >= 64 || list.contains(visited, instance.id)
}
