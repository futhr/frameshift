import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/geometry
import frameshift_physical.{type Interval, Compatible, Incompatible, Unknown}
import geometry_fixture
import gleam/int
import gleam/io
import gleam/json
import gleam/option.{type Option, None, Some}

pub fn main() {
  int.range(0, 2048, Nil, fn(_, seed) {
    json.object([
      #("seed", json.int(seed)),
      #(
        "findings",
        json.array(geometry.evaluate(geometry_fixture.resolved(seed)), encode),
      ),
    ])
    |> json.to_string
    |> io.println
  })
}

fn encode(value: Finding) -> json.Json {
  let #(required, available) = case value.measurement {
    Some(measurement) -> #(
      interval(measurement.required),
      interval(measurement.available),
    )
    None -> #(json.null(), json.null())
  }
  json.object([
    #("code", json.string(value.check.code)),
    #(
      "outcome",
      json.string(case value.check.outcome {
        Compatible -> "compatible"
        Incompatible -> "incompatible"
        Unknown -> "unknown"
      }),
    ),
    #("reason", json.string(value.check.reason)),
    #("instances", json.array(value.check.instances, json.string)),
    #("required", required),
    #("available", available),
  ])
}

fn interval(value: Option(Interval)) -> json.Json {
  case value {
    Some(value) -> json.array([value.minimum, value.maximum], json.int)
    None -> json.null()
  }
}
