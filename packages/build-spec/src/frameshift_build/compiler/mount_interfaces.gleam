/// Mechanical endpoint validity and complete connected-port declarations.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/declarations
import frameshift_build/compiler/facts
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{Check}
import frameshift_build/compiler/ports
import frameshift_build/model.{type Refusal, InvalidReference} as _
import frameshift_build/port_graph
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/list
import gleam/result

pub fn relevant(connection: a.Connection, value: Resolution) -> Bool {
  case
    ports.resolve(connection.from, value),
    ports.resolve(connection.to, value)
  {
    Ok(from), Ok(to) ->
      from.port.kind == "mechanical" || to.port.kind == "mechanical"
    _, _ -> True
  }
}

pub fn evaluate(value: Resolution) -> Result(List(Finding), Refusal) {
  let connections = list.filter(value.assembly.connections, relevant(_, value))
  let nodes =
    list.flat_map(connections, fn(c) { [c.from, c.to] }) |> list.unique
  let edges = list.map(connections, fn(c) { #(c.from, c.to) })
  use groups <- result.try(port_graph.components(nodes, edges))
  use declarations <- result.try(
    list.try_map(groups, fn(group) {
      list.try_map(["mount.pattern", "mount.contract"], check_group(
        group,
        connections,
        _,
        value,
      ))
    }),
  )
  Ok(list.append(
    list.map(connections, structure(_, value)),
    list.flatten(declarations),
  ))
}

fn structure(connection: a.Connection, value: Resolution) -> Finding {
  let #(outcome, reason) = case
    ports.resolve(connection.from, value),
    ports.resolve(connection.to, value)
  {
    Ok(from), Ok(to) ->
      case
        ports.ordinary(
          from,
          to,
          "mechanical",
          "unsupported_bidirectional_mount",
        )
      {
        Ok(_) -> #(Compatible, "directed_mount_interface")
        Error(reason) -> reason
      }
    Error(ports.MissingPort), _ | _, Error(ports.MissingPort) -> #(
      Incompatible,
      "absent_port",
    )
    _, _ -> #(Unknown, "unresolved_endpoint")
  }
  finding.explain(
    Check(
      "mount.interface",
      outcome,
      reason,
      list.unique([connection.from.instance, connection.to.instance]),
      ports.inputs(connection, value),
    ),
    [],
  )
}

fn check_group(
  group: List(a.Endpoint),
  connections: List(a.Connection),
  key: String,
  value: Resolution,
) -> Result(Finding, Refusal) {
  use readings <- result.try(
    list.try_map(group, fn(endpoint) {
      use instance <- result.try(
        resolution.find_instance(value, endpoint.instance)
        |> result.replace_error(InvalidReference),
      )
      Ok(facts.port(instance, endpoint.port, key, value))
    }),
  )
  let connections =
    list.filter(connections, fn(c) {
      list.contains(group, c.from) && list.contains(group, c.to)
    })
  Ok(declarations.agreement(
    Check(
      "mount.connected." <> key,
      Unknown,
      "incomplete_contract",
      list.map(group, fn(p) { p.instance }) |> list.unique,
      list.flat_map(connections, ports.inputs(_, value)),
    ),
    readings,
  ))
}
