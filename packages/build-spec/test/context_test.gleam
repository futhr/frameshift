import context_fixture as fixture
import frameshift_build/artifact
import frameshift_build/artifact/model as layouts
import frameshift_build/context
import frameshift_build/mapping
import frameshift_build/mapping/model.{Document, Pair}
import frameshift_build/model as p
import frameshift_build/resolution
import gleam/list
import gleam/string
import gleeunit/should
import layout_fixture

pub fn context_keeps_exact_scope_citations_and_order_independent_bindings_test() {
  let #(assembly, profiles, mappings) = fixture.inputs()
  let assert Ok(value) = context.resolve(assembly, profiles, mappings)
  context.resolve(assembly, list.reverse(profiles), list.reverse(mappings))
  |> should.equal(Ok(value))
  list.length(value.mappings) |> should.equal(2)
  value.resolution.missing |> should.equal([])
  let routes = context.route_mappings(value)
  list.map(routes, fn(m) { m.identity })
  |> should.equal(list.map(value.mappings, fn(m) { m.identity }))
  list.all(value.mappings, fn(m) { list.length(m.document.sources) == 1 })
  |> should.be_true
  let assembly_pin = "sha256:" <> string.repeat("1", 64)
  let assert Ok(bytes) = context.canonical(assembly_pin, value)
  context.identity_payload(assembly_pin, value)
  |> should.equal(Ok("frameshift.compilation.v1\n" <> bytes))
  context.canonical("missing", value) |> should.equal(Error(p.InvalidIdentity))
}

pub fn missing_profiles_and_mappings_remain_distinct_test() {
  let #(assembly, profiles, mappings) = fixture.inputs()
  let assert Ok(empty) = context.resolve(assembly, [], [])
  list.length(empty.resolution.missing) |> should.equal(4)
  empty.mappings |> should.equal([])
  context.resolve(assembly, [], mappings)
  |> should.equal(Error(p.InvalidReference))
  let assert Ok(without_maps) = context.resolve(assembly, profiles, [])
  without_maps.resolution.missing |> should.equal([])
  without_maps.mappings |> should.equal([])
}

pub fn supplied_mapping_revisions_must_match_runtime_profile_and_ports_test() {
  let #(assembly, profiles, mappings) = fixture.inputs()
  let assert [first, ..] = mappings
  let assert Ok(doc) = mapping.decode(first.1)
  list.each(
    [
      Document(..doc, firmware: "other"),
      Document(..doc, profile: "sha256:" <> string.repeat("9", 64)),
      Document(..doc, pairs: [Pair("absent", "out")]),
    ],
    fn(changed) {
      let assert Ok(bytes) = mapping.encode(changed)
      context.resolve(assembly, profiles, [#(first.0, bytes)])
      |> should.equal(Error(p.InvalidReference))
    },
  )
  context.resolve(assembly, profiles, [first, first])
  |> should.equal(Error(p.DuplicateIdentifier))
  context.resolve(assembly, profiles, [#(first.0, " " <> first.1)])
  |> should.equal(Error(p.NonCanonical))
  context.resolve(assembly, profiles, [#("fake", first.1)])
  |> should.equal(Error(p.InvalidIdentity))
}

pub fn joint_budget_precedes_decoding_and_never_resets_for_mapping_bodies_test() {
  let maximum = string.repeat("x", 262_144)
  let profiles = list.repeat(maximum, 8)
  let mappings = list.repeat(maximum, 8)
  resolution.context_budget("", profiles, mappings) |> should.equal(Ok(Nil))
  resolution.context_budget("x", profiles, mappings)
  |> should.equal(Error(p.TooLarge))
  resolution.context_budget("", [], [maximum <> "x"])
  |> should.equal(Error(p.TooLarge))
  resolution.context_budget("", [], list.repeat("", 65))
  |> should.equal(Error(p.InvalidCount))
  resolution.context_budget("", list.repeat("", 65), [])
  |> should.equal(Error(p.InvalidCount))
  context.resolve(
    "x",
    list.map(profiles, fn(p) { #("fake", p) }),
    list.map(mappings, fn(m) { #("fake", m) }),
  )
  |> should.equal(Error(p.TooLarge))
}

pub fn layout_bindings_preserve_complete_inputs_and_change_context_identity_payload_test() {
  let #(assembly, profiles, mappings) = fixture.inputs()
  let assert Ok(bytes) = artifact.encode(layout_fixture.document(0))
  let pin = "sha256:" <> string.repeat("8", 64)
  let assert Ok(value) =
    context.resolve_all(assembly, profiles, mappings, [#(pin, bytes)])
  list.length(value.layouts) |> should.equal(1)
  let assert [layout] = value.layouts
  layout.document.controller |> should.equal("controller")
  let assert Ok(empty) = context.resolve(assembly, profiles, mappings)
  context.resolve_all(assembly, profiles, mappings, [])
  |> should.equal(Ok(empty))
  let assembly_pin = "sha256:" <> string.repeat("1", 64)
  let assert Ok(with_layout) = context.canonical(assembly_pin, value)
  let assert Ok(without_layout) = context.canonical(assembly_pin, empty)
  assert with_layout != without_layout
  string.contains(with_layout, "\"kind\":\"artifact-layout\"") |> should.be_true
  context.resolve_all(assembly, list.reverse(profiles), list.reverse(mappings), [
    #(pin, bytes),
  ])
  |> should.equal(Ok(value))
}

pub fn resolved_layouts_require_unique_assignments_and_exact_runtime_scope_test() {
  let #(assembly, profiles, mappings) = fixture.inputs()
  let doc = layout_fixture.document(0)
  let pin = "sha256:" <> string.repeat("8", 64)
  let assert Ok(bytes) = artifact.encode(doc)
  context.resolve_all(assembly, profiles, mappings, [
    #(pin, bytes),
    #(pin, bytes),
  ])
  |> should.equal(Error(p.DuplicateIdentifier))
  context.resolve_all(assembly, profiles, mappings, [
    #(pin, bytes),
    #("sha256:" <> string.repeat("7", 64), bytes),
  ])
  |> should.equal(Error(p.DuplicateIdentifier))
  list.each(
    [
      layouts.Document(..doc, controller: "absent"),
      layouts.Document(..doc, protocol: "other"),
      layouts.Document(..doc, tiles: [layouts.Tile("absent", 0, 0, 0)]),
    ],
    fn(doc) {
      let assert Ok(bytes) = artifact.encode(doc)
      context.resolve_all(assembly, profiles, mappings, [#(pin, bytes)])
      |> should.equal(Error(p.InvalidReference))
    },
  )
  let assert Ok(unknown) =
    context.resolve_all(assembly, [], [], [#(pin, bytes)])
  list.length(unknown.resolution.missing) |> should.equal(4)
}

pub fn all_four_document_groups_share_one_budget_test() {
  let body = string.repeat("x", 262_144)
  resolution.complete_budget(
    "",
    list.repeat(body, 6),
    list.repeat(body, 5),
    list.repeat(body, 5),
  )
  |> should.equal(Ok(Nil))
  resolution.complete_budget(
    "x",
    list.repeat(body, 6),
    list.repeat(body, 5),
    list.repeat(body, 5),
  )
  |> should.equal(Error(p.TooLarge))
  resolution.complete_budget("", [], [], [body <> "x"])
  |> should.equal(Error(p.TooLarge))
  resolution.complete_budget("", [], [], list.repeat("", 65))
  |> should.equal(Error(p.InvalidCount))
}
