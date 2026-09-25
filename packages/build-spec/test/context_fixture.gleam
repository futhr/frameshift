import frameshift_build
import frameshift_build/assembly
import frameshift_build/assembly/model as a
import frameshift_build/mapping
import frameshift_build/mapping/model.{Document} as _
import frameshift_build/model as p
import frameshift_build/resolution as r
import gleam/io
import gleam/json
import gleam/list
import profile_fixture
import route_fixture

pub fn inputs() -> #(String, List(#(String, String)), List(#(String, String))) {
  let original = route_fixture.mapping(route_fixture.adapted())
  let value = route_fixture.chain(2)
  let assert Ok(profile) = r.find_profile(value, original.profile)
  let extra =
    "sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
  let profiles = [
    r.ResolvedProfile(extra, p.Profile(..profile, id: "fixture-adapter-2")),
    ..value.profiles
  ]
  let instances =
    list.map(value.assembly.instances, fn(i) {
      case i.id {
        "adapter-1" -> a.Instance(..i, profile: extra)
        _ -> i
      }
    })
  let assert Ok(bytes) =
    assembly.encode(a.Assembly(..value.assembly, instances:))
  let profiles =
    list.map(profiles, fn(p) {
      let assert Ok(bytes) = frameshift_build.encode(p.profile)
      #(p.identity, bytes)
    })
  let doc =
    Document(
      original.artifact,
      original.firmware,
      original.pairs,
      original.profile,
      original.protocol,
      1,
      [profile_fixture.source()],
    )
  let assert Ok(first) = mapping.encode(doc)
  let assert Ok(second) = mapping.encode(Document(..doc, profile: extra))
  #(bytes, profiles, [
    #(original.identity, first),
    #(
      "sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
      second,
    ),
  ])
}

// Deterministic raw inputs for the standard-crypto adapter fixtures. Synthetic.
pub fn main() {
  let #(assembly, profiles, mappings) = inputs()
  emit("assembly", "assembly", assembly)
  list.each(profiles, fn(p) { emit("profile", p.0, p.1) })
  list.each(mappings, fn(m) { emit("mapping", m.0, m.1) })
}

fn emit(kind: String, pin: String, bytes: String) {
  json.object([
    #("kind", json.string(kind)),
    #("pin", json.string(pin)),
    #("bytes", json.string(bytes)),
  ])
  |> json.to_string
  |> io.println
}
