import frameshift_build/compiler/power_interfaces
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import power_fixture

pub fn main() {
  let intervals =
    int.range(0, 6, [], fn(acc, low) {
      int.range(low, 6, acc, fn(acc, high) { [#(low, high), ..acc] })
    })
    |> list.reverse
  list.each(intervals, fn(output) {
    list.each(intervals, fn(input) {
      let value =
        power_fixture.resolved()
        |> power_fixture.set_fact(
          "controller",
          power_fixture.number("output.voltage", output.0, output.1),
        )
        |> power_fixture.set_fact(
          "panel",
          power_fixture.number("input.voltage", input.0, input.1),
        )
      let assert [voltage, ..] = power_interfaces.evaluate(value)
      let result = case voltage.check.outcome {
        Compatible -> "compatible"
        Incompatible -> "incompatible"
        Unknown -> "unknown"
      }
      json.object([
        #("output", json.array([output.0, output.1], json.int)),
        #("input", json.array([input.0, input.1], json.int)),
        #("outcome", json.string(result)),
      ])
      |> json.to_string
      |> io.println
    })
  })
}
