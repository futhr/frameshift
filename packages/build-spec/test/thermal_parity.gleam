import frameshift_build/assembly/model as a
import frameshift_build/compiler/thermal
import frameshift_build/resolution as r
import frameshift_physical.{type Interval, Compatible, Incompatible, Unknown}
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import load_fixture
import thermal_fixture

fn interval(value: Option(Interval)) -> json.Json {
  case value {
    None -> json.null()
    Some(i) -> json.array([i.minimum, i.maximum], json.int)
  }
}

pub fn main() {
  int.range(0, 256, Nil, fn(_, seed) {
    let count = seed % 8 + 1
    let ambient_low = -10_000 + seed * 37
    let ambient_high = ambient_low + 100 + seed % 13
    let rise_low = seed % 80
    let rise_high = rise_low + 51
    let heat_low = seed * 13 + 1
    let heat_high = heat_low + 17
    let permitted_low = ambient_low + rise_low + seed % 3 - 1
    let permitted_high = ambient_high + rise_high + { seed / 3 } % 3 - 1
    let capacity = heat_high * count + 23 + { seed / 9 } % 3 - 1
    let value =
      thermal_fixture.resolved()
      |> thermal_fixture.ambient(ambient_low, ambient_high)
      |> load_fixture.component(
        "part-a",
        load_fixture.number(
          "temperature.ambient_rise",
          "mc",
          rise_low,
          rise_high,
        ),
      )
      |> load_fixture.component(
        "part-a",
        load_fixture.number(
          "temperature.operating",
          "mc",
          permitted_low,
          permitted_high,
        ),
      )
      |> load_fixture.component(
        "part-a",
        load_fixture.number("heat.maximum", "mw", heat_low, heat_high),
      )
      |> load_fixture.component(
        "frame",
        load_fixture.number("heat.maximum", "mw", 0, 23),
      )
      |> load_fixture.component(
        "frame",
        load_fixture.number("thermal.capacity", "mw", capacity, capacity),
      )
    let assert Ok(part) = r.find_instance(value, "part-a")
    let assert Ok(frame) = r.find_instance(value, "frame")
    let instances =
      int.range(
        0,
        count,
        [frame, a.Instance(..part, id: "external", location: "external")],
        fn(acc, n) {
          [a.Instance(..part, id: "part-" <> int.to_string(n)), ..acc]
        },
      )
    let value =
      load_fixture.canonical(
        r.Resolution(
          ..value,
          assembly: a.Assembly(..value.assembly, instances:),
        ),
      )
    let findings = thermal.evaluate(value)
    let selected = [
      #("thermal.operating", "part-0"),
      #("thermal.operating", "external"),
      #("thermal.capacity", "frame"),
    ]
    let actual =
      list.map(selected, fn(selection) {
        let assert Ok(f) =
          list.find(findings, fn(f) {
            f.check.code == selection.0
            && list.contains(f.check.instances, selection.1)
          })
        let assert Some(m) = f.measurement
        json.object([
          #("required", interval(m.required)),
          #(
            "outcome",
            json.string(case f.check.outcome {
              Compatible -> "compatible"
              Incompatible -> "incompatible"
              Unknown -> "unknown"
            }),
          ),
        ])
      })
    json.object([
      #("seed", json.int(seed)),
      #("count", json.int(count)),
      #("ambient", json.array([ambient_low, ambient_high], json.int)),
      #("rise", json.array([rise_low, rise_high], json.int)),
      #("operating", json.array([permitted_low, permitted_high], json.int)),
      #("heat", json.array([heat_low, heat_high], json.int)),
      #("frame_heat", json.array([0, 23], json.int)),
      #("capacity", json.int(capacity)),
      #("actual", json.array(actual, fn(a) { a })),
    ])
    |> json.to_string
    |> io.println
  })
}
