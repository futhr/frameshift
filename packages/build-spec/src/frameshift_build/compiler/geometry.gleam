/// Enclosure fit and service separation only. Aperture and complete assembly
/// qualification are distinct stages; these findings never grant admission.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/enclosure
import frameshift_build/compiler/envelope.{type Envelope}
import frameshift_build/compiler/facts
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{BuildInput, Check}
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Compatible, Unknown}
import gleam/list
import gleam/option.{type Option, None, Some}

pub fn evaluate(value: Resolution) -> List(Finding) {
  let #(topology, frame) = enclosure.select(value)
  let internal =
    value.assembly.instances
    |> list.filter(fn(instance) { instance.location == "internal" })
    |> list.map(envelope.read(_, value))
  list.flatten([
    [topology],
    list.flat_map(internal, fit(_, frame, value)),
    pairs(internal),
  ])
}

fn fit(
  part: Envelope,
  frame: Option(a.Instance),
  value: Resolution,
) -> List(Finding) {
  list.flat_map(part.axes, fn(axis) {
    let cavity = case frame {
      Some(frame) -> Some(facts.component(frame, inner_key(axis.name), value))
      None -> None
    }
    let available = case cavity {
      Some(reading) -> finding.interval(reading)
      None -> None
    }
    let cavity_readings = case cavity {
      Some(reading) -> [reading]
      None -> []
    }
    let base =
      Check(
        "geometry.fit." <> axis.name <> ".negative",
        Unknown,
        "unavailable_cavity",
        [part.instance.id],
        envelope.inputs(part),
      )
    let upper =
      Check(..base, code: "geometry.fit." <> axis.name <> ".positive", inputs: [
        BuildInput(["instances"]),
        ..base.inputs
      ])
    [
      finding.at_most(
        base,
        [axis.negative],
        "um",
        finding.interval(axis.negative),
        finding.constant(axis.position),
      ),
      finding.at_most(
        upper,
        [axis.outline, axis.positive, ..cavity_readings],
        "um",
        finding.sum([
          finding.constant(axis.position),
          finding.interval(axis.outline),
          finding.interval(axis.positive),
        ]),
        available,
      ),
    ]
  })
}

fn inner_key(axis: String) -> String {
  case axis {
    "x" -> "inner.width"
    "y" -> "inner.height"
    _ -> "inner.depth"
  }
}

fn pairs(parts: List(Envelope)) -> List(Finding) {
  case parts {
    [] -> []
    [first, ..rest] ->
      list.append(list.map(rest, separation(first, _)), pairs(rest))
  }
}

fn separation(first: Envelope, second: Envelope) -> Finding {
  let readings =
    list.append(envelope.readings(first), envelope.readings(second))
  let #(outcome, reason) = case envelope.separated(first, second) {
    True -> #(Compatible, "separated_service_envelopes")
    False -> #(
      Unknown,
      finding.unknown_reason(readings, "overlapping_service_envelopes"),
    )
  }
  finding.explain(
    Check(
      "geometry.separation",
      outcome,
      reason,
      [first.instance.id, second.instance.id],
      list.append(envelope.inputs(first), envelope.inputs(second)),
    ),
    readings,
  )
}
