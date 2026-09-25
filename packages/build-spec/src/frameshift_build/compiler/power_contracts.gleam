/// Whole connected-set agreement. Pairwise alternatives cannot imply a shared
/// selection; matching terms still do not establish registered qualification.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/declarations
import frameshift_build/compiler/facts.{type Reading}
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{
  type Input, BuildInput, Check, ProfileInput,
}
import frameshift_build/compiler/ports
import frameshift_build/model.{type Refusal, InvalidReference} as _
import frameshift_build/port_graph
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Unknown}
import gleam/list
import gleam/result

type Link {
  Link(
    from: a.Endpoint,
    to: a.Endpoint,
    inputs: List(Input),
    assumptions: List(Reading),
  )
}

pub fn evaluate(value: Resolution) -> Result(List(Finding), Refusal) {
  let connections = list.filter(value.assembly.connections, relevant(_, value))
  let physical =
    list.map(connections, fn(c) {
      Link(c.from, c.to, ports.inputs(c, value), [])
    })
  let rails =
    list.append(
      physical,
      list.flat_map(value.assembly.instances, ties(_, connections, value)),
    )
  use physical_checks <- result.try(checks(
    physical,
    [
      "pinout.contract",
      "connector.contract",
      "protection.contract",
      "strain_relief.contract",
    ],
    value,
  ))
  use rail_checks <- result.try(checks(
    rails,
    ["reference.contract", "polarity"],
    value,
  ))
  Ok(list.append(physical_checks, rail_checks))
}

fn relevant(connection: a.Connection, value: Resolution) -> Bool {
  case
    ports.resolve(connection.from, value),
    ports.resolve(connection.to, value)
  {
    Ok(from), Ok(to) -> from.port.kind == "power" || to.port.kind == "power"
    _, _ -> True
  }
}

fn ties(
  instance: a.Instance,
  connections: List(a.Connection),
  value: Resolution,
) -> List(Link) {
  let mode = facts.component(instance, "power.mode", value)
  case facts.terms(mode), resolution.find_profile(value, instance.profile) {
    Ok(["passthrough"]), Ok(profile) -> {
      let power = list.filter(profile.ports, fn(p) { p.kind == "power" })
      let sinks = list.filter(power, fn(p) { p.direction == "sink" })
      let sources = list.filter(power, fn(p) { p.direction == "source" })
      case sinks, list.any(power, fn(p) { p.direction == "bidirectional" }) {
        [sink], False ->
          sources
          |> list.filter(fn(p) {
            list.any(connections, fn(c) {
              c.from == a.Endpoint(instance.id, p.id)
            })
          })
          |> list.map(fn(p) {
            Link(
              a.Endpoint(instance.id, sink.id),
              a.Endpoint(instance.id, p.id),
              [
                BuildInput(["connections"]),
                ProfileInput(instance.id, instance.profile, ["ports"]),
              ],
              [mode],
            )
          })
        _, _ -> []
      }
    }
    _, _ -> []
  }
}

fn checks(
  links: List(Link),
  keys: List(String),
  value: Resolution,
) -> Result(List(Finding), Refusal) {
  let nodes = list.flat_map(links, fn(l) { [l.from, l.to] }) |> list.unique
  let edges = list.map(links, fn(l) { #(l.from, l.to) })
  use groups <- result.try(port_graph.components(nodes, edges))
  use groups <- result.try(
    list.try_map(groups, fn(group) {
      list.try_map(keys, check(group, links, _, value))
    }),
  )
  Ok(list.flatten(groups))
}

fn check(
  group: List(a.Endpoint),
  links: List(Link),
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
  let relevant =
    list.filter(links, fn(l) {
      list.contains(group, l.from) && list.contains(group, l.to)
    })
  let agreement =
    declarations.with_selector(
      Check(
        "power.connected." <> key,
        Unknown,
        case key {
          "polarity" -> "unsupported_polarity"
          _ -> "incomplete_contract"
        },
        list.map(group, fn(p) { p.instance }) |> list.unique,
        list.flat_map(relevant, fn(l) { l.inputs }) |> list.unique,
      ),
      readings,
      terms(_, key),
      "connected_contract_agrees",
    )
  Ok(
    finding.explain(
      agreement.check,
      list.append(
        readings,
        list.flat_map(relevant, fn(l) { l.assumptions }) |> list.unique,
      ),
    )
    |> finding.with_terms(agreement.common_terms),
  )
}

fn terms(reading: Reading, key: String) -> Result(List(String), Nil) {
  use terms <- result.try(facts.terms(reading) |> result.replace_error(Nil))
  case key, terms {
    "polarity", ["positive"] | "polarity", ["negative"] -> Ok(terms)
    "polarity", _ -> Error(Nil)
    _, _ -> Ok(terms)
  }
}
