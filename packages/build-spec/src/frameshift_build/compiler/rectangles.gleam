/// Exact bounded union coverage. These rectangles carry no source authority.
import frameshift_build/model.{
  type Refusal, InvalidCount, InvalidRange, TooLarge,
} as _
import gleam/int
import gleam/list
import gleam/result

pub type Rectangle {
  Rectangle(left: Int, top: Int, right: Int, bottom: Int)
}

pub fn validate(rectangle: Rectangle) -> Result(Nil, Refusal) {
  let edges = [rectangle.left, rectangle.top, rectangle.right, rectangle.bottom]
  case list.all(edges, fn(v) { v >= -15_000_000 && v <= 15_000_000 }) {
    False -> Error(TooLarge)
    True ->
      case
        rectangle.left < rectangle.right && rectangle.top < rectangle.bottom
      {
        True -> Ok(Nil)
        False -> Error(InvalidRange)
      }
  }
}

pub fn covers(
  target: Rectangle,
  rectangles: List(Rectangle),
) -> Result(Bool, Refusal) {
  case list.length(list.take(rectangles, 65)) <= 64 {
    False -> Error(InvalidCount)
    True -> {
      use _ <- result.try(validate(target))
      use _ <- result.try(list.try_map(rectangles, validate))
      let clipped = list.filter_map(rectangles, clip(_, target))
      let edges =
        [
          target.left,
          target.right,
          ..list.flat_map(clipped, fn(r) { [r.left, r.right] })
        ]
        |> list.unique
        |> list.sort(int.compare)
      Ok(slabs(edges, target, clipped))
    }
  }
}

fn clip(rectangle: Rectangle, target: Rectangle) -> Result(Rectangle, Nil) {
  let result =
    Rectangle(
      int.max(rectangle.left, target.left),
      int.max(rectangle.top, target.top),
      int.min(rectangle.right, target.right),
      int.min(rectangle.bottom, target.bottom),
    )
  case result.left < result.right && result.top < result.bottom {
    True -> Ok(result)
    False -> Error(Nil)
  }
}

fn slabs(
  edges: List(Int),
  target: Rectangle,
  rectangles: List(Rectangle),
) -> Bool {
  case edges {
    [left, right, ..rest] -> {
      let span =
        rectangles
        |> list.filter(fn(r) { r.left <= left && r.right >= right })
        |> list.sort(fn(a, b) { int.compare(a.top, b.top) })
      vertical(span, target.top, target.bottom)
      && slabs([right, ..rest], target, rectangles)
    }
    _ -> True
  }
}

fn vertical(rectangles: List(Rectangle), cursor: Int, end: Int) -> Bool {
  case rectangles {
    [] -> cursor >= end
    [first, ..rest] ->
      case first.top <= cursor {
        False -> False
        True -> vertical(rest, int.max(cursor, first.bottom), end)
      }
  }
}
