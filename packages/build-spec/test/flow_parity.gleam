import flow_fixture
import frameshift_build/assembly/model as a
import frameshift_build/compiler/power_context as ctx
import frameshift_build/compiler/power_current
import frameshift_build/compiler/power_loads
import frameshift_build/compiler/power_voltage
import frameshift_physical.{type Interval}
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import load_fixture
import power_fixture

fn interval(value: Option(Interval)) -> json.Json {
  case value {
    None -> json.null()
    Some(i) -> json.array([i.minimum, i.maximum], json.int)
  }
}

pub fn main() {
  int.range(0, 256, Nil, fn(_, seed) {
    let length = seed % 8 + 1
    let branches = { seed / 8 } % 4 + 1
    let voltage_low = 4801 + seed
    let voltage_high = voltage_low + seed % 37
    let drop_low = seed % 5
    let drop_high = drop_low + seed % 23
    let current_low = seed % 127 + 1
    let current_high = current_low + seed % 43
    let tail = flow_fixture.id(length - 1)
    let value =
      flow_fixture.chain(length)
      |> power_fixture.set_fact(
        "controller",
        power_fixture.number("output.voltage", voltage_low, voltage_high),
      )
      |> power_fixture.set_fact(
        "passive-0",
        power_fixture.number("voltage.drop", drop_low, drop_high),
      )
      |> power_fixture.set_fact(
        "panel",
        load_fixture.number("current.maximum", "ma", current_low, current_high),
      )
      |> flow_fixture.branches(tail, branches)
    let context = ctx.prepare(value)
    let voltage =
      power_voltage.inspect(a.Endpoint(tail, "out"), context).trace.value
    let current =
      power_current.demand(a.Endpoint("passive-0", "in"), context).value
    let findings = power_loads.evaluate(value)
    let powers =
      list.map(["controller", tail], fn(id) {
        let assert Ok(f) =
          list.find(findings, fn(f) {
            f.check.code == "power.output_capacity"
            && list.first(f.check.instances) == Ok(id)
          })
        let assert Some(measurement) = f.measurement
        interval(measurement.required)
      })
    json.object([
      #("seed", json.int(seed)),
      #("length", json.int(length)),
      #("branches", json.int(branches)),
      #("voltage", json.array([voltage_low, voltage_high], json.int)),
      #("drop", json.array([drop_low, drop_high], json.int)),
      #("current", json.array([current_low, current_high], json.int)),
      #("effective_voltage", interval(voltage)),
      #("effective_current", interval(current)),
      #("power", json.array(powers, fn(p) { p })),
    ])
    |> json.to_string
    |> io.println
  })
}
