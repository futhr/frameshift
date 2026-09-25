/// Compiler-stage explanations. A list from one stage is not a complete report.
import frameshift_physical.{type Outcome}

pub type Check {
  Check(
    code: String,
    outcome: Outcome,
    reason: String,
    instances: List(String),
    inputs: List(Input),
  )
}

/// Paths are separate identifier segments, not ambiguous dotted strings.
/// Profile inputs always retain the exact content pin from the assembly.
pub type Input {
  BuildInput(path: List(String))
  ProfileInput(instance: String, identity: String, path: List(String))
  MappingInput(instance: String, identity: String, path: List(String))
  LayoutInput(instance: String, identity: String, path: List(String))
}
