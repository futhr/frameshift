/// Necessary DC declaration agreements only. Contract registration, current
/// accounting and physical qualification remain separate mandatory stages.
import frameshift_build/assembly/model.{type Connection} as _
import frameshift_build/compiler/facts.{type Reading}
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{type Check, Check}
import frameshift_build/compiler/ports.{type Endpoint}
import frameshift_build/compiler/power_context.{type Context} as ctx
import frameshift_build/compiler/power_voltage
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/list

pub fn evaluate(value: Resolution) -> List(Finding) {
  let context = ctx.prepare(value)
  list.flat_map(value.assembly.connections, connection(_, context))
}

fn connection(connection: Connection, context: Context) -> List(Finding) {
  let value = context.value
  let base =
    Check(
      "power.interface",
      Unknown,
      "unresolved_endpoint",
      list.unique([connection.from.instance, connection.to.instance]),
      ports.inputs(connection, value),
    )
  case
    ports.resolve(connection.from, value),
    ports.resolve(connection.to, value)
  {
    Ok(from), Ok(to) -> resolved(base, from, to, context)
    Error(ports.MissingPort), _ | _, Error(ports.MissingPort) -> [
      finding.explain(
        Check(..base, outcome: Incompatible, reason: "absent_port"),
        [],
      ),
    ]
    _, _ -> [finding.explain(base, [])]
  }
}

fn resolved(
  base: Check,
  from: Endpoint,
  to: Endpoint,
  context: Context,
) -> List(Finding) {
  case from.port.kind == "power" || to.port.kind == "power" {
    False -> []
    True ->
      case validity(from, to) {
        Ok(_) -> checks(base, from, to, context)
        Error(#(outcome, reason)) -> [
          finding.explain(Check(..base, outcome:, reason:), []),
        ]
      }
  }
}

fn validity(from: Endpoint, to: Endpoint) {
  case from.instance.id == to.instance.id {
    True -> Error(#(Incompatible, "self_connection"))
    False ->
      case from.port.kind == to.port.kind {
        False -> Error(#(Incompatible, "port_kind_mismatch"))
        True -> directions(from, to)
      }
  }
}

fn directions(from: Endpoint, to: Endpoint) {
  let permitted =
    list.contains(["source", "bidirectional"], from.port.direction)
    && list.contains(["sink", "bidirectional"], to.port.direction)
  case permitted {
    False -> Error(#(Incompatible, "direction_mismatch"))
    True ->
      case
        from.port.direction == "bidirectional"
        || to.port.direction == "bidirectional"
      {
        True -> Error(#(Unknown, "unsupported_bidirectional_power"))
        False -> Ok(Nil)
      }
  }
}

fn read(endpoint: Endpoint, key: String, value: Resolution) -> Reading {
  facts.port(endpoint.instance, endpoint.port.id, key, value)
}

fn checks(
  base: Check,
  from: Endpoint,
  to: Endpoint,
  context: Context,
) -> List(Finding) {
  let value = context.value
  let output = power_voltage.inspect(ctx.key(from), context).trace
  let input = read(to, "input.voltage", value)
  let from_polarity = read(from, "polarity", value)
  let to_polarity = read(to, "polarity", value)
  [
    finding.within(
      Check(
        ..base,
        code: "power.voltage",
        reason: output.reason,
        inputs: list.append(base.inputs, output.inputs),
      ),
      [input, ..output.readings],
      "mv",
      output.value,
      finding.interval(input),
    ),
    polarity(Check(..base, code: "power.polarity"), from_polarity, to_polarity),
    ..list.map(
      [
        "reference.contract",
        "pinout.contract",
        "connector.contract",
        "protection.contract",
        "strain_relief.contract",
      ],
      fn(key) {
        agreement(
          Check(..base, code: "power." <> key),
          read(from, key, value),
          read(to, key, value),
        )
      },
    )
  ]
}

fn polarity(base: Check, from: Reading, to: Reading) -> Finding {
  let readings = [from, to]
  let #(outcome, reason) = case facts.terms(from), facts.terms(to) {
    Ok([first]), Ok([second]) ->
      case
        list.contains(["positive", "negative"], first)
        && list.contains(["positive", "negative"], second)
      {
        False -> #(Unknown, "unsupported_polarity")
        True ->
          case first == second {
            True -> #(Compatible, "polarity_agrees")
            False -> #(Incompatible, "polarity_mismatch")
          }
      }
    Ok(_), Ok(_) -> #(Unknown, "unsupported_polarity")
    _, _ -> #(Unknown, finding.unknown_reason(readings, "incomplete_polarity"))
  }
  finding.explain(Check(..base, outcome:, reason:), readings)
}

fn agreement(base: Check, from: Reading, to: Reading) -> Finding {
  let readings = [from, to]
  let #(outcome, reason) = case facts.terms(from), facts.terms(to) {
    Ok(first), Ok(second) ->
      case list.any(first, fn(term) { list.contains(second, term) }) {
        True -> #(Compatible, "declared_contract_agrees")
        False -> #(Incompatible, "declared_contract_mismatch")
      }
    _, _ -> #(Unknown, finding.unknown_reason(readings, "incomplete_contract"))
  }
  finding.explain(Check(..base, outcome:, reason:), readings)
}
