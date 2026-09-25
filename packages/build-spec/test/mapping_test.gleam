import frameshift_build
import frameshift_build/mapping
import frameshift_build/mapping/model.{Document, Pair}
import frameshift_build/model as p
import gleam/int
import gleam/list
import gleam/string
import gleeunit/should
import mapping_fixture as fixture
import profile_fixture

pub fn generated_round_trips_have_order_independent_bytes_and_domain_prefix_test() {
  int.range(0, 256, Nil, fn(_, seed) {
    let doc = fixture.document(seed)
    let assert Ok(bytes) = mapping.encode(doc)
    let assert Ok(restored) = mapping.decode(bytes)
    mapping.encode(restored) |> should.equal(Ok(bytes))
    mapping.encode(
      Document(
        ..doc,
        pairs: list.reverse(doc.pairs),
        sources: list.reverse(doc.sources),
      ),
    )
    |> should.equal(Ok(bytes))
    mapping.identity_payload(bytes)
    |> should.equal(Ok("frameshift.signal-mapping.v1\n" <> bytes))
  })
}

pub fn port_pairs_have_unique_outputs_and_distinct_bounded_identifiers_test() {
  let doc = fixture.document(0)
  list.each(
    [
      Pair("in", "in"),
    ],
    fn(pair) {
      mapping.encode(Document(..doc, pairs: [pair]))
      |> should.equal(Error(p.InvalidReference))
    },
  )
  list.each(["", "../a", "a b", "ü", string.repeat("a", 97)], fn(id) {
    mapping.encode(Document(..doc, pairs: [Pair(id, "out")]))
    |> should.equal(Error(p.InvalidIdentifier))
    mapping.encode(Document(..doc, firmware: id))
    |> should.equal(Error(p.InvalidIdentifier))
  })
  mapping.encode(
    Document(..doc, pairs: [Pair("in", "out"), Pair("other", "out")]),
  )
  |> should.equal(Error(p.DuplicateIdentifier))
  let assert Ok(_) =
    mapping.encode(Document(..doc, pairs: [Pair("in", "a"), Pair("in", "b")]))
  let pairs =
    int.range(0, 256, [], fn(acc, n) {
      [Pair("in", "out-" <> int.to_string(n)), ..acc]
    })
  let assert Ok(_) = mapping.encode(Document(..doc, pairs:))
  mapping.encode(Document(..doc, pairs: []))
  |> should.equal(Error(p.InvalidCount))
  mapping.encode(Document(..doc, pairs: [Pair("in", "extra"), ..pairs]))
  |> should.equal(Error(p.InvalidCount))
}

pub fn source_identity_and_scope_remain_bounded_and_sourced_test() {
  let doc = fixture.document(0)
  let source = profile_fixture.source()
  mapping.encode(Document(..doc, schema: 2))
  |> should.equal(Error(p.UnsupportedVersion))
  mapping.encode(Document(..doc, profile: "unverified"))
  |> should.equal(Error(p.InvalidIdentity))
  mapping.encode(Document(..doc, sources: []))
  |> should.equal(Error(p.InvalidCount))
  mapping.encode(Document(..doc, sources: [source, source]))
  |> should.equal(Error(p.DuplicateIdentifier))
  mapping.encode(
    Document(..doc, sources: [
      p.Source(..source, digest: string.repeat("A", 64)),
    ]),
  )
  |> should.equal(Error(p.InvalidSource))
  mapping.encode(
    Document(..doc, sources: [p.Source(..source, evidence: "approved")]),
  )
  |> should.equal(Error(p.InvalidEnum))
  let sources =
    int.range(0, 8, [], fn(acc, n) {
      [p.Source(..source, locator: "p-" <> int.to_string(n)), ..acc]
    })
  let assert Ok(_) = mapping.encode(Document(..doc, sources:))
  mapping.encode(Document(..doc, sources: [source, ..sources]))
  |> should.equal(Error(p.InvalidCount))
}

pub fn strict_import_refuses_ambiguous_and_mutable_fields_test() {
  let assert Ok(bytes) = mapping.encode(fixture.document(0))
  list.each(
    [
      string.replace(bytes, "\"schema\":1", "\"schema\":1,\"schema\":1"),
      string.replace(bytes, "\"schema\":1", "\"schema\":1,\"approved\":true"),
      string.replace(bytes, "\"schema\":1", "\"schema\":1.0"),
      string.replace(bytes, "\"schema\":1", "\"schema\":1e0"),
      string.replace(bytes, "\"schema\":1", "\"schema\":9007199254740993"),
      string.replace(
        bytes,
        "\"input\":\"in-0\"",
        "\"input\":\"in-0\",\"input\":\"in-0\"",
      ),
      string.replace(bytes, "in-0", "\\u0069n-0"),
      string.replace(
        bytes,
        "\"revision\":\"test-1\"",
        "\"revision\":\"test-1\",\"approved\":true",
      ),
      " " <> bytes,
      bytes <> "\n",
      string.trim_end(bytes),
    ],
    fn(changed) { mapping.decode(changed) |> should.be_error },
  )
  let assert Ok(multiple) = mapping.encode(fixture.document(1))
  let reversed =
    string.replace(
      multiple,
      "{\"input\":\"in-0\",\"output\":\"out-0\"},{\"input\":\"in-1\",\"output\":\"out-1\"}",
      "{\"input\":\"in-1\",\"output\":\"out-1\"},{\"input\":\"in-0\",\"output\":\"out-0\"}",
    )
  mapping.decode(reversed) |> should.equal(Error(p.NonCanonical))
}

pub fn malformed_and_resource_limits_precede_decoding_test() {
  list.each(
    ["", "{}", "[]", "null", "{}{}", "\"\\uD800\"", "\u{0}", "[1e9999]"],
    fn(bytes) { mapping.decode(bytes) |> should.be_error },
  )
  mapping.decode(string.repeat(" ", 262_145)) |> should.equal(Error(p.TooLarge))
  mapping.decode(string.repeat("[", 17)) |> should.equal(Error(p.TooDeep))
  mapping.decode(string.repeat("1", 200_000))
  |> should.equal(Error(p.InvalidDocument))
}

pub fn generated_corruption_returns_exact_round_trips_or_typed_refusals_test() {
  let assert Ok(bytes) = mapping.encode(fixture.document(0))
  let alphabet =
    string.to_graphemes("{}[],:\"\\0123456789-+eE.truefalsnul ABC_xyz\n")
  int.range(0, 2048, Nil, fn(_, i) {
    let index = { i * 433 + 17 } % string.byte_size(bytes)
    let assert Ok(char) =
      list.first(list.drop(alphabet, i % list.length(alphabet)))
    let changed =
      string.slice(bytes, 0, index)
      <> char
      <> string.slice(bytes, index + 1, string.byte_size(bytes))
    case mapping.decode(changed) {
      Ok(doc) -> mapping.encode(doc) |> should.equal(Ok(changed))
      Error(refusal) -> {
        assert frameshift_build.refusal_code(refusal) != ""
      }
    }
  })
}
