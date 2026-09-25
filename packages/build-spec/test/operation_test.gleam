import frameshift_build/assembly/model as a
import frameshift_build/compiler/finding.{type Finding, AtMost, Measurement}
import frameshift_build/compiler/model.{BuildInput, ProfileInput}
import frameshift_build/compiler/operation
import frameshift_build/model as p
import frameshift_build/resolution as r
import frameshift_physical.{Compatible, Incompatible, Interval, Unknown}
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import load_fixture
import operation_fixture as fixture
import power_fixture

fn check(value: r.Resolution, code: String, id: String) -> Finding {
  let assert Ok(f) =
    list.find(operation.evaluate(value), fn(f) {
      f.check.code == code && list.first(f.check.instances) == Ok(id)
    })
  f
}

fn dwell(value: r.Resolution, ms: Int) -> r.Resolution {
  r.Resolution(
    ..value,
    assembly: a.Assembly(
      ..value.assembly,
      intent: a.Intent(..value.assembly.intent, dwell_ms: ms),
    ),
  )
}

pub fn selected_runtime_contracts_dwell_and_integrated_storage_retain_sources_test() {
  let value = fixture.resolved()
  list.all(operation.evaluate(value), fn(f) { f.check.outcome == Compatible })
  |> should.be_true
  check(value, "operation.artifact", "controller").common_terms
  |> should.equal([value.assembly.intent.artifact])
  let storage = check(value, "operation.storage_capacity", "controller")
  storage.measurement
  |> should.equal(
    Some(Measurement(
      "byte",
      AtMost,
      Some(Interval(1_000_000, 1_000_000)),
      Some(Interval(1_000_000, 1_000_000)),
    )),
  )
  list.contains(storage.check.inputs, BuildInput(["intent", "storage_bytes"]))
  |> should.be_true
  check(value, "operation.storage_selection", "controller").check.reason
  |> should.equal("integrated_storage")
}

pub fn missing_roles_and_unresolved_profiles_are_explicit_test() {
  let value = fixture.resolved()
  let missing = r.Resolution(..value, profiles: [])
  let findings = operation.evaluate(missing)
  list.count(findings, fn(f) { f.check.code == "operation.classification" })
  |> should.equal(2)
  list.all(findings, fn(f) { f.check.outcome == Unknown }) |> should.be_true
  let wrong =
    r.Resolution(
      ..value,
      profiles: list.map(value.profiles, fn(profile) {
        r.ResolvedProfile(
          ..profile,
          profile: p.Profile(..profile.profile, kind: "frame"),
        )
      }),
    )
  operation.evaluate(wrong)
  |> list.map(fn(f) { f.check.reason })
  |> should.equal(["missing_controller", "missing_display"])
}

pub fn missing_or_excluded_contract_does_not_match_a_family_label_test() {
  let value =
    fixture.resolved()
    |> load_fixture.component(
      "controller",
      power_fixture.terms("firmware.contract", ["different"]),
    )
    |> load_fixture.component(
      "controller",
      p.Fact("protocol.contract", [], "token", p.Missing),
    )
    |> load_fixture.component(
      "controller",
      power_fixture.terms("protocol.family", ["fixture-protocol"]),
    )
  check(value, "operation.firmware", "controller").check.outcome
  |> should.equal(Incompatible)
  check(value, "operation.protocol", "controller").check.outcome
  |> should.equal(Unknown)
  check(value, "operation.firmware", "controller").common_terms
  |> should.equal([])
}

pub fn dwell_uses_the_largest_minimum_and_smallest_maximum_test() {
  let value = fixture.resolved()
  check(dwell(value, 1999), "operation.dwell_minimum", "panel").check.outcome
  |> should.equal(Incompatible)
  check(dwell(value, 2000), "operation.dwell_minimum", "panel").check.outcome
  |> should.equal(Compatible)
  check(dwell(value, 3_600_000), "operation.dwell_maximum", "panel").check.outcome
  |> should.equal(Compatible)
  check(dwell(value, 3_600_001), "operation.dwell_maximum", "panel").check.outcome
  |> should.equal(Incompatible)
  let zero =
    load_fixture.component(
      value,
      "panel",
      load_fixture.number("refresh.maximum", "ms", 0, 0),
    )
  check(zero, "operation.dwell_maximum", "panel").check.outcome
  |> should.equal(Incompatible)
}

pub fn recommendations_neither_replace_hard_limits_nor_reject_overrides_test() {
  let value =
    fixture.resolved()
    |> load_fixture.component(
      "panel",
      load_fixture.number(
        "refresh.recommended_minimum",
        "ms",
        604_800_000,
        604_800_000,
      ),
    )
    |> load_fixture.component(
      "panel",
      load_fixture.number("refresh.recommended_maximum", "ms", 1, 1),
    )
    |> load_fixture.component(
      "panel",
      load_fixture.number(
        "refresh.energy_recommended",
        "ms",
        604_800_000,
        604_800_000,
      ),
    )
  list.all(operation.evaluate(value), fn(f) { f.check.outcome == Compatible })
  |> should.be_true
  let missing =
    load_fixture.component(
      value,
      "panel",
      p.Fact("refresh.minimum", [], "ms", p.Missing),
    )
  check(missing, "operation.dwell_minimum", "panel").check.reason
  |> should.equal("missing_fact")
  let maximum =
    load_fixture.component(
      value,
      "panel",
      p.Fact("refresh.maximum", [], "ms", p.Missing),
    )
  check(maximum, "operation.dwell_maximum", "panel").check.outcome
  |> should.equal(Unknown)
}

pub fn external_storage_selection_never_falls_back_to_integrated_capacity_test() {
  let value = fixture.resolved() |> fixture.external
  check(value, "operation.storage_selection", "controller").check.reason
  |> should.equal("dedicated_storage")
  let assert Ok(storage) = r.find_instance(value, "storage")
  let capacity = check(value, "operation.storage_capacity", "controller")
  list.contains(
    capacity.check.inputs,
    ProfileInput("storage", storage.profile, ["facts", "storage.capacity"]),
  )
  |> should.be_true
  let small =
    load_fixture.component(
      value,
      "storage",
      load_fixture.number("storage.capacity", "byte", 999_999, 5_000_000),
    )
  check(small, "operation.storage_capacity", "controller").check.outcome
  |> should.equal(Incompatible)
  let missing =
    load_fixture.component(
      value,
      "storage",
      p.Fact("storage.capacity", [], "byte", p.Missing),
    )
  check(missing, "operation.storage_capacity", "controller").check.outcome
  |> should.equal(Unknown)
  let absent =
    r.Resolution(
      ..value,
      profiles: list.filter(value.profiles, fn(p) {
        p.identity != storage.profile
      }),
    )
  check(absent, "operation.storage_selection", "controller").check.reason
  |> should.equal("missing_profile")
}

pub fn wrong_provider_kind_and_multiple_stores_do_not_become_a_pool_test() {
  let value = fixture.resolved() |> fixture.external
  let wrong =
    r.Resolution(
      ..value,
      profiles: list.map(value.profiles, fn(profile) {
        case profile.profile.kind == "storage" {
          True ->
            r.ResolvedProfile(
              ..profile,
              profile: p.Profile(..profile.profile, kind: "power"),
            )
          False -> profile
        }
      }),
    )
  check(wrong, "operation.storage_selection", "controller").check.outcome
  |> should.equal(Incompatible)
  let assert Some(capacity) =
    check(wrong, "operation.storage_capacity", "controller").measurement
  capacity.available |> should.equal(None)
  let assert Ok(storage) = r.find_instance(value, "storage")
  let other = a.Instance(..storage, id: "storage-2")
  let multiple =
    r.Resolution(
      ..value,
      assembly: a.Assembly(
        ..value.assembly,
        instances: [other, ..value.assembly.instances],
        dependencies: [
          a.Dependency("controller", "storage-2", "storage"),
          ..value.assembly.dependencies
        ],
      ),
    )
    |> load_fixture.canonical
  check(multiple, "operation.storage_selection", "controller").check.reason
  |> should.equal("multiple_storage_providers")
  check(multiple, "operation.storage_capacity", "controller").check.outcome
  |> should.equal(Unknown)
}

pub fn shared_store_is_unknown_but_separate_instances_of_one_profile_are_independent_test() {
  let value = fixture.resolved() |> fixture.external
  let assert Ok(controller) = r.find_instance(value, "controller")
  let assert Ok(storage) = r.find_instance(value, "storage")
  let other = a.Instance(..controller, id: "controller-2")
  let shared =
    r.Resolution(
      ..value,
      assembly: a.Assembly(
        ..value.assembly,
        instances: [other, ..value.assembly.instances],
        dependencies: [
          a.Dependency("controller-2", "storage", "storage"),
          ..value.assembly.dependencies
        ],
      ),
    )
    |> load_fixture.canonical
  list.each(["controller", "controller-2"], fn(id) {
    check(shared, "operation.storage_selection", id).check.reason
    |> should.equal("shared_storage_without_partition")
    check(shared, "operation.storage_capacity", id).check.outcome
    |> should.equal(Unknown)
  })
  let separate =
    r.Resolution(
      ..shared,
      assembly: a.Assembly(
        ..shared.assembly,
        instances: [
          a.Instance(..storage, id: "storage-2"),
          ..shared.assembly.instances
        ],
        dependencies: list.map(shared.assembly.dependencies, fn(d) {
          case d.consumer == "controller-2" {
            True -> a.Dependency(..d, provider: "storage-2")
            False -> d
          }
        }),
      ),
    )
    |> load_fixture.canonical
  list.each(["controller", "controller-2"], fn(id) {
    check(separate, "operation.storage_capacity", id).check.outcome
    |> should.equal(Compatible)
  })
}

pub fn maximum_storage_and_planning_dwell_remain_exact_test() {
  let value =
    fixture.resolved()
    |> load_fixture.component(
      "controller",
      load_fixture.number(
        "storage.capacity",
        "byte",
        1_099_511_627_776,
        1_099_511_627_776,
      ),
    )
    |> load_fixture.component(
      "panel",
      load_fixture.number("refresh.maximum", "ms", 604_800_000, 604_800_000),
    )
    |> dwell(604_800_000)
  let value =
    r.Resolution(
      ..value,
      assembly: a.Assembly(
        ..value.assembly,
        intent: a.Intent(
          ..value.assembly.intent,
          storage_bytes: 1_099_511_627_776,
        ),
      ),
    )
    |> load_fixture.canonical
  list.all(operation.evaluate(value), fn(f) { f.check.outcome == Compatible })
  |> should.be_true
  let assert Some(capacity) =
    check(value, "operation.storage_capacity", "controller").measurement
  capacity.required
  |> should.equal(Some(Interval(1_099_511_627_776, 1_099_511_627_776)))
  let short =
    load_fixture.component(
      value,
      "controller",
      load_fixture.number(
        "storage.capacity",
        "byte",
        1_099_511_627_775,
        1_099_511_627_776,
      ),
    )
  check(short, "operation.storage_capacity", "controller").check.outcome
  |> should.equal(Incompatible)
}
