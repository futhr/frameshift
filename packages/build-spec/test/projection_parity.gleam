import frameshift_build/assembly/model as a
import frameshift_build/compiler/projection
import frameshift_build/compiler/rectangles.{type Rectangle}
import frameshift_build/model.{KnownRange} as _
import frameshift_build/resolution
import geometry_fixture
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import viewing_fixture

pub fn main() {
  int.range(0, 256, Nil, fn(_, seed) {
    let facts = [
      geometry_fixture.fact(
        "outline.width",
        40 + seed % 13,
        42 + seed % 13 + seed % 5,
      ),
      geometry_fixture.fact(
        "outline.height",
        30 + seed % 17,
        32 + seed % 17 + seed % 3,
      ),
      geometry_fixture.fact("active.width", 20, 22),
      geometry_fixture.fact("active.height", 10, 12),
      geometry_fixture.fact("active.offset.x", 3, 4 + seed % 3),
      geometry_fixture.fact("active.offset.y", 5, 6 + seed % 2),
    ]
    let value =
      list.fold(facts, viewing_fixture.resolved(), fn(value, fact) {
        viewing_fixture.set_fact(value, "display", fact.key, fact)
      })
      |> viewing_fixture.place(
        "part-a",
        a.Placement(90 * { seed % 4 }, seed % 11, seed % 7, 10),
      )
    let assert Ok(instance) = resolution.find_instance(value, "part-a")
    let region = projection.active(instance, value)
    let facts =
      list.map(facts, fn(fact) {
        let assert KnownRange(low, high) = fact.value
        #(fact.key, json.array([low, high], json.int))
      })
    json.object([
      #("seed", json.int(seed)),
      #("facts", json.object(facts)),
      #("possible", rectangle(projection.possible(region))),
      #("guaranteed", rectangle(projection.guaranteed(region))),
    ])
    |> json.to_string
    |> io.println
  })
}

fn rectangle(value: Option(Rectangle)) -> json.Json {
  case value {
    None -> json.null()
    Some(r) -> json.array([r.left, r.top, r.right, r.bottom], json.int)
  }
}
