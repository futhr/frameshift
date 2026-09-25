/// Structural obligations on validated resolution. Numeric/interface facts and
/// mandatory physical completeness remain obligations of the complete compiler.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/model.{
  type Check, type Input, BuildInput, Check, ProfileInput,
}
import frameshift_build/compiler/ports
import frameshift_build/graph
import frameshift_build/model.{type Port, type Profile, type Refusal} as _
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/list
import gleam/result

pub fn evaluate(value: Resolution) -> Result(List(Check), Refusal) {
  let plan = value.assembly
  let nodes = list.map(plan.instances, fn(v) { v.id })
  let dependencies =
    list.map(plan.dependencies, fn(v) { #(v.consumer, v.provider) })
  use dependency_cycles <- result.try(graph.cyclic_nodes(nodes, dependencies))
  let power_connections =
    list.filter(plan.connections, power_connection(_, value))
  let power_edges =
    list.map(power_connections, fn(v) { #(v.from.instance, v.to.instance) })
  use power_cycles <- result.try(graph.cyclic_nodes(nodes, power_edges))
  Ok(
    list.flatten([
      [
        cycle_check("dependency.acyclic", dependency_cycles, [
          BuildInput(["dependencies"]),
        ]),
      ],
      list.flat_map(plan.instances, instance_checks(_, value)),
      list.map(plan.dependencies, dependency_check(_, value)),
      list.flat_map(plan.connections, connection_checks(_, value)),
      [
        cycle_check(
          "power.acyclic",
          power_cycles,
          power_inputs(plan.connections, value),
        ),
      ],
    ]),
  )
}

fn cycle_check(
  code: String,
  cycles: List(String),
  inputs: List(Input),
) -> Check {
  case cycles {
    [] -> Check(code, Compatible, "acyclic", [], inputs)
    _ -> Check(code, Incompatible, "cycle_detected", cycles, inputs)
  }
}

fn profile(instance: a.Instance, value: Resolution) -> Result(Profile, Nil) {
  resolution.find_profile(value, instance.profile)
}

fn instance(id: String, value: Resolution) -> Result(a.Instance, Nil) {
  resolution.find_instance(value, id)
}

fn input(instance: a.Instance, path: List(String)) -> Input {
  ProfileInput(instance.id, instance.profile, path)
}

fn instance_checks(instance: a.Instance, value: Resolution) -> List(Check) {
  let resolved =
    Check(
      "profile.resolved",
      Compatible,
      "exact_profile_resolved",
      [instance.id],
      [input(instance, [])],
    )
  case profile(instance, value) {
    Error(_) -> [Check(..resolved, outcome: Unknown, reason: "missing_profile")]
    Ok(profile) -> {
      let class = case list.contains(profile.classes, value.assembly.class) {
        True -> Compatible
        False -> Incompatible
      }
      let revision = case profile.part_revision {
        "unverified" -> Unknown
        _ -> Compatible
      }
      list.flatten([
        [
          resolved,
          Check(
            "profile.class",
            class,
            case class {
              Compatible -> "class_supported"
              _ -> "class_mismatch"
            },
            [instance.id],
            [BuildInput(["class"]), input(instance, ["classes"])],
          ),
          Check(
            "profile.part_revision",
            revision,
            case revision {
              Unknown -> "unverified_part_revision"
              _ -> "part_revision_declared"
            },
            [instance.id],
            [input(instance, ["part_revision"])],
          ),
        ],
        list.map(profile.requires, required_role(instance, _, value)),
        profile.ports
          |> list.filter(fn(port) { port.required })
          |> list.map(required_port(instance, _, value)),
      ])
    }
  }
}

fn required_role(
  consumer: a.Instance,
  role: String,
  value: Resolution,
) -> Check {
  let dependencies =
    list.filter(value.assembly.dependencies, fn(v) {
      v.consumer == consumer.id && v.role == role
    })
  let checks = list.map(dependencies, dependency_check(_, value))
  let check =
    Check(
      "dependency.required",
      Unknown,
      "missing_required_role",
      [consumer.id],
      [input(consumer, ["requires", role]), BuildInput(["dependencies"])],
    )
  case checks {
    [] -> check
    _ -> {
      let outcome = case list.any(checks, fn(v) { v.outcome == Compatible }) {
        True -> Compatible
        False ->
          case list.any(checks, fn(v) { v.outcome == Unknown }) {
            True -> Unknown
            False -> Incompatible
          }
      }
      Check(
        ..check,
        outcome:,
        reason: case outcome {
          Compatible -> "required_role_bound"
          Unknown -> "unresolved_provider"
          Incompatible -> "role_kind_mismatch"
        },
        inputs: list.append(
          check.inputs,
          list.flat_map(checks, fn(v) { v.inputs }),
        ),
      )
    }
  }
}

fn dependency_check(dependency: a.Dependency, value: Resolution) -> Check {
  let reference =
    BuildInput([
      "dependencies",
      dependency.consumer,
      dependency.provider,
      dependency.role,
    ])
  let base =
    Check(
      "dependency.kind",
      Unknown,
      "unresolved_provider",
      [dependency.consumer, dependency.provider],
      [reference],
    )
  case instance(dependency.provider, value) {
    Error(_) -> base
    Ok(provider) -> {
      let base = Check(..base, inputs: [reference, input(provider, ["kind"])])
      case profile(provider, value) {
        Error(_) -> base
        Ok(profile) ->
          case profile.kind == dependency.role {
            True ->
              Check(..base, outcome: Compatible, reason: "role_kind_matches")
            False ->
              Check(..base, outcome: Incompatible, reason: "role_kind_mismatch")
          }
      }
    }
  }
}

fn required_port(instance: a.Instance, port: Port, value: Resolution) -> Check {
  let endpoint = a.Endpoint(instance.id, port.id)
  let connected =
    list.any(value.assembly.connections, fn(v) {
      v.from == endpoint || v.to == endpoint
    })
  Check(
    "port.required",
    case connected {
      True -> Compatible
      False -> Unknown
    },
    case connected {
      True -> "required_port_connected"
      False -> "missing_required_connection"
    },
    [instance.id],
    [
      input(instance, ["ports", port.id, "required"]),
      BuildInput(["connections"]),
    ],
  )
}

type EndpointState {
  UnresolvedProfile
  AbsentPort
  FoundPort(Port)
}

fn endpoint(endpoint: a.Endpoint, value: Resolution) -> EndpointState {
  case ports.resolve(endpoint, value) {
    Ok(endpoint) -> FoundPort(endpoint.port)
    Error(ports.MissingPort) -> AbsentPort
    Error(_) -> UnresolvedProfile
  }
}

fn connection_inputs(
  connection: a.Connection,
  value: Resolution,
) -> List(Input) {
  ports.inputs(connection, value)
}

fn connection_checks(
  connection: a.Connection,
  value: Resolution,
) -> List(Check) {
  let subjects = list.unique([connection.from.instance, connection.to.instance])
  let inputs = connection_inputs(connection, value)
  let different = connection.from.instance != connection.to.instance
  let self_check =
    Check(
      "connection.instances",
      case different {
        True -> Compatible
        False -> Incompatible
      },
      case different {
        True -> "distinct_instances"
        False -> "self_connection"
      },
      subjects,
      inputs,
    )
  let endpoints =
    Check(
      "connection.endpoints",
      Unknown,
      "unresolved_endpoint_profile",
      subjects,
      inputs,
    )
  let rest = case
    endpoint(connection.from, value),
    endpoint(connection.to, value)
  {
    AbsentPort, _ | _, AbsentPort -> [
      Check(..endpoints, outcome: Incompatible, reason: "absent_port"),
    ]
    FoundPort(from), FoundPort(to) -> [
      Check(..endpoints, outcome: Compatible, reason: "endpoints_exist"),
      Check(
        "connection.kind",
        case from.kind == to.kind {
          True -> Compatible
          False -> Incompatible
        },
        case from.kind == to.kind {
          True -> "port_kind_matches"
          False -> "port_kind_mismatch"
        },
        subjects,
        inputs,
      ),
      direction_check(from, to, subjects, inputs),
    ]
    _, _ -> [endpoints]
  }
  [self_check, ..rest]
}

fn direction_check(
  from: Port,
  to: Port,
  subjects: List(String),
  inputs: List(Input),
) -> Check {
  let permits =
    list.contains(["source", "bidirectional"], from.direction)
    && list.contains(["sink", "bidirectional"], to.direction)
  Check(
    "connection.direction",
    case permits {
      True -> Compatible
      False -> Incompatible
    },
    case permits {
      True -> "direction_permitted"
      False -> "direction_mismatch"
    },
    subjects,
    inputs,
  )
}

fn power_connection(connection: a.Connection, value: Resolution) -> Bool {
  case endpoint(connection.from, value), endpoint(connection.to, value) {
    FoundPort(from), FoundPort(to) -> from.kind == "power" && to.kind == "power"
    _, _ -> False
  }
}

fn power_inputs(
  connections: List(a.Connection),
  value: Resolution,
) -> List(Input) {
  [
    BuildInput(["connections"]),
    ..list.flat_map(connections, connection_inputs(_, value))
  ]
  |> list.unique
}
