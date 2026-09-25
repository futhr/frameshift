import frameshift_build/compiler/evidence
import frameshift_build/compiler/facts
import frameshift_build/compiler/model.{
  BuildInput, LayoutInput, MappingInput, ProfileInput,
}
import frameshift_build/model as p
import frameshift_build/resolution
import gleam/list
import gleeunit/should
import power_fixture

pub fn exact_observations_survive_short_key_collisions_in_stable_order_test() {
  let value = power_fixture.resolved()
  let assert Ok(instance) = resolution.find_instance(value, "controller")
  let first = facts.port(instance, "out", "output.voltage", value)
  let changed = facts.Reading(..first, value: p.KnownRange(1, 2))
  let revision = facts.Reading(..first, profile: "different")
  evidence.readings([first, changed, first, revision, changed])
  |> should.equal([first, changed, revision])
  let inputs = [
    ProfileInput("i", "a", ["b"]),
    ProfileInput("i", "other", ["b"]),
    MappingInput("i", "a", ["b"]),
    MappingInput("i", "other", ["b"]),
    LayoutInput("i", "a", ["b"]),
    LayoutInput("i", "other", ["b"]),
    BuildInput(["a", "b"]),
    BuildInput(["a\u{0}b"]),
  ]
  evidence.inputs(list.append(inputs, list.reverse(inputs)))
  |> should.equal(inputs)
}
