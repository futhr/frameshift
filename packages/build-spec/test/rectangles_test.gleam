import frameshift_build/compiler/rectangles.{Rectangle}
import frameshift_build/model.{InvalidCount, InvalidRange, TooLarge} as _
import gleam/int
import gleam/list
import gleeunit/should

pub fn empty_coverage_and_bounding_boxes_do_not_hide_gaps_test() {
  let target = Rectangle(0, 0, 10, 10)
  rectangles.covers(target, []) |> should.equal(Ok(False))
  rectangles.covers(target, [Rectangle(0, 0, 4, 10), Rectangle(5, 0, 10, 10)])
  |> should.equal(Ok(False))
  // Identical outer bounds and summed area do not establish union coverage.
  rectangles.covers(target, [
    Rectangle(0, 0, 5, 10),
    Rectangle(0, 0, 5, 10),
    Rectangle(9, 0, 10, 10),
  ])
  |> should.equal(Ok(False))
}

pub fn touching_overlapping_and_outside_rectangles_cover_exactly_test() {
  let target = Rectangle(-10, -10, 10, 10)
  let parts = [
    Rectangle(-20, -20, 0, 0),
    Rectangle(0, -10, 10, 0),
    Rectangle(-10, 0, 10, 10),
  ]
  rectangles.covers(target, parts) |> should.equal(Ok(True))
  rectangles.covers(target, list.reverse(parts)) |> should.equal(Ok(True))
  rectangles.covers(target, [Rectangle(-100, -100, 100, 100)])
  |> should.equal(Ok(True))
  rectangles.covers(target, [Rectangle(-100, -100, -10, 100)])
  |> should.equal(Ok(False))
  rectangles.covers(target, [
    Rectangle(-10, -10, 10, -1),
    Rectangle(-10, 0, 10, 10),
  ])
  |> should.equal(Ok(False))
}

pub fn count_coordinate_and_positive_area_boundaries_are_enforced_test() {
  let target = Rectangle(-15_000_000, -15_000_000, 15_000_000, 15_000_000)
  rectangles.covers(target, [target]) |> should.equal(Ok(True))
  let copies = int.range(0, 64, [], fn(acc, _) { [target, ..acc] })
  rectangles.covers(target, copies) |> should.equal(Ok(True))
  rectangles.covers(target, [target, ..copies])
  |> should.equal(Error(InvalidCount))
  rectangles.covers(Rectangle(-15_000_001, 0, 1, 1), [])
  |> should.equal(Error(TooLarge))
  rectangles.covers(Rectangle(0, 0, 0, 1), [])
  |> should.equal(Error(InvalidRange))
  rectangles.covers(target, [Rectangle(0, 1, 1, 0)])
  |> should.equal(Error(InvalidRange))
  rectangles.covers(target, [Rectangle(0, 0, 15_000_001, 1)])
  |> should.equal(Error(TooLarge))
}

pub fn two_dimensional_holes_are_not_filled_by_independent_axis_coverage_test() {
  let target = Rectangle(0, 0, 3, 3)
  let border = [
    Rectangle(0, 0, 3, 1),
    Rectangle(0, 2, 3, 3),
    Rectangle(0, 1, 1, 2),
    Rectangle(2, 1, 3, 2),
  ]
  rectangles.covers(target, border) |> should.equal(Ok(False))
  rectangles.covers(target, [Rectangle(1, 1, 2, 2), ..border])
  |> should.equal(Ok(True))
}
