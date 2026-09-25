import frameshift_build/assembly/model as a
import frameshift_build/compiler/projection
import frameshift_build/compiler/rectangles.{Rectangle}
import frameshift_build/model as p
import frameshift_build/resolution as r
import geometry_fixture
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import viewing_fixture as fixture

pub fn explicit_offsets_rotate_without_inferred_centering_test() {
  let value =
    fixture.resolved()
    |> fixture.set_fact(
      "display",
      "active.offset.x",
      fixture.fact("active.offset.x", 3),
    )
    |> fixture.set_fact(
      "display",
      "active.offset.y",
      fixture.fact("active.offset.y", 5),
    )
  let expected = [
    Rectangle(13, 15, 113, 95),
    Rectangle(15, 13, 95, 113),
    Rectangle(17, 15, 117, 95),
    Rectangle(15, 17, 95, 117),
  ]
  list.index_map(expected, fn(expected, i) {
    let value = fixture.place(value, "part-a", a.Placement(90 * i, 10, 10, 10))
    let assert Ok(instance) = r.find_instance(value, "part-a")
    let region = projection.active(instance, value)
    projection.possible(region) |> should.equal(Some(expected))
    projection.guaranteed(region) |> should.equal(Some(expected))
  })
}

pub fn tolerances_distinguish_guaranteed_from_possible_area_test() {
  let value =
    fixture.resolved()
    |> fixture.set_fact(
      "display",
      "active.offset.x",
      geometry_fixture.fact("active.offset.x", 0, 5),
    )
    |> fixture.set_fact(
      "display",
      "active.width",
      geometry_fixture.fact("active.width", 90, 100),
    )
  let assert Ok(instance) = r.find_instance(value, "part-a")
  let region = projection.active(instance, value)
  projection.possible(region) |> should.equal(Some(Rectangle(10, 10, 115, 90)))
  projection.guaranteed(region)
  |> should.equal(Some(Rectangle(15, 10, 100, 90)))
}

pub fn absent_offsets_and_out_of_outline_regions_are_unusable_test() {
  let value =
    fixture.resolved()
    |> fixture.set_fact(
      "display",
      "active.offset.x",
      p.Fact("active.offset.x", [], "um", p.Missing),
    )
  let assert Ok(instance) = r.find_instance(value, "part-a")
  let region = projection.active(instance, value)
  projection.guaranteed(region) |> should.equal(None)
  projection.unavailable_reason(region) |> should.equal("missing_fact")
  let value =
    fixture.set_fact(
      value,
      "display",
      "active.offset.x",
      fixture.fact("active.offset.x", 11),
    )
  let region = projection.active(instance, value)
  projection.possible(region) |> should.equal(None)
  projection.unavailable_reason(region)
  |> should.equal("region_outside_outline")
}

pub fn uncertainty_can_remove_guaranteed_area_and_outline_stays_anchored_test() {
  let value =
    fixture.resolved()
    |> fixture.set_fact(
      "display",
      "active.offset.x",
      geometry_fixture.fact("active.offset.x", 0, 50),
    )
    |> fixture.set_fact(
      "display",
      "active.width",
      fixture.fact("active.width", 10),
    )
  let assert Ok(instance) = r.find_instance(value, "part-a")
  let region = projection.active(instance, value)
  projection.possible(region) |> should.equal(Some(Rectangle(10, 10, 70, 90)))
  projection.guaranteed(region) |> should.equal(None)
  projection.unavailable_reason(region) |> should.equal("no_guaranteed_region")
  let value =
    fixture.set_fact(
      value,
      "display",
      "outline.height",
      geometry_fixture.fact("outline.height", 90, 100),
    )
    |> fixture.place("part-a", a.Placement(90, 10, 10, 10))
  let assert Ok(instance) = r.find_instance(value, "part-a")
  projection.possible(projection.outline(instance, value))
  |> should.equal(Some(Rectangle(10, 10, 110, 120)))
  projection.guaranteed(projection.outline(instance, value))
  |> should.equal(Some(Rectangle(10, 10, 100, 120)))
}
