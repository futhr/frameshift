/// Necessary directed signal envelopes and declarations. Timing, thresholds,
/// internal adapter routes and executable support require qualified mappings.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/declarations
import frameshift_build/compiler/facts.{type Reading}
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{Check}
import frameshift_build/compiler/ports
import frameshift_build/model.{type Refusal, InvalidReference} as _
import frameshift_build/port_graph
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/list
import gleam/result

pub fn evaluate(value: Resolution) -> Result(List(Finding), Refusal) {
  let connections = list.filter(value.assembly.connections, relevant(_, value))
  let nodes =
    list.flat_map(connections, fn(c) { [c.from, c.to] }) |> list.unique
  use groups <- result.try(port_graph.components(
    nodes,
    list.map(connections, fn(c) { #(c.from, c.to) }),
  ))
  use agreements <- result.try(
    list.try_map(groups, fn(group) {
      list.try_map(
        [
          "polarity",
          "reference.contract",
          "pinout.contract",
          "connector.contract",
          "protection.contract",
          "driver.contract",
          "strain_relief.contract",
        ],
        common(group, connections, _, value),
      )
    }),
  )
  Ok(list.append(
    list.flat_map(connections, connection(_, value)),
    list.flatten(agreements),
  ))
}

fn relevant(connection: a.Connection, value: Resolution) -> Bool {
  case
    ports.resolve(connection.from, value),
    ports.resolve(connection.to, value)
  {
    Ok(from), Ok(to) -> from.port.kind == "signal" || to.port.kind == "signal"
    _, _ -> True
  }
}

fn connection(connection: a.Connection, value: Resolution) -> List(Finding) {
  let base =
    Check(
      "signal.interface",
      Unknown,
      "unresolved_endpoint",
      list.unique([connection.from.instance, connection.to.instance]),
      ports.inputs(connection, value),
    )
  case
    ports.resolve(connection.from, value),
    ports.resolve(connection.to, value)
  {
    Ok(from), Ok(to) ->
      case
        ports.ordinary(from, to, "signal", "unsupported_bidirectional_signal")
      {
        Error(#(outcome, reason)) -> [
          finding.explain(Check(..base, outcome:, reason:), []),
        ]
        Ok(_) -> {
          let output =
            facts.port(from.instance, from.port.id, "logic.voltage", value)
          let input =
            facts.port(to.instance, to.port.id, "logic.voltage", value)
          [
            finding.explain(
              Check(
                ..base,
                outcome: Compatible,
                reason: "directed_signal_interface",
              ),
              [],
            ),
            finding.within(
              Check(
                ..base,
                code: "signal.voltage",
                reason: "incomplete_signal_voltage",
              ),
              [output, input],
              "mv",
              finding.interval(output),
              finding.interval(input),
            ),
          ]
        }
      }
    Error(ports.MissingPort), _ | _, Error(ports.MissingPort) -> [
      finding.explain(
        Check(..base, outcome: Incompatible, reason: "absent_port"),
        [],
      ),
    ]
    _, _ -> [finding.explain(base, [])]
  }
}

fn common(
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
  Ok(declarations.with_selector(
    Check(
      "signal.connected." <> key,
      Unknown,
      case key {
        "polarity" -> "unsupported_signal_polarity"
        _ -> "incomplete_contract"
      },
      list.map(group, fn(p) { p.instance }) |> list.unique,
      list.flat_map(connections, ports.inputs(_, value)),
    ),
    readings,
    terms(_, key),
    "connected_contract_agrees",
  ))
}

fn terms(reading: Reading, key: String) -> Result(List(String), Nil) {
  use terms <- result.try(facts.terms(reading) |> result.replace_error(Nil))
  case key, terms {
    "polarity", ["positive"] -> Ok(terms)
    "polarity", _ -> Error(Nil)
    _, _ -> Ok(terms)
  }
}
