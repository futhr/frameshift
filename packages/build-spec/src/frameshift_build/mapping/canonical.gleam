import frameshift_build/canonical as profiles
import frameshift_build/mapping/model.{type Document, type Pair}
import gleam/json as j
import gleam/list
import gleam/string

// Internal encoding primitives. Public export validates first.
pub fn document(value: Document) -> String {
  j.object([
    #("artifact", j.string(value.artifact)),
    #("firmware", j.string(value.firmware)),
    #(
      "pairs",
      j.array(
        list.sort(value.pairs, fn(a, b) {
          string.compare(pair_key(a), pair_key(b))
        }),
        pair,
      ),
    ),
    #("profile", j.string(value.profile)),
    #("protocol", j.string(value.protocol)),
    #("schema", j.int(value.schema)),
    #(
      "sources",
      j.array(
        list.sort(value.sources, fn(a, b) {
          string.compare(profiles.source_key(a), profiles.source_key(b))
        }),
        profiles.source,
      ),
    ),
  ])
  |> j.to_string
  |> string.append("\n")
}

fn pair_key(value: Pair) -> String {
  pair(value) |> j.to_string
}

fn pair(value: Pair) -> j.Json {
  j.object([
    #("input", j.string(value.input)),
    #("output", j.string(value.output)),
  ])
}
