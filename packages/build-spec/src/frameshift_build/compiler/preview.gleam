/// Pure v1 planning preview. It retains every implemented frame check, but
/// cannot grant physical, runtime, evidence or purchasing admission.
import frameshift_build/compiler/artifacts
import frameshift_build/compiler/completeness
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/geometry
import frameshift_build/compiler/graph_checks
import frameshift_build/compiler/mounting
import frameshift_build/compiler/operation
import frameshift_build/compiler/power_contracts
import frameshift_build/compiler/power_interfaces
import frameshift_build/compiler/power_loads
import frameshift_build/compiler/signal_routes
import frameshift_build/compiler/signals
import frameshift_build/compiler/thermal
import frameshift_build/compiler/viewing
import frameshift_build/context.{type Context}
import frameshift_build/model.{type Refusal}
import frameshift_physical.{type Outcome, Incompatible, Unknown}
import gleam/list
import gleam/result

pub type Stage {
  Stage(name: String, findings: List(Finding))
}

pub type Preview {
  Preview(status: Outcome, stages: List(Stage))
}

pub fn evaluate(context: Context) -> Result(Preview, Refusal) {
  let value = context.resolution
  use graph <- result.try(graph_checks.evaluate(value))
  let completeness_checks = completeness.evaluate(value)
  let geometry_checks = geometry.evaluate(value)
  let viewing_checks = viewing.evaluate(value)
  let power_interface_checks = power_interfaces.evaluate(value)
  let power_load_checks = power_loads.evaluate(value)
  use power_contract_checks <- result.try(power_contracts.evaluate(value))
  let thermal_checks = thermal.evaluate(value)
  use mounting_checks <- result.try(mounting.evaluate(value))
  use signal_checks <- result.try(signals.evaluate(value))
  use routes <- result.try(signal_routes.evaluate(
    value,
    context.route_mappings(context),
  ))
  let operation_checks = operation.evaluate(value)
  use artifact_checks <- result.try(artifacts.evaluate(value, context.layouts))
  let stages = [
    Stage("graph", list.map(graph, fn(check) { finding.explain(check, []) })),
    Stage("completeness", completeness_checks),
    Stage("geometry", geometry_checks),
    Stage("viewing", viewing_checks),
    Stage("power_interfaces", power_interface_checks),
    Stage("power_loads", power_load_checks),
    Stage("power_contracts", power_contract_checks),
    Stage("thermal", thermal_checks),
    Stage("mounting", mounting_checks),
    Stage("signals", signal_checks),
    Stage("signal_routes", routes),
    Stage("operation", operation_checks),
    Stage("artifacts", artifact_checks),
  ]
  let incompatible =
    list.any(stages, fn(stage) {
      list.any(stage.findings, fn(f) { f.check.outcome == Incompatible })
    })
  Ok(Preview(
    case incompatible {
      True -> Incompatible
      False -> Unknown
    },
    stages,
  ))
}
