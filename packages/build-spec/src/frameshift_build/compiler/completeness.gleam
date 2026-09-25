/// Fixed physical obligations. Profiles cannot opt out with empty requirements,
/// optional ports or a composite label. Full-stage aggregation is separate.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/facts
import frameshift_build/compiler/finding.{type Finding, Finding}
import frameshift_build/compiler/model.{BuildInput, Check, ProfileInput}
import frameshift_build/compiler/ownership
import frameshift_build/compiler/power_modes
import frameshift_build/model.{type Profile} as _
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/list

pub fn evaluate(value: Resolution) -> List(Finding) {
  [source(value), ..list.flat_map(value.assembly.instances, instance(_, value))]
}

fn instance(instance: a.Instance, value: Resolution) -> List(Finding) {
  let dimensions =
    list.map(["width", "height", "depth"], fn(axis) {
      required(instance, "outline." <> axis, False, value)
    })
  let classified = case resolution.find_profile(value, instance.profile) {
    Error(_) -> [
      finding.explain(
        Check(
          "complete.classification",
          Unknown,
          "missing_profile",
          [instance.id],
          [ProfileInput(instance.id, instance.profile, ["kind"])],
        ),
        [],
      ),
    ]
    Ok(profile) -> obligations(instance, profile, value)
  }
  list.append(dimensions, classified)
}

fn required(
  instance: a.Instance,
  key: String,
  exact: Bool,
  value: Resolution,
) -> Finding {
  let reading = facts.component(instance, key, value)
  let #(outcome, reason) = case facts.numeric(reading) {
    Ok(#(low, high)) if exact && low != high -> #(
      Unknown,
      "ambiguous_raster_dimension",
    )
    Ok(_) -> #(Compatible, "required_fact_present")
    Error(_) -> #(
      Unknown,
      finding.unknown_reason([reading], "incomplete_required_fact"),
    )
  }
  finding.explain(
    Check("complete." <> key, outcome, reason, [instance.id], [
      ProfileInput(instance.id, instance.profile, ["kind"]),
    ]),
    [reading],
  )
}

fn obligations(
  instance: a.Instance,
  profile: Profile,
  value: Resolution,
) -> List(Finding) {
  let mode = power_modes.read(instance, value)
  let source_kind = case mode.kind == "source" {
    True -> [
      finding.explain(
        Check(
          "complete.source_kind",
          case profile.kind == "power" {
            True -> Compatible
            False -> Incompatible
          },
          case profile.kind == "power" {
            True -> "power_source_kind"
            False -> "wrong_power_source_kind"
          },
          [instance.id],
          [ProfileInput(instance.id, instance.profile, ["kind"])],
        ),
        [mode.reading],
      ),
    ]
    False -> []
  }
  let powered = case
    list.contains(["display", "controller", "driver", "storage"], profile.kind)
  {
    True -> [
      powered_scope(instance, mode),
      connected(instance, profile, "power", "sink", value),
    ]
    False ->
      case profile.kind {
        "power" -> [
          Finding(
            ..mode.finding,
            check: Check(..mode.finding.check, code: "complete.power_scope"),
          ),
        ]
        _ -> []
      }
  }
  let signal_inputs = case
    list.contains(["display", "driver", "storage"], profile.kind)
  {
    True -> [connected(instance, profile, "signal", "sink", value)]
    False -> []
  }
  let signal_outputs = case
    list.contains(["controller", "driver"], profile.kind)
  {
    True -> [connected(instance, profile, "signal", "source", value)]
    False -> []
  }
  let specific = case profile.kind {
    "frame" ->
      list.map(["width", "height", "depth"], cavity(instance, _, value))
    "display" -> [
      required(instance, "raster.width", True, value),
      required(instance, "raster.height", True, value),
      ownership.controller(instance, value).0,
    ]
    "assembly" -> [
      finding.explain(
        Check(
          "complete.constituents",
          Unknown,
          "composite_expansion_required",
          [instance.id],
          [ProfileInput(instance.id, instance.profile, ["kind"])],
        ),
        [],
      ),
    ]
    _ -> []
  }
  list.flatten([source_kind, powered, signal_inputs, signal_outputs, specific])
}

fn powered_scope(instance: a.Instance, mode: power_modes.Mode) -> Finding {
  let #(outcome, reason) = case mode.kind {
    "consumer" | "converter" -> #(Compatible, "powered_scope_declared")
    "source" | "passthrough" -> #(Incompatible, "powered_role_mode_mismatch")
    _ -> #(
      Unknown,
      finding.unknown_reason([mode.reading], "unsupported_power_mode"),
    )
  }
  finding.explain(
    Check("complete.power_scope", outcome, reason, [instance.id], [
      ProfileInput(instance.id, instance.profile, ["kind"]),
    ]),
    [mode.reading],
  )
}

fn connected(
  instance: a.Instance,
  profile: Profile,
  kind: String,
  direction: String,
  value: Resolution,
) -> Finding {
  let present =
    list.any(profile.ports, fn(p) {
      p.kind == kind
      && p.direction == direction
      && list.any(value.assembly.connections, fn(c) {
        let endpoint = case direction {
          "sink" -> c.to
          _ -> c.from
        }
        endpoint == a.Endpoint(instance.id, p.id)
      })
    })
  finding.explain(
    Check(
      "complete." <> kind <> "_" <> direction,
      case present {
        True -> Compatible
        False -> Unknown
      },
      case present {
        True -> "required_connection_present"
        False -> "missing_required_connection"
      },
      [instance.id],
      [
        BuildInput(["connections"]),
        ProfileInput(instance.id, instance.profile, ["kind"]),
        ProfileInput(instance.id, instance.profile, ["ports"]),
      ],
    ),
    [],
  )
}

fn cavity(instance: a.Instance, axis: String, value: Resolution) -> Finding {
  let inner = facts.component(instance, "inner." <> axis, value)
  let outer = facts.component(instance, "outline." <> axis, value)
  finding.at_most(
    Check(
      "complete.cavity." <> axis,
      Unknown,
      "incomplete_frame_dimensions",
      [instance.id],
      [ProfileInput(instance.id, instance.profile, ["kind"])],
    ),
    [inner, outer],
    "um",
    finding.interval(inner),
    finding.interval(outer),
  )
}

fn source(value: Resolution) -> Finding {
  let modes = list.map(value.assembly.instances, power_modes.read(_, value))
  let sources =
    list.filter(modes, fn(mode) {
      case resolution.find_profile(value, mode.instance.profile) {
        Ok(profile)
          if profile.kind == "power"
          && mode.kind == "source"
          && mode.finding.check.outcome == Compatible
        ->
          list.any(profile.ports, fn(p) {
            p.kind == "power"
            && p.direction == "source"
            && list.any(value.assembly.connections, fn(c) {
              c.from == a.Endpoint(mode.instance.id, p.id)
            })
          })
        _ -> False
      }
    })
  let #(outcome, reason) = case sources {
    [] -> #(Unknown, "missing_connected_power_source")
    _ -> #(Compatible, "power_source_present")
  }
  finding.explain(
    Check(
      "complete.power_source",
      outcome,
      reason,
      list.map(sources, fn(s) { s.instance.id }),
      [
        BuildInput(["instances"]),
        BuildInput(["connections"]),
        ..list.flat_map(value.assembly.instances, fn(i) {
          [
            ProfileInput(i.id, i.profile, ["kind"]),
            ProfileInput(i.id, i.profile, ["ports"]),
          ]
        })
      ],
    ),
    list.map(sources, fn(s) { s.reading }),
  )
}
