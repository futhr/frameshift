import frameshift_build/assembly/model as a
import frameshift_build/model as p
import frameshift_build/resolution as r
import gleam/list
import graph_fixture
import profile_fixture

pub fn number(key: String, low: Int, high: Int) -> p.Fact {
  p.Fact(key, [profile_fixture.source()], "mv", p.KnownRange(low, high))
}

pub fn terms(key: String, terms: List(String)) -> p.Fact {
  p.Fact(key, [profile_fixture.source()], "token", p.KnownTerms(terms))
}

pub fn resolved() -> r.Resolution {
  let value = graph_fixture.resolved()
  r.Resolution(
    ..value,
    profiles: list.map(value.profiles, fn(profile) {
      let ports =
        list.map(profile.profile.ports, fn(port) {
          let voltage = case port.direction {
            "source" -> number("output.voltage", 4750, 5250)
            _ -> number("input.voltage", 4500, 5500)
          }
          p.Port(..port, facts: [
            voltage,
            terms("polarity", ["positive"]),
            ..list.map(
              [
                "reference.contract",
                "pinout.contract",
                "connector.contract",
                "protection.contract",
                "strain_relief.contract",
              ],
              fn(key) { terms(key, ["fixture-" <> key]) },
            )
          ])
        })
      r.ResolvedProfile(
        ..profile,
        profile: p.Profile(..profile.profile, ports:, facts: [
          terms("power.mode", [
            case profile.profile.kind {
              "controller" -> "source"
              _ -> "consumer"
            },
          ]),
          ..list.filter(profile.profile.facts, fn(f) { f.key != "power.mode" })
        ]),
      )
    }),
  )
}

pub fn change(
  value: r.Resolution,
  id: String,
  transform: fn(p.Port) -> p.Port,
) -> r.Resolution {
  let assert Ok(instance) = r.find_instance(value, id)
  r.Resolution(
    ..value,
    profiles: list.map(value.profiles, fn(profile) {
      case profile.identity == instance.profile {
        False -> profile
        True ->
          r.ResolvedProfile(
            ..profile,
            profile: p.Profile(
              ..profile.profile,
              ports: list.map(profile.profile.ports, transform),
            ),
          )
      }
    }),
  )
}

pub fn set_fact(value: r.Resolution, id: String, fact: p.Fact) -> r.Resolution {
  change(value, id, fn(port) {
    p.Port(..port, facts: [
      fact,
      ..list.filter(port.facts, fn(f) { f.key != fact.key })
    ])
  })
}

pub fn connect(
  value: r.Resolution,
  from: a.Endpoint,
  to: a.Endpoint,
) -> r.Resolution {
  r.Resolution(
    ..value,
    assembly: a.Assembly(..value.assembly, connections: [a.Connection(from, to)]),
  )
}
