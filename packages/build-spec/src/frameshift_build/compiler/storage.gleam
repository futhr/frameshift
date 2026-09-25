/// Per-controller allocation under the single-store model. Shared devices have
/// no implicit partition, and a selected external store never falls back.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/facts
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{
  type Check, type Input, BuildInput, Check, ProfileInput,
}
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/list
import gleam/option.{type Option, None, Some}

type Allocation {
  Allocation(provider: Option(a.Instance), permitted: Bool, finding: Finding)
}

pub fn evaluate(controller: a.Instance, value: Resolution) -> List(Finding) {
  let allocation = select(controller, value)
  let readings = case allocation.provider {
    None -> []
    Some(provider) -> [facts.component(provider, "storage.capacity", value)]
  }
  let capacity = case allocation.permitted, readings {
    True, [reading] -> finding.interval(reading)
    _, _ -> None
  }
  let base = allocation.finding.check
  [
    allocation.finding,
    finding.at_most(
      Check(
        ..base,
        code: "operation.storage_capacity",
        outcome: Unknown,
        inputs: [BuildInput(["intent", "storage_bytes"]), ..base.inputs],
      ),
      readings,
      "byte",
      finding.constant(value.assembly.intent.storage_bytes),
      capacity,
    ),
  ]
}

fn select(controller: a.Instance, value: Resolution) -> Allocation {
  let selected =
    list.filter(value.assembly.dependencies, fn(d) {
      d.consumer == controller.id && d.role == "storage"
    })
  let inputs = [
    BuildInput(["dependencies"]),
    ProfileInput(controller.id, controller.profile, ["kind"]),
  ]
  let base =
    Check(
      "operation.storage_selection",
      Unknown,
      "multiple_storage_providers",
      [controller.id],
      inputs,
    )
  case selected {
    [] ->
      Allocation(
        Some(controller),
        True,
        finding.explain(
          Check(..base, outcome: Compatible, reason: "integrated_storage"),
          [],
        ),
      )
    [dependency] -> external(controller, dependency, base, value)
    _ ->
      Allocation(
        None,
        False,
        finding.explain(
          Check(
            ..base,
            inputs: list.append(
              inputs,
              list.flat_map(selected, fn(d) {
                provider_input(d.provider, value)
              }),
            ),
          ),
          [],
        ),
      )
  }
}

fn external(
  controller: a.Instance,
  dependency: a.Dependency,
  base: Check,
  value: Resolution,
) -> Allocation {
  let base =
    Check(
      ..base,
      inputs: list.append(
        base.inputs,
        provider_input(dependency.provider, value),
      ),
    )
  case resolution.find_instance(value, dependency.provider) {
    Error(_) ->
      Allocation(
        None,
        False,
        finding.explain(Check(..base, reason: "missing_storage_provider"), []),
      )
    Ok(provider) -> {
      let consumers =
        value.assembly.dependencies
        |> list.filter(fn(d) {
          d.provider == provider.id && d.role == "storage"
        })
        |> list.map(fn(d) { d.consumer })
        |> list.unique
      let #(outcome, reason) = case
        resolution.find_profile(value, provider.profile)
      {
        Error(_) -> #(Unknown, "missing_profile")
        Ok(profile) if profile.kind != "storage" -> #(
          Incompatible,
          "wrong_storage_kind",
        )
        Ok(_) ->
          case list.length(consumers) == 1 {
            True -> #(Compatible, "dedicated_storage")
            False -> #(Unknown, "shared_storage_without_partition")
          }
      }
      Allocation(
        Some(provider),
        outcome == Compatible,
        finding.explain(
          Check(
            ..base,
            outcome:,
            reason:,
            instances: list.unique([controller.id, provider.id, ..consumers]),
          ),
          [],
        ),
      )
    }
  }
}

fn provider_input(id: String, value: Resolution) -> List(Input) {
  case resolution.find_instance(value, id) {
    Error(_) -> [BuildInput(["instances"])]
    Ok(instance) -> [ProfileInput(instance.id, instance.profile, ["kind"])]
  }
}
