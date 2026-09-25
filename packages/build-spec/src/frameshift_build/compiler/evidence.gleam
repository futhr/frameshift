/// Preserve exact observations and first-occurrence order. Short lookup keys
/// avoid repeatedly hashing whole source documents; buckets still compare the
/// complete value so two observations of one fact are never conflated.
import frameshift_build/compiler/facts.{type Reading}
import frameshift_build/compiler/model.{type Input, BuildInput, ProfileInput}
import gleam/dict
import gleam/list
import gleam/string

pub fn readings(values: List(Reading)) -> List(Reading) {
  unique(values, fn(r) { r.instance <> "\u{0}" <> r.port <> "\u{0}" <> r.key })
}

pub fn inputs(values: List(Input)) -> List(Input) {
  unique(values, fn(input) {
    case input {
      BuildInput(path) -> "b\u{0}" <> string.join(path, "\u{0}")
      ProfileInput(instance, _, path) ->
        "p\u{0}" <> instance <> "\u{0}" <> string.join(path, "\u{0}")
    }
  })
}

fn unique(values: List(a), key: fn(a) -> String) -> List(a) {
  let #(_, reversed) =
    list.fold(values, #(dict.new(), []), fn(state, value) {
      let #(seen, result) = state
      let key = key(value)
      let bucket = case dict.get(seen, key) {
        Ok(values) -> values
        Error(_) -> []
      }
      case list.contains(bucket, value) {
        True -> state
        False -> #(dict.insert(seen, key, [value, ..bucket]), [value, ..result])
      }
    })
  list.reverse(reversed)
}
