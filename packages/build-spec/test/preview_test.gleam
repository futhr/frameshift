import completeness_fixture as fixture
import frameshift_build/compiler/artifact_layout.{Layout}
import frameshift_build/compiler/preview
import frameshift_build/context
import frameshift_build/model as p
import frameshift_physical.{Incompatible, Unknown}
import gleam/list
import gleeunit/should
import layout_fixture
import load_fixture
import route_fixture

pub fn preview_runs_all_frame_stages_and_keeps_incomplete_plans_unadmitted_test() {
  let value = fixture.resolved()
  let assert Ok(result) = preview.evaluate(context.Context(value, [], []))
  list.map(result.stages, fn(stage) { stage.name })
  |> should.equal([
    "graph",
    "completeness",
    "geometry",
    "viewing",
    "power_interfaces",
    "power_loads",
    "power_contracts",
    "thermal",
    "mounting",
    "signals",
    "signal_routes",
    "operation",
    "artifacts",
  ])
  result.status |> should.equal(Unknown)
  let assert Ok(artifacts) =
    list.find(result.stages, fn(stage) { stage.name == "artifacts" })
  list.any(artifacts.findings, fn(f) {
    f.check.code == "artifact.assignment" && f.check.outcome == Unknown
  })
  |> should.be_true
}

pub fn known_physical_conflict_is_visible_with_its_exact_inputs_test() {
  let value =
    fixture.resolved()
    |> fixture.frame
    |> load_fixture.component(
      "frame",
      load_fixture.number("inner.width", "um", 3000, 3100),
    )
  let assert Ok(result) = preview.evaluate(context.Context(value, [], []))
  result.status |> should.equal(Incompatible)
  let assert Ok(stage) =
    list.find(result.stages, fn(stage) { stage.name == "completeness" })
  let assert Ok(finding) =
    list.find(stage.findings, fn(f) { f.check.code == "complete.cavity.width" })
  finding.check.outcome |> should.equal(Incompatible)
  { finding.check.inputs != [] } |> should.be_true
  list.length(finding.readings) |> should.equal(2)
}

pub fn invalid_layout_refuses_the_entire_preview_test() {
  let value = fixture.resolved()
  let layout = Layout("invalid", layout_fixture.document(0))
  preview.evaluate(context.Context(value, [], [layout]))
  |> should.equal(Error(p.InvalidIdentity))
}

pub fn maximum_instance_chain_completes_all_stages_without_dropping_units_test() {
  let value = route_fixture.chain(62)
  let assert Ok(result) = preview.evaluate(context.Context(value, [], []))
  list.length(value.assembly.instances) |> should.equal(64)
  list.length(result.stages) |> should.equal(13)
  let assert Ok(stage) =
    list.find(result.stages, fn(stage) { stage.name == "completeness" })
  list.count(stage.findings, fn(f) { f.check.code == "complete.outline.depth" })
  |> should.equal(64)
}
