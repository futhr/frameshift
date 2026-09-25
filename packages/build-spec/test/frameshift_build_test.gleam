import frameshift_build as build
import frameshift_build/model as m
import gleam/int
import gleam/list
import gleam/string
import gleeunit
import profile_fixture as fixture

pub fn main() {
  gleeunit.main()
}

pub fn round_trip_and_order_test() {
  list.each(fixture.sequences(), fn(profile) {
    let assert Ok(bytes) = build.encode(profile)
    let assert Ok(restored) = build.decode(bytes)
    assert build.encode(restored) == Ok(bytes)
    let permuted =
      m.Profile(
        ..profile,
        facts: list.reverse(profile.facts),
        requires: list.reverse(profile.requires),
      )
    assert build.encode(permuted) == Ok(bytes)
    assert build.identity_payload(bytes)
      == Ok("frameshift.profile.v1\n" <> bytes)
  })
}

pub fn unknown_conflicting_and_tokens_round_trip_test() {
  let source2 = m.Source(..fixture.source(), locator: "contradiction")
  let facts = [
    m.Fact("missing", [], "um", m.Missing),
    m.Fact("conflict", [fixture.source(), source2], "mc", m.Conflicting),
    m.Fact("protocol", [fixture.source()], "token", m.KnownTerms(["v2", "v1"])),
  ]
  let assert Ok(bytes) = build.encode(m.Profile(..fixture.profile(0), facts:))
  let assert Ok(profile) = build.decode(bytes)
  assert build.encode(profile) == Ok(bytes)
  assert string.contains(bytes, "\"terms\":[\"v1\",\"v2\"]")
}

pub fn source_and_value_invariants_test() {
  let sourced = m.Fact("width", [fixture.source()], "um", m.KnownRange(1, 2))
  assert build.encode(fixture.with_fact(m.Fact(..sourced, sources: [])))
    == Error(m.InvalidCount)
  assert build.encode(fixture.with_fact(m.Fact(..sourced, value: m.Missing)))
    == Error(m.InvalidCount)
  assert build.encode(fixture.with_fact(m.Fact(..sourced, value: m.Conflicting)))
    == Error(m.InvalidCount)
  assert build.encode(fixture.with_fact(
      m.Fact(..sourced, sources: [fixture.source(), fixture.source()]),
    ))
    == Error(m.DuplicateIdentifier)
  assert build.encode(fixture.with_fact(m.Fact(..sourced, unit: "token")))
    == Error(m.InvalidFact)
  assert build.encode(fixture.with_fact(
      m.Fact(..sourced, value: m.KnownTerms(["one"])),
    ))
    == Error(m.InvalidEnum)
  assert build.encode(fixture.with_fact(m.Fact(..sourced, unit: "metres")))
    == Error(m.InvalidEnum)
  assert build.encode(fixture.with_fact(
      m.Fact(..sourced, sources: [
        m.Source(..fixture.source(), digest: string.repeat("A", 64)),
      ]),
    ))
    == Error(m.InvalidSource)
}

pub fn numeric_limits_test() {
  let units = [
    #("um", 0, 5_000_000),
    #("mv", 0, 300_000),
    #("ma", 0, 100_000),
    #("mw", 0, 1_000_000),
    #("g", 0, 100_000),
    #("mc", -100_000, 300_000),
    #("byte", 0, 1_099_511_627_776),
    #("ms", 0, 604_800_000),
    #("count", 0, 1_000_000),
  ]
  list.each(units, fn(unit) {
    let fact =
      m.Fact(
        "property",
        [fixture.source()],
        unit.0,
        m.KnownRange(unit.1, unit.2),
      )
    let assert Ok(bytes) = build.encode(fixture.with_fact(fact))
    let assert Ok(_) = build.decode(bytes)
    assert build.encode(fixture.with_fact(
        m.Fact(..fact, value: m.KnownRange(unit.1 - 1, unit.2)),
      ))
      == Error(m.InvalidRange)
    assert build.encode(fixture.with_fact(
        m.Fact(..fact, value: m.KnownRange(unit.1, unit.2 + 1)),
      ))
      == Error(m.InvalidRange)
    assert build.encode(fixture.with_fact(
        m.Fact(..fact, value: m.KnownRange(2, 1)),
      ))
      == Error(m.InvalidRange)
  })
}

pub fn duplicate_identifiers_and_counts_test() {
  let p = fixture.profile(0)
  assert build.encode(m.Profile(..p, classes: ["paper", "paper"]))
    == Error(m.DuplicateIdentifier)
  assert build.encode(m.Profile(..p, facts: list.append(p.facts, p.facts)))
    == Error(m.DuplicateIdentifier)
  assert build.encode(m.Profile(..p, ports: list.append(p.ports, p.ports)))
    == Error(m.DuplicateIdentifier)
  assert build.encode(m.Profile(..p, facts: [])) == Error(m.InvalidCount)
  assert build.encode(
      m.Profile(..p, ports: list.flatten(list.repeat(p.ports, 33))),
    )
    == Error(m.InvalidCount)
  assert build.encode(m.Profile(..p, requires: ["fuse", "power"]))
    == Error(m.InvalidEnum)
  assert build.encode(m.Profile(..p, kind: "video")) == Error(m.InvalidEnum)
  assert build.encode(m.Profile(..p, classes: ["paper", "photo", "pixel"]))
    |> accepted
}

pub fn identifiers_and_version_test() {
  let p = fixture.profile(0)
  list.each(
    [
      "",
      "../root",
      "_private",
      "hello world",
      "ü",
      "a\"b",
      "a\\b",
      string.repeat("a", 97),
    ],
    fn(id) {
      assert build.encode(m.Profile(..p, id:)) == Error(m.InvalidIdentifier)
    },
  )
  assert build.encode(m.Profile(..p, id: string.repeat("a", 96))) |> accepted
  assert build.encode(m.Profile(..p, schema: 2)) == Error(m.UnsupportedVersion)
  let assert Ok(bytes) = build.encode(p)
  assert build.decode(string.replace(bytes, "\"schema\":1", "\"schema\":2"))
    == Error(m.UnsupportedVersion)
}

pub fn duplicates_unknown_fields_and_noncanonical_input_test() {
  let assert Ok(bytes) = build.encode(fixture.profile(0))
  let mutations = [
    string.replace(bytes, "\"schema\":1", "\"schema\":1,\"schema\":1"),
    string.replace(bytes, "\"schema\":1", "\"schema\":2,\"schema\":1"),
    string.replace(bytes, "\"schema\":1", "\"schema\":1,\"unknown\":true"),
    string.replace(
      bytes,
      "\"id\":\"fixture-0\"",
      "\"id\":\"fixture-0\",\"id\":\"fixture-0\"",
    ),
    string.replace(bytes, "\"max\":1010", "\"max\":1010,\"max\":1010"),
    string.replace(bytes, "\"min\":1000", "\"min\":1e3"),
    string.replace(bytes, "\"min\":1000", "\"min\":1000.0"),
    string.replace(bytes, "\"min\":1000", "\"min\":9007199254740993"),
    string.replace(bytes, "\"min\":1000", "\"min\":-0"),
    string.replace(bytes, "\"min\":1000", "\"min\":0001"),
    string.replace(bytes, "fixture-0", "\\u0066ixture-0"),
    string.replace(
      bytes,
      "\"state\":\"missing\"",
      "\"state\":\"missing\",\"min\":0",
    ),
    string.replace(bytes, "\"required\":true", "\"required\":1"),
    string.replace(bytes, "\"state\":\"missing\"", "\"state\":\"certain\""),
    " " <> bytes,
    bytes <> "\n",
    string.trim_end(bytes),
  ]
  list.each(mutations, fn(text) {
    assert !accepted(build.decode(text))
  })
}

pub fn malformed_and_resource_limits_test() {
  list.each(
    [
      "",
      "null",
      "[]",
      "{",
      "{}",
      "{}{}",
      "\"\\uD800\"",
      "\"\\q\"",
      "true",
      "\u{0000}",
      "[1e9999]",
    ],
    fn(text) {
      assert !accepted(build.decode(text))
    },
  )
  assert build.decode(string.repeat(" ", 262_145)) == Error(m.TooLarge)
  assert build.decode(string.repeat("[", 17)) == Error(m.TooDeep)
  assert build.decode(string.repeat("1", 200_000)) == Error(m.InvalidDocument)
  assert build.decode(string.repeat(" ", 262_144)) == Error(m.InvalidDocument)
  assert !accepted(build.decode(
    string.repeat("[", 16) <> string.repeat("]", 16),
  ))
}

fn accepted(value: Result(a, b)) -> Bool {
  case value {
    Ok(_) -> True
    Error(_) -> False
  }
}

// Fixed generated corruption sequence; every accepted mutation must retain its
// exact bytes, and every other mutation must return a typed refusal.
pub fn generated_corruption_test() {
  let assert Ok(bytes) = build.encode(fixture.profile(0))
  let alphabet =
    string.to_graphemes("{}[],:\"\\0123456789-+eE.truefalsnul ABC_xyz\n")
  int.range(0, 2048, Nil, fn(_, i) {
    let index = { i * 433 + 17 } % string.byte_size(bytes)
    let assert Ok(char) =
      list.first(list.drop(alphabet, i % list.length(alphabet)))
    let mutated =
      string.slice(bytes, 0, index)
      <> char
      <> string.slice(bytes, index + 1, string.byte_size(bytes))
    case build.decode(mutated) {
      Ok(profile) -> {
        assert build.encode(profile) == Ok(mutated)
      }
      Error(refusal) -> {
        assert build.refusal_code(refusal) != ""
      }
    }
  })
}
