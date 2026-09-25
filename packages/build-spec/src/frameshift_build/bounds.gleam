import frameshift_build/model.{
  type Refusal, DuplicateIdentifier, InvalidCount, InvalidDocument, InvalidEnum,
  InvalidIdentifier, TooDeep, TooLarge,
}
import gleam/bit_array
import gleam/list
import gleam/result
import gleam/string

pub fn document(text: String) -> Result(Nil, Refusal) {
  case string.byte_size(text) > 262_144 {
    True -> Error(TooLarge)
    False -> scan(bit_array.from_string(text), 0, False, False, 0)
  }
}

// Resource preflight only. The pinned parser owns JSON grammar. Reject deep
// nesting and enormous integer tokens before either native parser runs.
fn scan(
  bytes: BitArray,
  depth: Int,
  quoted: Bool,
  escaped: Bool,
  digits: Int,
) -> Result(Nil, Refusal) {
  case bytes {
    <<>> if depth == 0 && !quoted -> Ok(Nil)
    <<>> -> Error(InvalidDocument)
    <<byte, _:bytes>> if byte > 127 || byte < 10 -> Error(InvalidDocument)
    <<byte, rest:bytes>> -> {
      case quoted, escaped, byte {
        True, True, _ -> scan(rest, depth, True, False, 0)
        True, False, 92 -> scan(rest, depth, True, True, 0)
        _, _, 34 -> scan(rest, depth, !quoted, False, 0)
        True, _, _ -> scan(rest, depth, True, False, 0)
        _, _, 123 | _, _, 91 -> {
          case depth >= 16 {
            True -> Error(TooDeep)
            False -> scan(rest, depth + 1, False, False, 0)
          }
        }
        _, _, 125 | _, _, 93 -> {
          case depth <= 0 {
            True -> Error(InvalidDocument)
            False -> scan(rest, depth - 1, False, False, 0)
          }
        }
        _, _, byte if byte >= 48 && byte <= 57 -> {
          case digits >= 16 {
            True -> Error(InvalidDocument)
            False -> scan(rest, depth, False, False, digits + 1)
          }
        }
        _, _, byte
          if digits > 0 && { byte == 101 || byte == 69 || byte == 46 }
        -> Error(InvalidDocument)
        _, _, _ -> scan(rest, depth, False, False, 0)
      }
    }
    _ -> Error(InvalidDocument)
  }
}

pub fn identifier(value: String) -> Result(Nil, Refusal) {
  let chars = string.to_graphemes(value)
  case chars {
    [first, ..] -> {
      case
        string.byte_size(value) <= 96
        && alphanumeric(first)
        && list.all(chars, fn(c) {
          alphanumeric(c) || list.contains([".", "_", "+", "-"], c)
        })
      {
        True -> Ok(Nil)
        False -> Error(InvalidIdentifier)
      }
    }
    _ -> Error(InvalidIdentifier)
  }
}

fn alphanumeric(char: String) -> Bool {
  string.contains(
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
    char,
  )
}

pub fn count(
  values: List(a),
  minimum: Int,
  maximum: Int,
) -> Result(Nil, Refusal) {
  let length = list.length(values)
  case length >= minimum && length <= maximum {
    True -> Ok(Nil)
    False -> Error(InvalidCount)
  }
}

pub fn unique(values: List(String)) -> Result(Nil, Refusal) {
  case list.length(values) == list.length(list.unique(values)) {
    True -> Ok(Nil)
    False -> Error(DuplicateIdentifier)
  }
}

pub fn identifiers(
  values: List(String),
  min: Int,
  max: Int,
) -> Result(Nil, Refusal) {
  use _ <- result.try(count(values, min, max))
  use _ <- result.try(unique(values))
  list.try_each(values, identifier)
}

pub fn enum(value: String, allowed: List(String)) -> Result(Nil, Refusal) {
  case list.contains(allowed, value) {
    True -> Ok(Nil)
    False -> Error(InvalidEnum)
  }
}
