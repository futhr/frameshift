import assembly_fixture as fixture
import frameshift_build/assembly
import frameshift_build/assembly/model as m
import frameshift_build/model as error
import gleam/int
import gleam/list
import gleam/string
import gleeunit/should

pub fn canonical_round_trip_and_set_order_test() {
  list.each(fixture.sequences(), fn(value) {
    let assert Ok(bytes) = assembly.encode(value)
    let assert Ok(decoded) = assembly.decode(bytes)
    assembly.encode(decoded) |> should.equal(Ok(bytes))
    assembly.encode(
      m.Assembly(
        ..value,
        instances: list.reverse(value.instances),
        connections: list.reverse(value.connections),
        dependencies: list.reverse(value.dependencies),
      ),
    )
    |> should.equal(Ok(bytes))
    assembly.identity_payload(bytes)
    |> should.equal(Ok("frameshift.build.v1\n" <> bytes))
  })
}

pub fn incomplete_graphs_and_cycles_remain_planning_inputs_test() {
  let value = fixture.assembly(0)
  let cycle = [
    m.Dependency("panel", "controller", "controller"),
    m.Dependency("controller", "panel", "display"),
  ]
  let assert Ok(bytes) =
    assembly.encode(m.Assembly(..value, dependencies: cycle, connections: []))
  let assert Ok(plan) = assembly.decode(bytes)
  list.length(plan.dependencies) |> should.equal(2)
  plan.connections |> should.equal([])
}

pub fn identity_pins_are_unique_exact_and_sorted_test() {
  let value = fixture.assembly(0)
  let assert [first, second] = value.instances
  let duplicate_pin = m.Instance(..second, profile: first.profile)
  let assert Ok(bytes) =
    assembly.encode(m.Assembly(..value, instances: [first, duplicate_pin]))
  assembly.profile_pins(bytes) |> should.equal(Ok([first.profile]))
}

pub fn dangling_references_duplicates_and_bounds_are_refused_test() {
  let value = fixture.assembly(0)
  let assert [first, second] = value.instances
  let assert [edge] = value.connections
  let assert [dependency] = value.dependencies
  assembly.encode(m.Assembly(..value, instances: []))
  |> should.equal(Error(error.InvalidCount))
  assembly.encode(m.Assembly(..value, instances: list.repeat(first, 65)))
  |> should.equal(Error(error.InvalidCount))
  assembly.encode(m.Assembly(..value, instances: [first, first]))
  |> should.equal(Error(error.DuplicateIdentifier))
  assembly.encode(m.Assembly(..value, connections: [edge, edge]))
  |> should.equal(Error(error.DuplicateIdentifier))
  assembly.encode(m.Assembly(..value, dependencies: [dependency, dependency]))
  |> should.equal(Error(error.DuplicateIdentifier))
  assembly.encode(m.Assembly(..value, connections: list.repeat(edge, 257)))
  |> should.equal(Error(error.InvalidCount))
  assembly.encode(
    m.Assembly(..value, dependencies: list.repeat(dependency, 257)),
  )
  |> should.equal(Error(error.InvalidCount))
  assembly.encode(m.Assembly(..value, instances: [first]))
  |> should.equal(Error(error.InvalidReference))
  assembly.encode(
    m.Assembly(..value, instances: [
      m.Instance(..first, profile: "sha256:bad"),
      second,
    ]),
  )
  |> should.equal(Error(error.InvalidIdentity))
}

pub fn scalar_versions_and_intent_limits_are_refused_test() {
  let value = fixture.assembly(0)
  assembly.encode(m.Assembly(..value, schema: 2))
  |> should.equal(Error(error.UnsupportedVersion))
  assembly.encode(m.Assembly(..value, semantics: "latest"))
  |> should.equal(Error(error.UnsupportedSemantics))
  assembly.encode(m.Assembly(..value, class: "video"))
  |> should.equal(Error(error.InvalidEnum))
  let intents = [
    m.Intent(..value.intent, dwell_ms: 0),
    m.Intent(..value.intent, dwell_ms: 604_800_001),
    m.Intent(..value.intent, storage_bytes: 0),
    m.Intent(..value.intent, storage_bytes: 1_099_511_627_777),
    m.Intent(..value.intent, ambient_mc: m.Range(-100_001, 0)),
    m.Intent(..value.intent, ambient_mc: m.Range(100, 99)),
    m.Intent(..value.intent, ambient_mc: m.Range(0, 300_001)),
  ]
  list.each(intents, fn(intent) {
    assembly.encode(m.Assembly(..value, intent:))
    |> should.equal(Error(error.InvalidRange))
  })
  let assert [first, second] = value.instances
  let positions = [
    m.Placement(45, 0, 0, 0),
    m.Placement(0, -1, 0, 0),
    m.Placement(0, 0, 5_000_001, 0),
    m.Placement(0, 0, 0, 5_000_001),
  ]
  list.each(positions, fn(placement) {
    assembly.encode(
      m.Assembly(..value, instances: [m.Instance(..first, placement:), second]),
    )
    |> should.equal(Error(error.InvalidRange))
  })
}

pub fn documented_inclusive_limits_are_accepted_test() {
  let value = fixture.assembly(0)
  let assert [first, second] = value.instances
  let positions = m.Placement(270, 5_000_000, 5_000_000, 5_000_000)
  let intent =
    m.Intent(
      ..value.intent,
      ambient_mc: m.Range(-100_000, 300_000),
      dwell_ms: 604_800_000,
      storage_bytes: 1_099_511_627_776,
    )
  let extras =
    int.range(0, 62, [], fn(acc, i) {
      [m.Instance(..first, id: "extra-" <> int.to_string(i)), ..acc]
    })
  let instances = [m.Instance(..first, placement: positions), second, ..extras]
  let assert Ok(bytes) =
    assembly.encode(m.Assembly(..value, instances:, intent:))
  let assert Ok(decoded) = assembly.decode(bytes)
  list.length(decoded.instances) |> should.equal(64)
}

pub fn exact_wire_mutations_and_resource_limits_test() {
  let assert Ok(bytes) = assembly.encode(fixture.assembly(0))
  let mutations = [
    string.trim(bytes),
    " " <> bytes,
    bytes <> "\n",
    string.replace(bytes, "\"schema\":1", "\"schema\":1.0"),
    string.replace(bytes, "\"schema\":1", "\"schema\":1e0"),
    string.replace(bytes, "\"schema\":1", "\"schema\":1,\"schema\":1"),
    string.replace(bytes, "\"schema\":1", "\"schema\":1,\"artwork\":\"secret\""),
    string.replace(bytes, "\"rotation\":0", "\"rotation\":-0"),
    string.replace(
      bytes,
      "\"storage_bytes\":1000000",
      "\"storage_bytes\":9007199254740993",
    ),
    string.replace(bytes, "\"class\":\"paper\"", "\"class\":\"\\u0070aper\""),
  ]
  list.each(mutations, fn(bytes) { assembly.decode(bytes) |> should.be_error })
  assembly.decode(string.repeat(" ", 262_145))
  |> should.equal(Error(error.TooLarge))
  assembly.decode(string.repeat("[", 17) <> string.repeat("]", 17))
  |> should.equal(Error(error.TooDeep))
}

pub fn generated_corruption_never_acquires_validity_test() {
  let assert Ok(bytes) = assembly.encode(fixture.assembly(0))
  int.range(0, 2048, Nil, fn(_, seed) {
    let offset = seed % string.length(bytes)
    let corrupt =
      string.slice(bytes, 0, offset)
      <> "~"
      <> string.slice(bytes, offset, string.length(bytes))
    // An insertion within a free identifier can form another valid plan, but
    // '~' is forbidden by every string field in this schema.
    assembly.decode(corrupt) |> should.be_error
    Nil
  })
}
