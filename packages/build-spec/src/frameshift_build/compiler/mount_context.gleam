/// Cached declared mechanical roles and exact support endpoints.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/facts.{type Reading}
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{
  type Input, BuildInput, Check, ProfileInput,
}
import frameshift_build/compiler/ports
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/list

pub type Mode {
  Mode(
    instance: a.Instance,
    kind: String,
    ports: List(ports.Endpoint),
    reading: Reading,
    finding: Finding,
  )
}

pub type Context {
  Context(value: Resolution, modes: List(Mode))
}

pub fn prepare(value: Resolution) -> Context {
  Context(value, list.map(value.assembly.instances, read(_, value)))
}

fn read(instance: a.Instance, value: Resolution) -> Mode {
  let reading = facts.component(instance, "mount.mode", value)
  let kind = case facts.terms(reading) {
    Ok([kind]) -> kind
    _ -> ""
  }
  let ports = case resolution.find_profile(value, instance.profile) {
    Error(_) -> []
    Ok(profile) ->
      profile.ports
      |> list.filter(fn(p) { p.kind == "mechanical" })
      |> list.map(ports.Endpoint(instance, _))
  }
  let sinks = list.count(ports, fn(p) { p.port.direction == "sink" })
  let #(outcome, reason) = case
    list.any(ports, fn(p) { p.port.direction == "bidirectional" })
  {
    True -> #(Unknown, "unsupported_bidirectional_mount")
    False ->
      case kind, sinks, instance.location {
        "anchor", _, "internal" -> #(Incompatible, "internal_anchor")
        "anchor", 0, _ -> #(Compatible, "declared_anchor")
        "supported", 1, _ -> #(Compatible, "declared_supported_part")
        "anchor", _, _ | "supported", _, _ -> #(
          Incompatible,
          "mount_mode_port_mismatch",
        )
        _, _, _ -> #(
          Unknown,
          finding.unknown_reason([reading], "unsupported_mount_mode"),
        )
      }
  }
  Mode(
    instance,
    kind,
    ports,
    reading,
    finding.explain(
      Check("mount.mode", outcome, reason, [instance.id], inputs(instance)),
      [reading],
    ),
  )
}

pub fn mode(instance: a.Instance, context: Context) -> Mode {
  case list.find(context.modes, fn(m) { m.instance.id == instance.id }) {
    Ok(mode) -> mode
    Error(_) -> read(instance, context.value)
  }
}

pub fn inputs(instance: a.Instance) -> List(Input) {
  [
    BuildInput(["connections"]),
    BuildInput(["instances", instance.id, "location"]),
    ProfileInput(instance.id, instance.profile, ["ports"]),
  ]
}

pub fn key(endpoint: ports.Endpoint) -> a.Endpoint {
  a.Endpoint(endpoint.instance.id, endpoint.port.id)
}

pub fn input(mode: Mode) -> Result(ports.Endpoint, Nil) {
  case list.filter(mode.ports, fn(p) { p.port.direction == "sink" }) {
    [input] -> Ok(input)
    _ -> Error(Nil)
  }
}

pub fn incoming(endpoint: a.Endpoint, context: Context) -> List(a.Connection) {
  list.filter(context.value.assembly.connections, fn(c) { c.to == endpoint })
}

pub fn outgoing(endpoint: a.Endpoint, context: Context) -> List(a.Connection) {
  list.filter(context.value.assembly.connections, fn(c) { c.from == endpoint })
}

pub fn outputs(mode: Mode) -> List(ports.Endpoint) {
  list.filter(mode.ports, fn(p) { p.port.direction == "source" })
}

pub fn children(mode: Mode, context: Context) -> List(a.Connection) {
  outputs(mode) |> list.flat_map(fn(p) { outgoing(key(p), context) })
}

pub fn source(
  connection: a.Connection,
  context: Context,
) -> Result(ports.Endpoint, Nil) {
  case ports.resolve(connection.from, context.value) {
    Ok(from)
      if from.port.kind == "mechanical" && from.port.direction == "source"
    -> Ok(from)
    _ -> Error(Nil)
  }
}

pub fn visited(instance: a.Instance, seen: List(String)) -> Bool {
  list.length(seen) >= 64 || list.contains(seen, instance.id)
}
