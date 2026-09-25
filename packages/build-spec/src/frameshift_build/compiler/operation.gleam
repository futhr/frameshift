/// Required runtime declarations and configured budgets. Executable mapping,
/// complete artifact footprint and installed receiver admission are separate.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/facts
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{BuildInput, Check, ProfileInput}
import frameshift_build/compiler/storage
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/list

pub fn evaluate(value: Resolution) -> List(Finding) {
  let classified =
    list.map(value.assembly.instances, fn(i) {
      #(i, resolution.find_profile(value, i.profile))
    })
  let known =
    list.filter_map(classified, fn(entry) {
      case entry.1 {
        Ok(profile) -> Ok(#(entry.0, profile.kind))
        Error(_) -> Error(Nil)
      }
    })
  let unknown =
    list.filter_map(classified, fn(entry) {
      case entry.1 {
        Ok(_) -> Error(Nil)
        Error(_) ->
          Ok(
            finding.explain(
              Check(
                "operation.classification",
                Unknown,
                "missing_profile",
                [entry.0.id],
                [ProfileInput(entry.0.id, entry.0.profile, ["kind"])],
              ),
              [],
            ),
          )
      }
    })
  let controllers =
    list.filter(known, fn(entry) { entry.1 == "controller" })
    |> list.map(fn(entry) { entry.0 })
  let displays =
    list.filter(known, fn(entry) { entry.1 == "display" })
    |> list.map(fn(entry) { entry.0 })
  list.flatten([
    [
      presence("controller", controllers, value),
      presence("display", displays, value),
    ],
    unknown,
    list.flat_map(controllers, fn(i) {
      list.append(contracts(i, value), storage.evaluate(i, value))
    }),
    list.flat_map(list.append(controllers, displays), dwell(_, value)),
  ])
}

fn presence(
  kind: String,
  instances: List(a.Instance),
  value: Resolution,
) -> Finding {
  let #(outcome, reason) = case instances {
    [] -> #(Unknown, "missing_" <> kind)
    _ -> #(Compatible, "role_present")
  }
  finding.explain(
    Check(
      "operation." <> kind,
      outcome,
      reason,
      list.map(instances, fn(i) { i.id }),
      [
        BuildInput(["instances"]),
        ..list.map(value.assembly.instances, fn(i) {
          ProfileInput(i.id, i.profile, ["kind"])
        })
      ],
    ),
    [],
  )
}

fn contracts(instance: a.Instance, value: Resolution) -> List(Finding) {
  let intent = value.assembly.intent
  list.map(
    [
      #("artifact", intent.artifact),
      #("firmware", intent.firmware),
      #("protocol", intent.protocol),
    ],
    fn(selection) {
      let reading = facts.component(instance, selection.0 <> ".contract", value)
      let #(outcome, reason) = case facts.terms(reading) {
        Error(_) -> #(
          Unknown,
          finding.unknown_reason([reading], "incomplete_runtime_contract"),
        )
        Ok(terms) ->
          case list.contains(terms, selection.1) {
            True -> #(Compatible, "runtime_contract_declared")
            False -> #(Incompatible, "runtime_contract_not_declared")
          }
      }
      finding.explain(
        Check("operation." <> selection.0, outcome, reason, [instance.id], [
          BuildInput(["intent", selection.0]),
          ProfileInput(instance.id, instance.profile, ["kind"]),
        ]),
        [reading],
      )
      |> finding.with_terms(case outcome {
        Compatible -> [selection.1]
        _ -> []
      })
    },
  )
}

fn dwell(instance: a.Instance, value: Resolution) -> List(Finding) {
  let minimum = facts.component(instance, "refresh.minimum", value)
  let maximum = facts.component(instance, "refresh.maximum", value)
  let chosen = finding.constant(value.assembly.intent.dwell_ms)
  let base =
    Check(
      "operation.dwell_minimum",
      Unknown,
      "incomplete_dwell_limit",
      [instance.id],
      [
        BuildInput(["intent", "dwell_ms"]),
        ProfileInput(instance.id, instance.profile, ["kind"]),
      ],
    )
  [
    finding.at_most(base, [minimum], "ms", finding.interval(minimum), chosen),
    finding.at_most(
      Check(..base, code: "operation.dwell_maximum"),
      [maximum],
      "ms",
      chosen,
      finding.interval(maximum),
    ),
  ]
}
