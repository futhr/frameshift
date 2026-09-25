import frameshift_build/compiler/facts
import frameshift_build/compiler/model.{ProfileInput}
import frameshift_build/compiler/properties as registry
import frameshift_build/model as p
import frameshift_build/resolution as r
import gleeunit/should
import graph_fixture
import profile_fixture

fn with_facts(facts: List(p.Fact)) -> r.Resolution {
  let value = graph_fixture.resolved()
  let assert [display, controller] = value.profiles
  r.Resolution(..value, profiles: [
    r.ResolvedProfile(..display, profile: p.Profile(..display.profile, facts:)),
    controller,
  ])
}

fn read(value: r.Resolution, key: String) -> facts.Reading {
  let assert Ok(instance) = r.find_instance(value, "panel")
  facts.component(instance, key, value)
}

pub fn readings_retain_exact_scope_unit_pin_value_and_sources_test() {
  let value = graph_fixture.resolved()
  let reading = read(value, "outline.width")
  reading.status |> should.equal(facts.Usable)
  reading.expected_unit |> should.equal("um")
  reading.actual_unit |> should.equal("um")
  reading.value |> should.equal(p.KnownRange(1000, 1010))
  facts.numeric(reading) |> should.equal(Ok(#(1000, 1010)))
  facts.terms(reading) |> should.equal(Error(facts.InvalidValue))
  let contract =
    read(
      with_facts([
        p.Fact(
          "artifact.contract",
          [profile_fixture.source()],
          "token",
          p.KnownTerms(["fixture-v1"]),
        ),
      ]),
      "artifact.contract",
    )
  facts.terms(contract) |> should.equal(Ok(["fixture-v1"]))
  facts.numeric(contract) |> should.equal(Error(facts.InvalidValue))
  reading.sources |> should.equal([profile_fixture.source()])
  facts.input(reading)
  |> should.equal(
    ProfileInput("panel", reading.profile, ["facts", "outline.width"]),
  )
}

pub fn missing_bounds_never_borrow_nominal_typical_or_conditioned_values_test() {
  let source = profile_fixture.source()
  let value =
    with_facts([
      p.Fact("outline.width.nominal", [source], "um", p.KnownRange(1000, 1000)),
      p.Fact("power.typical", [source], "mw", p.KnownRange(2000, 2000)),
      p.Fact(
        "temperature.absolute",
        [source],
        "mc",
        p.KnownRange(-5000, 60_000),
      ),
    ])
  read(value, "outline.width").status |> should.equal(facts.MissingFact)
  read(value, "power.maximum").status |> should.equal(facts.MissingFact)
  read(value, "temperature.operating").status |> should.equal(facts.MissingFact)
  let nominal = read(value, "outline.width.nominal")
  nominal.status |> should.equal(facts.UnsupportedProperty)
  nominal.value |> should.equal(p.KnownRange(1000, 1000))
  nominal.sources |> should.equal([source])
  facts.numeric(nominal) |> should.equal(Error(facts.UnsupportedProperty))
}

pub fn conflicting_citations_and_explicit_missing_values_are_preserved_test() {
  let first = profile_fixture.source()
  let second = p.Source(..first, locator: "different-scope")
  let value =
    with_facts([
      p.Fact("temperature.operating", [first, second], "mc", p.Conflicting),
      p.Fact("outline.width", [], "um", p.Missing),
    ])
  let reading = read(value, "temperature.operating")
  reading.status |> should.equal(facts.ConflictingFact)
  reading.sources |> should.equal([first, second])
  reading.value |> should.equal(p.Conflicting)
  facts.numeric(reading) |> should.equal(Error(facts.ConflictingFact))
  read(value, "outline.width").status |> should.equal(facts.MissingFact)
}

pub fn wrong_units_and_zero_positive_dimensions_never_become_usable_test() {
  let source = profile_fixture.source()
  let value =
    with_facts([
      p.Fact("outline.width", [source], "mv", p.KnownRange(1000, 1010)),
    ])
  let reading = read(value, "outline.width")
  reading.status |> should.equal(facts.UnitMismatch)
  reading.expected_unit |> should.equal("um")
  reading.actual_unit |> should.equal("mv")
  facts.numeric(reading) |> should.equal(Error(facts.UnitMismatch))
  reading.value |> should.equal(p.KnownRange(1000, 1010))
  read(
    with_facts([p.Fact("outline.width", [source], "um", p.KnownRange(0, 10))]),
    "outline.width",
  ).status
  |> should.equal(facts.InvalidValue)
  read(
    with_facts([
      p.Fact(
        "temperature.operating",
        [source],
        "mc",
        p.KnownRange(-5000, 40_000),
      ),
    ]),
    "temperature.operating",
  ).status
  |> should.equal(facts.Usable)
}

pub fn port_lookup_does_not_cross_scope_or_mask_missing_profiles_and_ports_test() {
  let value = graph_fixture.resolved()
  let assert Ok(instance) = r.find_instance(value, "panel")
  facts.port(instance, "absent", "input.voltage", value).status
  |> should.equal(facts.MissingPort)
  facts.component(
    instance,
    "outline.width",
    r.Resolution(..value, profiles: []),
  ).status
  |> should.equal(facts.MissingProfile)
  let assert [display, controller] = value.profiles
  let assert [port] = display.profile.ports
  let fact =
    p.Fact(
      "input.voltage",
      [profile_fixture.source()],
      "mv",
      p.KnownRange(4750, 5250),
    )
  let display =
    r.ResolvedProfile(
      ..display,
      profile: p.Profile(..display.profile, ports: [
        p.Port(..port, facts: [fact]),
      ]),
    )
  let value = r.Resolution(..value, profiles: [display, controller])
  let reading = facts.port(instance, "dc", "input.voltage", value)
  reading.status |> should.equal(facts.Usable)
  facts.input(reading)
  |> should.equal(
    ProfileInput("panel", instance.profile, [
      "ports",
      "dc",
      "facts",
      "input.voltage",
    ]),
  )
  facts.component(instance, "input.voltage", value).status
  |> should.equal(facts.UnsupportedProperty)
  registry.lookup(registry.SignalPort, "input.voltage")
  |> should.equal(Error(Nil))
  registry.lookup(registry.PowerPort, "logic.voltage")
  |> should.equal(Error(Nil))
  registry.lookup(registry.MechanicalPort, "mount.capacity")
  |> should.equal(Ok(registry.Number("g", 0)))
}
