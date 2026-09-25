import frameshift_build/assembly/model as a
import frameshift_build/resolution as r
import geometry_fixture
import gleam/list
import load_fixture
import power_fixture

pub fn ambient(value: r.Resolution, low: Int, high: Int) -> r.Resolution {
  r.Resolution(
    ..value,
    assembly: a.Assembly(
      ..value.assembly,
      intent: a.Intent(..value.assembly.intent, ambient_mc: a.Range(low, high)),
    ),
  )
}

pub fn resolved() -> r.Resolution {
  geometry_fixture.resolved(0)
  |> load_fixture.component(
    "frame",
    load_fixture.number("heat.maximum", "mw", 0, 0),
  )
  |> load_fixture.component(
    "part-a",
    load_fixture.number("heat.maximum", "mw", 1000, 1200),
  )
  |> load_fixture.component(
    "frame",
    load_fixture.number("temperature.operating", "mc", -20_000, 50_000),
  )
  |> load_fixture.component(
    "part-a",
    load_fixture.number("temperature.operating", "mc", -20_000, 40_000),
  )
  |> load_fixture.component(
    "part-a",
    load_fixture.number("temperature.ambient_rise", "mc", 1000, 5000),
  )
  |> load_fixture.component(
    "frame",
    load_fixture.number("thermal.ambient", "mc", -20_000, 35_000),
  )
  |> load_fixture.component(
    "frame",
    load_fixture.number("thermal.capacity", "mw", 2400, 2600),
  )
  |> load_fixture.component(
    "frame",
    power_fixture.terms("assembly.thermal", ["fixture-v1"]),
  )
  |> load_fixture.component(
    "part-a",
    power_fixture.terms("assembly.thermal", ["fixture-v1"]),
  )
  |> load_fixture.canonical
}

pub fn instance(
  value: r.Resolution,
  id: String,
  change: fn(a.Instance) -> a.Instance,
) -> r.Resolution {
  r.Resolution(
    ..value,
    assembly: a.Assembly(
      ..value.assembly,
      instances: list.map(value.assembly.instances, fn(i) {
        case i.id == id {
          True -> change(i)
          False -> i
        }
      }),
    ),
  )
}
