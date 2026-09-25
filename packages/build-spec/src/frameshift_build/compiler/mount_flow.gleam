/// Single-parent support paths and complete downstream mass. A grouped joint
/// must qualify any load sharing; ambiguous input feeds have no known demand.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/evidence
import frameshift_build/compiler/facts.{type Reading}
import frameshift_build/compiler/finding
import frameshift_build/compiler/model.{type Input, BuildInput}
import frameshift_build/compiler/mount_context.{type Context} as ctx
import frameshift_build/compiler/ports
import frameshift_build/resolution
import frameshift_physical.{type Interval, Compatible}
import gleam/list
import gleam/option.{type Option, None, Some}

pub type Demand {
  Demand(
    mass: Option(Interval),
    readings: List(Reading),
    inputs: List(Input),
    reason: String,
  )
}

pub type Path {
  Path(
    anchor: Option(a.Instance),
    readings: List(Reading),
    inputs: List(Input),
    reason: String,
  )
}

pub fn demand(endpoint: a.Endpoint, context: Context) -> Demand {
  load(endpoint, [], context)
}

pub fn path(instance: a.Instance, context: Context) -> Path {
  root(instance, [], context)
}

pub fn combined(
  demands: List(Demand),
  readings: List(Reading),
  inputs: List(Input),
) -> Demand {
  let reason = case list.find(demands, fn(d) { d.mass == None }) {
    Ok(d) -> d.reason
    Error(_) -> "incomplete_supported_mass"
  }
  result(
    finding.sum(list.map(demands, fn(d) { d.mass })),
    list.append(readings, list.flat_map(demands, fn(d) { d.readings })),
    list.append(inputs, list.flat_map(demands, fn(d) { d.inputs })),
    reason,
  )
}

pub fn result(
  mass: Option(Interval),
  readings: List(Reading),
  inputs: List(Input),
  reason: String,
) -> Demand {
  Demand(mass, evidence.readings(readings), evidence.inputs(inputs), case mass {
    Some(_) -> "known_supported_mass"
    None -> finding.unknown_reason(readings, reason)
  })
}

fn load(endpoint: a.Endpoint, seen: List(String), context: Context) -> Demand {
  case ports.resolve(endpoint, context.value) {
    Error(_) ->
      case resolution.find_instance(context.value, endpoint.instance) {
        Error(_) ->
          result(None, [], [BuildInput(["instances"])], "unresolved_endpoint")
        Ok(instance) ->
          result(
            None,
            [
              facts.port(
                instance,
                endpoint.port,
                "mount.capacity",
                context.value,
              ),
            ],
            ctx.inputs(instance),
            "unresolved_endpoint",
          )
      }
    Ok(to) -> {
      let mode = ctx.mode(to.instance, context)
      let permitted =
        to.port.kind == "mechanical"
        && to.port.direction == "sink"
        && mode.kind == "supported"
        && mode.finding.check.outcome == Compatible
      case permitted, ctx.visited(to.instance, seen) {
        _, True ->
          result(
            None,
            [mode.reading],
            ctx.inputs(to.instance),
            "mount_flow_cycle",
          )
        False, _ ->
          result(
            None,
            [mode.reading],
            ctx.inputs(to.instance),
            "unsupported_mount_scope",
          )
        True, False -> supported(to, mode, [to.instance.id, ..seen], context)
      }
    }
  }
}

fn supported(
  to: ports.Endpoint,
  mode: ctx.Mode,
  seen: List(String),
  context: Context,
) -> Demand {
  case ctx.incoming(ctx.key(to), context) {
    [] ->
      result(None, [mode.reading], ctx.inputs(to.instance), "missing_support")
    [connection] ->
      case ctx.source(connection, context) {
        Error(_) ->
          result(
            None,
            [mode.reading],
            ports.inputs(connection, context.value),
            "unresolved_support_source",
          )
        Ok(_) -> {
          let mass = facts.component(to.instance, "mass", context.value)
          let own =
            result(
              finding.interval(mass),
              [mode.reading, mass],
              list.append(
                ctx.inputs(to.instance),
                ports.inputs(connection, context.value),
              ),
              "incomplete_mass",
            )
          let children =
            list.map(ctx.children(mode, context), fn(c) {
              load(c.to, seen, context)
            })
          combined([own, ..children], [], [])
        }
      }
    _ ->
      result(None, [mode.reading], ctx.inputs(to.instance), "ambiguous_support")
  }
}

fn root(instance: a.Instance, seen: List(String), context: Context) -> Path {
  let mode = ctx.mode(instance, context)
  let base =
    Path(None, [mode.reading], ctx.inputs(instance), "unsupported_mount_scope")
  case
    ctx.visited(instance, seen),
    mode.finding.check.outcome == Compatible,
    mode.kind
  {
    True, _, _ -> Path(..base, reason: "mount_flow_cycle")
    False, True, "anchor" ->
      Path(..base, anchor: Some(instance), reason: "anchored_support_path")
    False, True, "supported" ->
      parent(mode, [instance.id, ..seen], base, context)
    _, _, _ ->
      Path(..base, reason: finding.unknown_reason([mode.reading], base.reason))
  }
}

fn parent(
  mode: ctx.Mode,
  seen: List(String),
  base: Path,
  context: Context,
) -> Path {
  case ctx.input(mode) {
    Error(_) -> base
    Ok(input) ->
      case ctx.incoming(ctx.key(input), context) {
        [] -> Path(..base, reason: "missing_support")
        [connection] ->
          case ctx.source(connection, context) {
            Error(_) ->
              Path(
                ..base,
                reason: "unresolved_support_source",
                inputs: evidence.inputs(list.append(
                  base.inputs,
                  ports.inputs(connection, context.value),
                )),
              )
            Ok(from) -> {
              let parent = root(from.instance, seen, context)
              Path(
                parent.anchor,
                evidence.readings(list.append(base.readings, parent.readings)),
                evidence.inputs(
                  list.flatten([
                    base.inputs,
                    parent.inputs,
                    ports.inputs(connection, context.value),
                  ]),
                ),
                parent.reason,
              )
            }
          }
        _ -> Path(..base, reason: "ambiguous_support")
      }
  }
}
