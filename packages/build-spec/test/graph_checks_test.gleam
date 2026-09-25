import frameshift_build/assembly/model as a
import frameshift_build/compiler/graph_checks
import frameshift_build/compiler/model.{type Check}
import frameshift_build/model as p
import frameshift_build/resolution as r
import frameshift_physical as physical
import gleam/list
import gleeunit/should
import graph_fixture

fn evaluate(value: r.Resolution) -> List(Check) {
  let assert Ok(checks) = graph_checks.evaluate(value)
  checks
}

fn outcome(
  checks: List(Check),
  code: String,
  outcome: physical.Outcome,
) -> Bool {
  list.any(checks, fn(check) { check.code == code && check.outcome == outcome })
}

pub fn graph_obligations_include_exact_pins_without_claiming_complete_compatibility_test() {
  let value = graph_fixture.resolved()
  let checks = evaluate(value)
  list.all(checks, fn(v) { v.outcome == physical.Compatible }) |> should.be_true
  list.all(checks, fn(v) { v.inputs != [] || v.code == "power.acyclic" })
  |> should.be_true
  outcome(checks, "dependency.required", physical.Compatible) |> should.be_true
  outcome(checks, "port.required", physical.Compatible) |> should.be_true
}

pub fn missing_profiles_roles_ports_and_unverified_revisions_remain_unknown_test() {
  let value = graph_fixture.resolved()
  let assert [display, controller] = value.profiles
  let partial =
    r.Resolution(..value, profiles: [display], missing: [controller.identity])
  outcome(evaluate(partial), "profile.resolved", physical.Unknown)
  |> should.be_true
  outcome(evaluate(partial), "dependency.required", physical.Unknown)
  |> should.be_true
  outcome(evaluate(partial), "connection.endpoints", physical.Unknown)
  |> should.be_true
  let unverified =
    r.ResolvedProfile(
      ..display,
      profile: p.Profile(..display.profile, part_revision: "unverified"),
    )
  let incomplete =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, dependencies: [], connections: []),
      profiles: [unverified, controller],
    )
  let checks = evaluate(incomplete)
  outcome(checks, "profile.part_revision", physical.Unknown) |> should.be_true
  outcome(checks, "dependency.required", physical.Unknown) |> should.be_true
  outcome(checks, "port.required", physical.Unknown) |> should.be_true
}

pub fn declared_class_and_provider_kind_mismatches_are_incompatible_test() {
  let value = graph_fixture.resolved()
  let assert [display, controller] = value.profiles
  let controller =
    r.ResolvedProfile(
      ..controller,
      profile: p.Profile(
        ..controller.profile,
        classes: ["photo"],
        kind: "power",
      ),
    )
  let checks = evaluate(r.Resolution(..value, profiles: [display, controller]))
  outcome(checks, "profile.class", physical.Incompatible) |> should.be_true
  outcome(checks, "dependency.kind", physical.Incompatible) |> should.be_true
  outcome(checks, "dependency.required", physical.Incompatible)
  |> should.be_true
}

pub fn nonexistent_reversed_mismatched_and_self_ports_are_incompatible_test() {
  let value = graph_fixture.resolved()
  let assert [edge] = value.assembly.connections
  let connections = [
    a.Connection(edge.to, edge.from),
    a.Connection(edge.to, edge.to),
    a.Connection(a.Endpoint("controller", "absent"), edge.to),
  ]
  let checks =
    evaluate(
      r.Resolution(
        ..value,
        assembly: a.Assembly(..value.assembly, connections:),
      ),
    )
  outcome(checks, "connection.direction", physical.Incompatible)
  |> should.be_true
  outcome(checks, "connection.instances", physical.Incompatible)
  |> should.be_true
  outcome(checks, "connection.endpoints", physical.Incompatible)
  |> should.be_true
  let assert [display, controller] = value.profiles
  let assert [port] = controller.profile.ports
  let controller =
    r.ResolvedProfile(
      ..controller,
      profile: p.Profile(..controller.profile, ports: [
        p.Port(..port, kind: "signal"),
      ]),
    )
  outcome(
    evaluate(r.Resolution(..value, profiles: [display, controller])),
    "connection.kind",
    physical.Incompatible,
  )
  |> should.be_true
}

pub fn adapter_power_and_role_cycles_cannot_disappear_in_connected_graphs_test() {
  let value = graph_fixture.resolved()
  let assert [display, controller] = value.profiles
  let assert [sink] = display.profile.ports
  let assert [source] = controller.profile.ports
  let display =
    r.ResolvedProfile(
      ..display,
      profile: p.Profile(..display.profile, ports: [sink, source]),
    )
  let controller =
    r.ResolvedProfile(
      ..controller,
      profile: p.Profile(..controller.profile, ports: [sink, source]),
    )
  let reverse =
    a.Connection(a.Endpoint("panel", "out"), a.Endpoint("controller", "dc"))
  let plan =
    a.Assembly(
      ..value.assembly,
      connections: [reverse, ..value.assembly.connections],
      dependencies: [
        a.Dependency("controller", "panel", "display"),
        ..value.assembly.dependencies
      ],
    )
  let checks =
    evaluate(
      r.Resolution(..value, assembly: plan, profiles: [display, controller]),
    )
  outcome(checks, "power.acyclic", physical.Incompatible) |> should.be_true
  outcome(checks, "dependency.acyclic", physical.Incompatible) |> should.be_true
  let assert Ok(power) = list.find(checks, fn(v) { v.code == "power.acyclic" })
  power.instances |> should.equal(["controller", "panel"])
}
