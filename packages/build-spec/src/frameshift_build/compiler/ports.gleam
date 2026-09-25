/// Shared exact endpoint resolution for structural and physical port stages.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/model.{type Input, BuildInput, ProfileInput}
import frameshift_build/model.{type Port} as _
import frameshift_build/resolution.{type Resolution}
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

fn endpoint_input(endpoint: a.Endpoint, value: Resolution) -> List(Input) {
  case resolution.find_instance(value, endpoint.instance) {
    Error(_) -> []
    Ok(instance) -> [
      ProfileInput(instance.id, instance.profile, ["ports", endpoint.port]),
    ]
  }
}
