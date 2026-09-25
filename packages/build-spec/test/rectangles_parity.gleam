import frameshift_build/compiler/rectangles.{type Rectangle, Rectangle}
import gleam/int
import gleam/io
import gleam/json

pub fn main() {
  let candidates = [
    Rectangle(0, 0, 1, 1),
    Rectangle(0, 0, 1, 2),
    Rectangle(0, 0, 2, 1),
    Rectangle(0, 0, 2, 2),
    Rectangle(0, 1, 1, 2),
    Rectangle(0, 1, 2, 2),
    Rectangle(1, 0, 2, 1),
    Rectangle(1, 0, 2, 2),
    Rectangle(1, 1, 2, 2),
  ]
  int.range(0, 512, Nil, fn(_, mask) {
    let assert Ok(covered) =
      rectangles.covers(Rectangle(0, 0, 2, 2), select(mask, candidates))
    json.object([#("mask", json.int(mask)), #("covered", json.bool(covered))])
    |> json.to_string
    |> io.println
  })
}

fn select(mask: Int, rectangles: List(Rectangle)) -> List(Rectangle) {
  case rectangles {
    [] -> []
    [first, ..rest] ->
      case mask % 2 {
        1 -> [first, ..select(mask / 2, rest)]
        _ -> select(mask / 2, rest)
      }
  }
}
