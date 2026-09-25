/// Shared exact endpoint resolution for structural and physical port stages.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/model.{type Input, BuildInput, ProfileInput}
import frameshift_build/model.{type Port} as _
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{type Outcome, Incompatible, Unknown}
import gleam/list
import gleam/result

pub type Endpoint {
  Endpoint(instance: a.Instance, port: Port)
}

pub type Missing {
  MissingInstance
  MissingProfile
  MissingPort
}

pub fn resolve(
  endpoint: a.Endpoint,
  value: Resolution,
) -> Result(Endpoint, Missing) {
  use instance <- result.try(
    resolution.find_instance(value, endpoint.instance)
    |> result.replace_error(MissingInstance),
  )
  use profile <- result.try(
    resolution.find_profile(value, instance.profile)
    |> result.replace_error(MissingProfile),
  )
  use port <- result.try(
    list.find(profile.ports, fn(port) { port.id == endpoint.port })
    |> result.replace_error(MissingPort),
  )
  Ok(Endpoint(instance, port))
}

pub fn inputs(connection: a.Connection, value: Resolution) -> List(Input) {
  list.flatten([
    [
      BuildInput([
        "connections",
        connection.from.instance,
        connection.from.port,
        connection.to.instance,
        connection.to.port,
      ]),
    ],
    endpoint_input(connection.from, value),
    endpoint_input(connection.to, value),
  ])
}

pub fn ordinary(
  from: Endpoint,
  to: Endpoint,
  kind: String,
  bidirectional_reason: String,
) -> Result(Nil, #(Outcome, String)) {
  case from.instance.id == to.instance.id {
    True -> Error(#(Incompatible, "self_connection"))
    False ->
      case from.port.kind != kind || to.port.kind != kind {
        True -> Error(#(Incompatible, "port_kind_mismatch"))
        False -> {
          let permitted =
            list.contains(["source", "bidirectional"], from.port.direction)
            && list.contains(["sink", "bidirectional"], to.port.direction)
          case
            permitted,
            from.port.direction == "bidirectional"
            || to.port.direction == "bidirectional"
          {
            False, _ -> Error(#(Incompatible, "direction_mismatch"))
            True, True -> Error(#(Unknown, bidirectional_reason))
            True, False -> Ok(Nil)
          }
        }
      }
  }
}

fn endpoint_input(endpoint: a.Endpoint, value: Resolution) -> List(Input) {
  case resolution.find_instance(value, endpoint.instance) {
    Error(_) -> []
    Ok(instance) -> [
      ProfileInput(instance.id, instance.profile, ["ports", endpoint.port]),
    ]
  }
}
