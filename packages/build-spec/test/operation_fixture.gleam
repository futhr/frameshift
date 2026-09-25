import frameshift_build/assembly/model as a
import frameshift_build/model as p
import frameshift_build/resolution as r
import load_fixture
import power_fixture

pub fn resolved() -> r.Resolution {
  let value = power_fixture.resolved()
  let intent = value.assembly.intent
  value
  |> load_fixture.component(
    "controller",
    power_fixture.terms("artifact.contract", [intent.artifact]),
  )
  |> load_fixture.component(
    "controller",
    power_fixture.terms("firmware.contract", [intent.firmware]),
  )
  |> load_fixture.component(
    "controller",
    power_fixture.terms("protocol.contract", [intent.protocol]),
  )
  |> load_fixture.component(
    "controller",
    load_fixture.number(
      "storage.capacity",
      "byte",
      intent.storage_bytes,
      intent.storage_bytes,
    ),
  )
  |> load_fixture.component(
    "controller",
    load_fixture.number("refresh.minimum", "ms", 1, 1000),
  )
  |> load_fixture.component(
    "controller",
    load_fixture.number("refresh.maximum", "ms", 604_800_000, 604_800_000),
  )
  |> load_fixture.component(
    "panel",
    load_fixture.number("refresh.minimum", "ms", 1000, 2000),
  )
  |> load_fixture.component(
    "panel",
    load_fixture.number("refresh.maximum", "ms", 3_600_000, 7_200_000),
  )
  |> load_fixture.canonical
}

pub fn external(value: r.Resolution) -> r.Resolution {
  let assert Ok(controller) = r.find_instance(value, "controller")
  let assert Ok(profile) = r.find_profile(value, controller.profile)
  let pin =
    "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
  let storage = a.Instance(..controller, id: "storage", profile: pin)
  let storage_profile =
    p.Profile(
      ..profile,
      id: "fixture-storage",
      kind: "storage",
      ports: [],
      requires: [],
      facts: [
        load_fixture.number("storage.capacity", "byte", 5_000_000, 5_000_000),
      ],
    )
  load_fixture.canonical(
    r.Resolution(
      ..value,
      profiles: [r.ResolvedProfile(pin, storage_profile), ..value.profiles],
      assembly: a.Assembly(
        ..value.assembly,
        instances: [storage, ..value.assembly.instances],
        dependencies: [
          a.Dependency("controller", "storage", "storage"),
          ..value.assembly.dependencies
        ],
      ),
    ),
  )
}
