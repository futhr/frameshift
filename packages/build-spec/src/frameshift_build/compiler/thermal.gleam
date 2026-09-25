/// Declared local-ambient and enclosure heat constraints. Qualified assembly
/// evidence must separately cover exact placement, ventilation and load scope.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/declarations
import frameshift_build/compiler/enclosure
import frameshift_build/compiler/facts
import frameshift_build/compiler/finding.{type Finding, Finding}
import frameshift_build/compiler/model.{type Input, BuildInput, Check}
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Incompatible, Interval, Unknown}
import gleam/list
import gleam/option.{None, Some}

pub fn evaluate(value: Resolution) -> List(Finding) {
  let #(selected, frame) = enclosure.select(value)
  let topology =
    Finding(
      ..selected,
      check: Check(..selected.check, code: "thermal.enclosure"),
    )
  let contributors =
    list.filter(value.assembly.instances, fn(i) { i.location != "external" })
  let inputs = [BuildInput(["intent", "ambient_mc"]), BuildInput(["instances"])]
  let heat = list.map(contributors, facts.component(_, "heat.maximum", value))
  let scopes =
    list.map(contributors, facts.component(_, "assembly.thermal", value))
  let base =
    Check(
      "thermal.scope",
      Unknown,
      "incomplete_contract",
      list.map(contributors, fn(i) { i.id }),
      inputs,
    )
  let scope = declarations.agreement(base, scopes)
  let scope = case frame, scope.check.outcome {
    None, outcome if outcome != Incompatible ->
      Finding(
        ..scope,
        check: Check(
          ..scope.check,
          outcome: Unknown,
          reason: selected.check.reason,
        ),
        common_terms: [],
      )
    _, _ -> scope
  }
  let bounds = case frame {
    None ->
      [
        finding.within(
          Check(..base, code: "thermal.ambient", reason: selected.check.reason),
          [],
          "mc",
          ambient(value),
          None,
        ),
        finding.at_most(
          Check(..base, code: "thermal.capacity", reason: selected.check.reason),
          heat,
          "mw",
          finding.sum(list.map(heat, finding.interval)),
          None,
        ),
      ]
      |> list.map(fn(f) {
        Finding(..f, check: Check(..f.check, reason: selected.check.reason))
      })
    Some(frame) -> {
      let ambient_scope = facts.component(frame, "thermal.ambient", value)
      let capacity = facts.component(frame, "thermal.capacity", value)
      [
        finding.within(
          Check(
            ..base,
            code: "thermal.ambient",
            reason: "incomplete_thermal_ambient",
          ),
          [ambient_scope],
          "mc",
          ambient(value),
          finding.interval(ambient_scope),
        ),
        finding.at_most(
          Check(
            ..base,
            code: "thermal.capacity",
            reason: "incomplete_heat_budget",
          ),
          [capacity, ..heat],
          "mw",
          finding.sum(list.map(heat, finding.interval)),
          finding.interval(capacity),
        ),
      ]
    }
  }
  list.flatten([
    [topology],
    list.map(value.assembly.instances, operating(_, value)),
    [scope],
    bounds,
  ])
}

fn ambient(value: Resolution) {
  let ambient = value.assembly.intent.ambient_mc
  Some(Interval(ambient.minimum, ambient.maximum))
}

fn operating(instance: a.Instance, value: Resolution) -> Finding {
  let permitted = facts.component(instance, "temperature.operating", value)
  let #(required, readings) = case instance.location {
    "internal" -> {
      let rise = facts.component(instance, "temperature.ambient_rise", value)
      let required = case finding.interval(rise), ambient(value) {
        Some(rise), Some(ambient) ->
          Some(Interval(
            ambient.minimum + rise.minimum,
            ambient.maximum + rise.maximum,
          ))
        _, _ -> None
      }
      #(required, [rise, permitted])
    }
    _ -> #(ambient(value), [permitted])
  }
  finding.within(
    Check(
      "thermal.operating",
      Unknown,
      "incomplete_local_ambient",
      [instance.id],
      placement_inputs(instance),
    ),
    readings,
    "mc",
    required,
    finding.interval(permitted),
  )
}

fn placement_inputs(instance: a.Instance) -> List(Input) {
  [
    BuildInput(["intent", "ambient_mc"]),
    BuildInput(["instances", instance.id, "location"]),
    BuildInput(["instances", instance.id, "placement"]),
  ]
}
