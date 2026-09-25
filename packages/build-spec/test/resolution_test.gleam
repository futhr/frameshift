import assembly_fixture
import frameshift_build
import frameshift_build/assembly
import frameshift_build/model as refusal
import frameshift_build/resolution
import gleam/list
import gleam/string
import gleeunit/should
import profile_fixture

fn inputs() -> #(String, List(#(String, String))) {
  let assert Ok(plan) = assembly.encode(assembly_fixture.assembly(0))
  let assert Ok(first) = frameshift_build.encode(profile_fixture.profile(0))
  let assert Ok(second) = frameshift_build.encode(profile_fixture.profile(1))
  // Internal pure fixtures; cryptographic binding is exercised by adapter tests.
  #(plan, [
    #("sha256:" <> string.repeat("a", 64), first),
    #("sha256:" <> string.repeat("b", 64), second),
  ])
}

pub fn resolution_order_and_exact_profile_binding_test() {
  let #(plan, profiles) = inputs()
  let assert Ok(value) = resolution.resolve(plan, profiles)
  resolution.resolve(plan, list.reverse(profiles)) |> should.equal(Ok(value))
  value.missing |> should.equal([])
  let assert [first, second] = value.profiles
  first.profile.id |> should.equal("fixture-0")
  second.profile.id |> should.equal("fixture-1")
  list.length(value.assembly.instances) |> should.equal(2)
}

pub fn missing_pins_are_explicit_and_never_replace_a_part_test() {
  let #(plan, profiles) = inputs()
  let assert [first, second] = profiles
  let assert Ok(value) = resolution.resolve(plan, [first])
  value.missing |> should.equal([second.0])
  let assert Ok(empty) = resolution.resolve(plan, [])
  empty.profiles |> should.equal([])
  empty.missing |> should.equal([first.0, second.0])
}

pub fn duplicate_extra_or_malformed_profiles_refuse_resolution_test() {
  let #(plan, profiles) = inputs()
  let assert [first, ..] = profiles
  resolution.resolve(plan, [first, first])
  |> should.equal(Error(refusal.DuplicateIdentifier))
  resolution.resolve(plan, [#("sha256:" <> string.repeat("c", 64), first.1)])
  |> should.equal(Error(refusal.UnreferencedProfile))
  resolution.resolve(plan, [#(first.0, " " <> first.1)])
  |> should.equal(Error(refusal.NonCanonical))
  resolution.resolve("{}", profiles)
  |> should.equal(Error(refusal.InvalidDocument))
}

pub fn total_byte_and_count_budgets_are_checked_before_parsing_test() {
  let maximum = string.repeat("x", 262_144)
  resolution.budget("", list.repeat("", 65))
  |> should.equal(Error(refusal.InvalidCount))
  resolution.budget(maximum <> "x", []) |> should.equal(Error(refusal.TooLarge))
  resolution.budget("", [maximum <> "x"])
  |> should.equal(Error(refusal.TooLarge))
  resolution.budget("x", list.repeat(maximum, 16))
  |> should.equal(Error(refusal.TooLarge))
  resolution.budget("", list.repeat(maximum, 16)) |> should.equal(Ok(Nil))
  resolution.budget("", [string.repeat("é", 131_073)])
  |> should.equal(Error(refusal.TooLarge))
}
