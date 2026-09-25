import frameshift_build/assembly/model as a
import frameshift_build/compiler/model.{BuildInput, MappingInput, ProfileInput}
import frameshift_build/compiler/signal_mapping.{Mapping}
import frameshift_build/compiler/signal_routes
import frameshift_build/mapping/model.{Pair} as _
import frameshift_build/model as p
import frameshift_build/resolution as r
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/int
import gleam/list
import gleeunit/should
import load_fixture
import power_fixture
import route_fixture as fixture
import signal_fixture

fn one(value, mappings) {
  let assert Ok([finding]) = signal_routes.evaluate(value, mappings)
  finding
}

pub fn direct_route_reaches_declared_controller_with_exact_edge_evidence_test() {
  let value = signal_fixture.resolved()
  let f = one(value, [])
  f.check.outcome |> should.equal(Compatible)
  f.check.reason |> should.equal("controller_route_present")
  list.contains(
    f.check.inputs,
    BuildInput(["connections", "controller", "out", "panel", "dc"]),
  )
  |> should.be_true
  list.contains(f.check.inputs, BuildInput(["dependencies"])) |> should.be_true
}

pub fn adapter_needs_explicit_mapping_and_retains_its_exact_scope_test() {
  let value = fixture.adapted()
  one(value, []).check.reason |> should.equal("missing_internal_signal_mapping")
  let mapping = fixture.mapping(value)
  let f = one(value, [mapping])
  f.check.outcome |> should.equal(Compatible)
  list.contains(
    f.check.inputs,
    MappingInput("adapter", mapping.identity, ["pairs", "in", "out"]),
  )
  |> should.be_true
  list.contains(
    f.check.inputs,
    ProfileInput("adapter", mapping.profile, ["ports", "in"]),
  )
  |> should.be_true
  list.contains(f.check.inputs, BuildInput(["intent", "firmware"]))
  |> should.be_true
}

pub fn optional_missing_and_multiple_upstream_feeds_cannot_establish_route_test() {
  let value = fixture.adapted()
  let mapping = fixture.mapping(value)
  let changed =
    power_fixture.change(value, "adapter", fn(port) {
      p.Port(..port, required: False)
    })
  let missing =
    r.Resolution(
      ..changed,
      assembly: a.Assembly(
        ..changed.assembly,
        connections: list.filter(changed.assembly.connections, fn(c) {
          c.from.instance != "controller"
        }),
      ),
    )
  one(missing, [mapping]).check.reason |> should.equal("missing_signal_feed")
  let ambiguous =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, connections: [
        a.Connection(a.Endpoint("panel", "dc"), a.Endpoint("adapter", "in")),
        ..value.assembly.connections
      ]),
    )
  one(ambiguous, [mapping]).check.reason
  |> should.equal("multiple_signal_feeds")
}

pub fn wrong_root_is_incompatible_and_an_orphan_owner_stays_unknown_test() {
  let value = signal_fixture.resolved()
  let assert Ok(controller) = r.find_instance(value, "controller")
  let wrong =
    r.Resolution(
      ..value,
      assembly: a.Assembly(
        ..value.assembly,
        instances: [
          a.Instance(..controller, id: "other"),
          ..value.assembly.instances
        ],
        connections: [
          a.Connection(a.Endpoint("other", "out"), a.Endpoint("panel", "dc")),
        ],
      ),
    )
  let f = one(wrong, [])
  f.check.outcome |> should.equal(Incompatible)
  f.check.reason |> should.equal("wrong_controller_route")
  f.check.instances |> should.equal(["panel", "controller", "other"])
  let orphan =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, dependencies: []),
    )
  one(orphan, []).check.reason |> should.equal("missing_controller_owner")
}

pub fn every_required_or_connected_display_input_is_checked_test() {
  let value = signal_fixture.resolved()
  let add = fn(required) {
    r.Resolution(
      ..value,
      profiles: list.map(value.profiles, fn(resolved) {
        case resolved.profile.kind == "display" {
          True -> {
            let assert [port] = resolved.profile.ports
            r.ResolvedProfile(
              ..resolved,
              profile: p.Profile(..resolved.profile, ports: [
                p.Port(..port, id: "second", required:),
                p.Port(..port, required: False),
              ]),
            )
          }
          False -> resolved
        }
      }),
    )
  }
  one(add(False), []).check.outcome |> should.equal(Compatible)
  let assert Ok(findings) = signal_routes.evaluate(add(True), [])
  list.map(findings, fn(f) { f.check.outcome })
  |> should.equal([Unknown, Compatible])
  let disconnected =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, connections: []),
    )
  one(disconnected, []).check.reason |> should.equal("missing_signal_feed")
  let optional =
    power_fixture.change(disconnected, "panel", fn(p) {
      p.Port(..p, required: False)
    })
  one(optional, []).check.reason |> should.equal("missing_display_signal_input")
}

pub fn invalid_and_unresolved_physical_endpoints_remain_distinct_test() {
  let value = signal_fixture.resolved()
  let missing =
    r.Resolution(
      ..value,
      profiles: list.filter(value.profiles, fn(p) {
        p.profile.kind != "controller"
      }),
    )
  one(missing, []).check.reason |> should.equal("missing_profile")
  let reversed =
    power_fixture.change(value, "controller", fn(p) {
      p.Port(..p, direction: "sink")
    })
  one(reversed, []).check.outcome |> should.equal(Incompatible)
  let bidirectional =
    power_fixture.change(value, "controller", fn(p) {
      p.Port(..p, direction: "bidirectional")
    })
  one(bidirectional, []).check.outcome |> should.equal(Unknown)
  let absent =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, connections: [
        a.Connection(
          a.Endpoint("controller", "absent"),
          a.Endpoint("panel", "dc"),
        ),
      ]),
    )
  one(absent, []).check.reason |> should.equal("missing_port")
  let self =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, connections: [
        a.Connection(a.Endpoint("panel", "dc"), a.Endpoint("panel", "dc")),
      ]),
    )
  one(self, []).check.reason |> should.equal("self_connection")
}

pub fn port_cycles_terminate_without_using_an_unrelated_controller_test() {
  let base = fixture.adapted()
  let mapping = fixture.mapping(base)
  let value = fixture.chain(2)
  let cyclic =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, connections: [
        a.Connection(
          a.Endpoint("adapter-1", "out"),
          a.Endpoint("adapter-0", "in"),
        ),
        ..list.filter(value.assembly.connections, fn(c) {
          c.from.instance != "controller"
        })
      ]),
    )
  let f = one(cyclic, [mapping])
  f.check.outcome |> should.equal(Incompatible)
  f.check.reason |> should.equal("signal_route_cycle")
}

pub fn mapping_boundaries_refuse_stale_scope_and_malformed_ports_test() {
  let value = fixture.adapted()
  let mapping = fixture.mapping(value)
  list.each(
    [
      Mapping(..mapping, artifact: "other"),
      Mapping(..mapping, firmware: "other"),
      Mapping(..mapping, protocol: "other"),
      Mapping(
        ..mapping,
        profile: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      ),
      Mapping(..mapping, pairs: [Pair("out", "in")]),
      Mapping(..mapping, pairs: [Pair("absent", "out")]),
    ],
    fn(bad) {
      signal_routes.evaluate(value, [bad])
      |> should.equal(Error(p.InvalidReference))
    },
  )
  signal_routes.evaluate(value, [Mapping(..mapping, identity: "fake")])
  |> should.equal(Error(p.InvalidIdentity))
  signal_routes.evaluate(value, [Mapping(..mapping, pairs: [])])
  |> should.equal(Error(p.InvalidCount))
  signal_routes.evaluate(value, [
    Mapping(..mapping, pairs: [Pair("in", "out"), Pair("in", "out")]),
  ])
  |> should.equal(Error(p.DuplicateIdentifier))
  signal_routes.evaluate(value, [mapping, mapping])
  |> should.equal(Error(p.DuplicateIdentifier))
  let second =
    Mapping(
      ..mapping,
      identity: "sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
    )
  signal_routes.evaluate(value, [mapping, second])
  |> should.equal(Error(p.DuplicateIdentifier))
  let excess = int.range(0, 65, [], fn(acc, _) { [mapping, ..acc] })
  signal_routes.evaluate(value, excess) |> should.equal(Error(p.InvalidCount))
}

pub fn selected_map_does_not_cover_an_unmapped_output_test() {
  let value = fixture.adapted()
  let mapping = fixture.mapping(value)
  let extended =
    r.Resolution(
      ..value,
      profiles: list.map(value.profiles, fn(resolved) {
        case resolved.identity == mapping.profile {
          True -> {
            let assert Ok(output) =
              list.find(resolved.profile.ports, fn(p) { p.id == "out" })
            r.ResolvedProfile(
              ..resolved,
              profile: p.Profile(..resolved.profile, ports: [
                p.Port(..output, id: "unused"),
                ..resolved.profile.ports
              ]),
            )
          }
          False -> resolved
        }
      }),
    )
  one(extended, [Mapping(..mapping, pairs: [Pair("in", "unused")])]).check.reason
  |> should.equal("unmapped_signal_output")
  let unresolved =
    r.Resolution(
      ..value,
      profiles: list.filter(value.profiles, fn(p) {
        p.identity != mapping.profile
      }),
    )
  signal_routes.evaluate(unresolved, [mapping])
  |> should.equal(Error(p.InvalidReference))
}

pub fn all_repeated_units_on_a_64_instance_chain_keep_distinct_map_inputs_test() {
  let mapping = fixture.mapping(fixture.adapted())
  let value = fixture.chain(62)
  let f = one(value, [mapping])
  f.check.outcome |> should.equal(Compatible)
  list.count(f.check.inputs, fn(input) {
    case input {
      MappingInput(_, _, ["pairs", "in", "out"]) -> True
      _ -> False
    }
  })
  |> should.equal(62)
  let assert Ok(again) =
    signal_routes.evaluate(load_fixture.canonical(value), [mapping])
  again |> should.equal([f])
}

pub fn maximal_port_path_revisits_components_without_confusing_them_with_cycles_test() {
  let #(value, mapping) = fixture.maximal()
  list.length(value.assembly.connections) |> should.equal(256)
  let f = one(value, [mapping])
  f.check.outcome |> should.equal(Compatible)
  list.count(f.check.inputs, fn(input) {
    case input {
      MappingInput(_, _, ["pairs", _, _]) -> True
      _ -> False
    }
  })
  |> should.equal(255)
  let assert Ok(adapter) = r.find_instance(value, "adapter-0")
  let excess =
    r.Resolution(
      ..value,
      assembly: a.Assembly(..value.assembly, instances: [
        a.Instance(..adapter, id: "extra"),
        ..value.assembly.instances
      ]),
    )
  signal_routes.evaluate(excess, [mapping])
  |> should.equal(Error(p.InvalidCount))
}
