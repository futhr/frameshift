import assembly_fixture
import frameshift_build
import frameshift_build/assembly
import frameshift_build/assembly/model as a
import frameshift_build/model as p
import frameshift_build/resolution
import profile_fixture

pub fn resolved() -> resolution.Resolution {
  let plan = assembly_fixture.assembly(0)
  let display =
    p.Profile(..profile_fixture.profile(0), requires: ["controller"])
  let assert [port] = display.ports
  let controller =
    p.Profile(
      ..profile_fixture.profile(1),
      kind: "controller",
      classes: ["paper"],
      requires: [],
      ports: [p.Port(..port, id: "out", direction: "source")],
    )
  let plan =
    a.Assembly(..plan, connections: [
      a.Connection(a.Endpoint("controller", "out"), a.Endpoint("panel", "dc")),
    ])
  let assert [panel, control] = plan.instances
  let assert Ok(bytes) = assembly.encode(plan)
  let assert Ok(first) = frameshift_build.encode(display)
  let assert Ok(second) = frameshift_build.encode(controller)
  let assert Ok(resolved) =
    resolution.resolve(bytes, [
      #(panel.profile, first),
      #(control.profile, second),
    ])
  resolved
}

pub fn edges(mask: Int) -> List(#(String, String)) {
  select(mask, [
    #("a", "a"),
    #("a", "b"),
    #("a", "c"),
    #("b", "a"),
    #("b", "b"),
    #("b", "c"),
    #("c", "a"),
    #("c", "b"),
    #("c", "c"),
  ])
}

fn select(
  mask: Int,
  edges: List(#(String, String)),
) -> List(#(String, String)) {
  case edges {
    [] -> []
    [edge, ..rest] ->
      case mask % 2 {
        1 -> [edge, ..select(mask / 2, rest)]
        _ -> select(mask / 2, rest)
      }
  }
}
