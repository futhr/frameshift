import completeness_fixture as fixture
import context_fixture
import frameshift_build/compiler/model.{
  type Input, BuildInput, LayoutInput, MappingInput, ProfileInput,
}
import frameshift_build/compiler/preview.{type Stage}
import frameshift_build/context
import frameshift_physical.{type Outcome, Compatible, Incompatible, Unknown}
import gleam/io
import gleam/json
import load_fixture

pub fn main() {
  let plain = fixture.resolved()
  emit("incomplete", context.Context(plain, [], []))
  let conflict =
    plain
    |> fixture.frame
    |> load_fixture.component(
      "frame",
      load_fixture.number("inner.width", "um", 3000, 3100),
    )
  emit("conflict", context.Context(conflict, [], []))
  let #(assembly, profiles, mappings) = context_fixture.inputs()
  let assert Ok(selected) = context.resolve(assembly, profiles, mappings)
  emit("selected_mappings", selected)
}

fn emit(label: String, context: context.Context) {
  let assert Ok(value) = preview.evaluate(context)
  json.object([
    #("case", json.string(label)),
    #("status", json.string(outcome(value.status))),
    #("stages", json.array(value.stages, stage)),
  ])
  |> json.to_string
  |> io.println
}

fn stage(value: Stage) -> json.Json {
  json.object([
    #("name", json.string(value.name)),
    #(
      "checks",
      json.array(value.findings, fn(finding) {
        let check = finding.check
        json.object([
          #("code", json.string(check.code)),
          #("outcome", json.string(outcome(check.outcome))),
          #("reason", json.string(check.reason)),
          #("instances", json.array(check.instances, json.string)),
          #("inputs", json.array(check.inputs, input)),
        ])
      }),
    ),
  ])
}

fn outcome(value: Outcome) -> String {
  case value {
    Compatible -> "compatible"
    Incompatible -> "incompatible"
    Unknown -> "unknown"
  }
}

fn input(value: Input) -> json.Json {
  case value {
    BuildInput(path) -> reference("build", "", "", path)
    ProfileInput(instance, identity, path) ->
      reference("profile", instance, identity, path)
    MappingInput(instance, identity, path) ->
      reference("mapping", instance, identity, path)
    LayoutInput(instance, identity, path) ->
      reference("layout", instance, identity, path)
  }
}

fn reference(
  kind: String,
  instance: String,
  identity: String,
  path: List(String),
) -> json.Json {
  json.object([
    #("kind", json.string(kind)),
    #("instance", json.string(instance)),
    #("identity", json.string(identity)),
    #("path", json.array(path, json.string)),
  ])
}
