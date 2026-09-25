import frameshift_build
import frameshift_build/artifact
import frameshift_build/artifact/model.{Document, Tile}
import frameshift_build/model as p
import gleam/int
import gleam/list
import gleam/string
import gleeunit/should
import layout_fixture as fixture

pub fn all_generated_layouts_round_trip_without_changing_unknown_encodings_test() {
  int.range(0, 256, Nil, fn(_, seed) {
    let doc = fixture.document(seed)
    let assert Ok(bytes) = artifact.encode(doc)
    let assert Ok(restored) = artifact.decode(bytes)
    artifact.encode(restored) |> should.equal(Ok(bytes))
    restored.encoding |> should.equal(doc.encoding)
    artifact.encode(Document(..doc, tiles: list.reverse(doc.tiles)))
    |> should.equal(Ok(bytes))
    artifact.identity_payload(bytes)
    |> should.equal(Ok("frameshift.artifact-layout.v1\n" <> bytes))
  })
}

pub fn structural_limits_require_unique_tiles_and_bounded_coordinates_test() {
  let doc = fixture.document(0)
  let tiles =
    int.range(0, 64, [], fn(acc, n) {
      [Tile("panel-" <> int.to_string(n), 270, 32_768, 32_768), ..acc]
    })
  let assert Ok(_) =
    artifact.encode(Document(..doc, width: 32_768, height: 32_768, tiles:))
  artifact.encode(Document(..doc, schema: 2))
  |> should.equal(Error(p.UnsupportedVersion))
  artifact.encode(Document(..doc, width: 32_769))
  |> should.equal(Error(p.InvalidRange))
  artifact.encode(Document(..doc, height: 0))
  |> should.equal(Error(p.InvalidRange))
  artifact.encode(Document(..doc, tiles: []))
  |> should.equal(Error(p.InvalidCount))
  artifact.encode(Document(..doc, tiles: [Tile("other", 0, 0, 0), ..tiles]))
  |> should.equal(Error(p.InvalidCount))
  artifact.encode(
    Document(..doc, tiles: [Tile("panel", 0, 0, 0), Tile("panel", 90, 1, 0)]),
  )
  |> should.equal(Error(p.DuplicateIdentifier))
  artifact.encode(Document(..doc, tiles: [Tile("panel", 45, 0, 0)]))
  |> should.equal(Error(p.InvalidRange))
  artifact.encode(Document(..doc, tiles: [Tile("panel", 0, -1, 0)]))
  |> should.equal(Error(p.InvalidRange))
  artifact.encode(Document(..doc, controller: "../private"))
  |> should.equal(Error(p.InvalidIdentifier))
}

pub fn import_refuses_duplicate_fields_mutable_metadata_and_alternate_numbers_test() {
  let assert Ok(bytes) = artifact.encode(fixture.document(0))
  list.each(
    [
      string.replace(bytes, "\"schema\":1", "\"schema\":1,\"schema\":1"),
      string.replace(bytes, "\"schema\":1", "\"schema\":1,\"approved\":true"),
      string.replace(bytes, "\"height\":3", "\"height\":3.0"),
      string.replace(bytes, "\"height\":3", "\"height\":3e0"),
      string.replace(bytes, "\"height\":3", "\"height\":9007199254740993"),
      string.replace(bytes, "\"rotation\":0", "\"rotation\":-0"),
      string.replace(bytes, "\"x\":0", "\"x\":0,\"x\":0"),
      string.replace(
        bytes,
        "\"display\":\"panel\"",
        "\"display\":\"\\u0070anel\"",
      ),
      " " <> bytes,
      bytes <> "\n",
      string.trim_end(bytes),
    ],
    fn(changed) { artifact.decode(changed) |> should.be_error },
  )
}

pub fn resource_and_malformed_limits_run_before_native_json_decoding_test() {
  list.each(
    ["", "{}", "[]", "null", "{}{}", "\"\\uD800\"", "\u{0}", "[1e9999]"],
    fn(bytes) { artifact.decode(bytes) |> should.be_error },
  )
  artifact.decode(string.repeat(" ", 262_145))
  |> should.equal(Error(p.TooLarge))
  artifact.decode(string.repeat("[", 17)) |> should.equal(Error(p.TooDeep))
  artifact.decode(string.repeat("1", 200_000))
  |> should.equal(Error(p.InvalidDocument))
}

pub fn deterministic_corruptions_are_exact_round_trips_or_typed_refusals_test() {
  let assert Ok(bytes) = artifact.encode(fixture.document(0))
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
    case artifact.decode(changed) {
      Ok(doc) -> artifact.encode(doc) |> should.equal(Ok(changed))
      Error(refusal) -> {
        assert frameshift_build.refusal_code(refusal) != ""
      }
    }
  })
}
