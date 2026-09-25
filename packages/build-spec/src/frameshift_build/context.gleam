/// Internal exact compilation inputs. Identity/byte pairs and the assembly pin
/// must come from standard-crypto adapters. This module cannot authenticate them.
import frameshift_build/artifact
import frameshift_build/assembly/validation as identities
import frameshift_build/bounds
import frameshift_build/compiler/artifact_layout.{type Layout, Layout}
import frameshift_build/compiler/signal_mapping
import frameshift_build/mapping
import frameshift_build/mapping/model.{type Document}
import frameshift_build/model.{type Refusal} as _
import frameshift_build/resolution.{type Resolution}
import gleam/json
import gleam/list
import gleam/result
import gleam/string

pub type ResolvedMapping {
  ResolvedMapping(identity: String, document: Document)
}

pub type Context {
  Context(
    resolution: Resolution,
    mappings: List(ResolvedMapping),
    layouts: List(Layout),
  )
}

pub fn resolve(
  bytes: String,
  profiles: List(#(String, String)),
  mappings: List(#(String, String)),
) -> Result(Context, Refusal) {
  resolve_all(bytes, profiles, mappings, [])
}

pub fn resolve_all(
  bytes: String,
  profiles: List(#(String, String)),
  mappings: List(#(String, String)),
  layouts: List(#(String, String)),
) -> Result(Context, Refusal) {
  use _ <- result.try(resolution.complete_budget(
    bytes,
    list.map(profiles, fn(p) { p.1 }),
    list.map(mappings, fn(m) { m.1 }),
    list.map(layouts, fn(l) { l.1 }),
  ))
  use resolved <- result.try(resolution.resolve(bytes, profiles))
  use _ <- result.try(bounds.unique(list.map(mappings, fn(m) { m.0 })))
  use mappings <- result.try(
    list.try_map(mappings, fn(pair) {
      use _ <- result.try(identities.identity(pair.0))
      use document <- result.try(mapping.decode(pair.1))
      Ok(ResolvedMapping(pair.0, document))
    }),
  )
  use layouts <- result.try(
    list.try_map(layouts, fn(pair) {
      use _ <- result.try(identities.identity(pair.0))
      use document <- result.try(artifact.decode(pair.1))
      Ok(Layout(pair.0, document))
    }),
  )
  let context =
    Context(
      resolved,
      list.sort(mappings, fn(a, b) { string.compare(a.identity, b.identity) }),
      list.sort(layouts, fn(a, b) { string.compare(a.identity, b.identity) }),
    )
  use _ <- result.try(signal_mapping.validate(route_mappings(context), resolved))
  use _ <- result.try(artifact_layout.validate(context.layouts, resolved))
  Ok(context)
}

pub fn route_mappings(context: Context) -> List(signal_mapping.Mapping) {
  list.map(context.mappings, fn(m) {
    let d = m.document
    signal_mapping.Mapping(
      m.identity,
      d.profile,
      d.artifact,
      d.firmware,
      d.protocol,
      d.pairs,
    )
  })
}

pub fn canonical(
  assembly: String,
  context: Context,
) -> Result(String, Refusal) {
  use _ <- result.try(identities.identity(assembly))
  let bindings =
    list.append(
      list.map(context.mappings, fn(m) { binding(m.identity, "signal-mapping") }),
      list.map(context.layouts, fn(l) { binding(l.identity, "artifact-layout") }),
    )
    |> list.sort(fn(a, b) {
      string.compare(json.to_string(a), json.to_string(b))
    })
  Ok(
    json.object([
      #("assembly", json.string(assembly)),
      #("bindings", json.array(bindings, fn(b) { b })),
      #("compiler", json.string(context.resolution.assembly.semantics)),
      #("schema", json.int(1)),
    ])
    |> json.to_string
    |> string.append("\n"),
  )
}

fn binding(identity: String, kind: String) -> json.Json {
  json.object([
    #("identity", json.string(identity)),
    #("kind", json.string(kind)),
  ])
}

pub fn identity_payload(
  assembly: String,
  context: Context,
) -> Result(String, Refusal) {
  use bytes <- result.try(canonical(assembly, context))
  Ok("frameshift.compilation.v1\n" <> bytes)
}
