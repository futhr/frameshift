/// A display's explicit runtime owner. This declaration cannot prove its route.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{
  type Check, type Input, BuildInput, Check, ProfileInput,
}
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/list
import gleam/option.{type Option, None, Some}

pub fn controller(
  display: a.Instance,
  value: Resolution,
) -> #(Finding, Option(a.Instance)) {
  let owners =
    list.filter(value.assembly.dependencies, fn(d) {
      d.consumer == display.id && d.role == "controller"
    })
  let inputs = [
    BuildInput(["dependencies"]),
    ProfileInput(display.id, display.profile, ["kind"]),
    ..list.flat_map(owners, fn(d) { provider_inputs(d.provider, value) })
  ]
  let base =
    Check(
      "complete.controller_owner",
      Unknown,
      "missing_controller_owner",
      [display.id],
      inputs,
    )
  case owners {
    [] -> #(finding.explain(base, []), None)
    [owner] -> resolve(display, owner.provider, base, value)
    _ -> #(
      finding.explain(Check(..base, reason: "multiple_controller_owners"), []),
      None,
    )
  }
}

fn resolve(
  display: a.Instance,
  id: String,
  base: Check,
  value: Resolution,
) -> #(Finding, Option(a.Instance)) {
  let base = Check(..base, instances: list.unique([display.id, id]))
  let provider = resolution.find_instance(value, id)
  let #(outcome, reason) = case id == display.id, provider {
    True, _ -> #(Incompatible, "self_controller_owner")
    False, Error(_) -> #(Unknown, "missing_controller_instance")
    False, Ok(instance) ->
      case resolution.find_profile(value, instance.profile) {
        Error(_) -> #(Unknown, "missing_profile")
        Ok(profile) if profile.kind == "controller" -> #(
          Compatible,
          "controller_owner_declared",
        )
        Ok(_) -> #(Incompatible, "wrong_controller_kind")
      }
  }
  #(
    finding.explain(Check(..base, outcome:, reason:), []),
    case provider, outcome {
      Ok(instance), Compatible -> Some(instance)
      _, _ -> None
    },
  )
}

fn provider_inputs(id: String, value: Resolution) -> List(Input) {
  case resolution.find_instance(value, id) {
    Error(_) -> [BuildInput(["instances"])]
    Ok(instance) -> [ProfileInput(instance.id, instance.profile, ["kind"])]
  }
}
