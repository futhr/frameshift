/// Declared DC circuit scope; not qualification of wiring or conversion.
import frameshift_build/assembly/model.{type Instance} as _
import frameshift_build/compiler/facts.{type Reading}
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{Check, ProfileInput}
import frameshift_build/model.{type Port} as _
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/list

pub type Mode {
  Mode(instance: Instance, kind: String, reading: Reading, finding: Finding)
}

pub fn read(instance: Instance, value: Resolution) -> Mode {
  let reading = facts.component(instance, "power.mode", value)
  let kind = case facts.terms(reading) {
    Ok([kind]) -> kind
    _ -> ""
  }
  let #(outcome, reason) = case
    resolution.find_profile(value, instance.profile)
  {
    Error(_) -> #(Unknown, "missing_profile")
    Ok(profile) ->
      topology(kind, list.filter(profile.ports, fn(p) { p.kind == "power" }))
  }
  let reason = case outcome {
    Unknown -> finding.unknown_reason([reading], reason)
    _ -> reason
  }
  Mode(
    instance,
    kind,
    reading,
    finding.explain(
      Check("power.mode", outcome, reason, [instance.id], [
        ProfileInput(instance.id, instance.profile, ["ports"]),
      ]),
      [reading],
    ),
  )
}

fn topology(kind: String, ports: List(Port)) {
  case list.any(ports, fn(p) { p.direction == "bidirectional" }) {
    True -> #(Unknown, "unsupported_bidirectional_power")
    False -> {
      let sources = list.count(ports, fn(p) { p.direction == "source" })
      let sinks = list.count(ports, fn(p) { p.direction == "sink" })
      let valid = case kind {
        "source" -> sources > 0 && sinks == 0
        "consumer" -> sinks > 0 && sources == 0
        "converter" | "passthrough" -> sinks == 1 && sources > 0
        _ -> False
      }
      case
        list.contains(["source", "consumer", "converter", "passthrough"], kind),
        valid
      {
        False, _ -> #(Unknown, "unsupported_power_mode")
        True, True -> #(Compatible, case kind {
          "passthrough" -> "passive_power_scope"
          _ -> "direct_power_scope"
        })
        True, False -> #(Incompatible, "power_mode_port_mismatch")
      }
    }
  }
}

pub fn supplies(mode: Mode) -> Bool {
  mode.finding.check.outcome == Compatible
  && list.contains(["source", "converter", "passthrough"], mode.kind)
}

pub fn consumes(mode: Mode) -> Bool {
  mode.finding.check.outcome == Compatible
  && list.contains(["consumer", "converter"], mode.kind)
}
