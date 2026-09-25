import frameshift_build/model as p
import frameshift_build/resolution as r
import gleam/list
import load_fixture
import power_fixture

pub fn signals(value: r.Resolution) -> r.Resolution {
  r.Resolution(
    ..value,
    profiles: list.map(value.profiles, fn(profile) {
      r.ResolvedProfile(
        ..profile,
        profile: p.Profile(
          ..profile.profile,
          ports: list.map(profile.profile.ports, fn(port) {
            let voltage = case port.direction {
              "source" -> power_fixture.number("logic.voltage", 2700, 3300)
              _ -> power_fixture.number("logic.voltage", 2500, 3600)
            }
            p.Port(..port, kind: "signal", facts: [
              voltage,
              power_fixture.terms("driver.contract", ["fixture-driver"]),
              ..port.facts
            ])
          }),
        ),
      )
    }),
  )
  |> load_fixture.canonical
}

pub fn resolved() -> r.Resolution {
  signals(power_fixture.resolved())
}
