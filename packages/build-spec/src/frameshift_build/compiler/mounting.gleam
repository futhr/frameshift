/// Declared mounting trees and payload ratings, separate from joint/anchor
/// qualification and from the geometry/strain-relief constraints.
import frameshift_build/compiler/facts
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{BuildInput, Check}
import frameshift_build/compiler/mount_context.{type Context, type Mode} as ctx
import frameshift_build/compiler/mount_flow.{type Demand}
import frameshift_build/compiler/mount_interfaces
import frameshift_build/compiler/ports
import frameshift_build/graph
import frameshift_build/model.{type Refusal} as _
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/list
import gleam/option.{None, Some}
import gleam/result

pub fn evaluate(value: Resolution) -> Result(List(Finding), Refusal) {
  let context = ctx.prepare(value)
  use interfaces <- result.try(mount_interfaces.evaluate(value))
  use cycle <- result.try(cycle(context))
  Ok(
    list.flatten([
      [cycle],
      interfaces,
      list.flat_map(context.modes, fn(mode) {
        list.flatten([
          [mode.finding, mass(mode, context)],
          feed(mode, context),
          anchor(mode, context),
          path(mode, context),
          budgets(mode, context),
        ])
      }),
    ]),
  )
}

fn mass(mode: Mode, context: Context) -> Finding {
  let reading = facts.component(mode.instance, "mass", context.value)
  let #(outcome, reason) = case facts.numeric(reading) {
    Ok(_) -> #(Compatible, "known_mass")
    Error(_) -> #(Unknown, finding.unknown_reason([reading], "incomplete_mass"))
  }
  finding.explain(
    Check(
      "mount.mass",
      outcome,
      reason,
      [mode.instance.id],
      ctx.inputs(mode.instance),
    ),
    [reading],
  )
}

fn feed(mode: Mode, context: Context) -> List(Finding) {
  case mode.kind, ctx.input(mode) {
    "supported", Ok(input) -> {
      let connections = ctx.incoming(ctx.key(input), context)
      let #(outcome, reason) = case connections {
        [] -> #(Unknown, "missing_support")
        [_] -> #(Compatible, "single_support")
        _ -> #(Unknown, "ambiguous_support")
      }
      let demand = mount_flow.demand(ctx.key(input), context)
      let rating =
        facts.port(
          mode.instance,
          input.port.id,
          "mount.capacity",
          context.value,
        )
      [
        finding.explain(
          Check(
            "mount.feed",
            outcome,
            reason,
            [mode.instance.id],
            list.append(
              ctx.inputs(mode.instance),
              list.flat_map(connections, ports.inputs(_, context.value)),
            ),
          ),
          [mode.reading],
        ),
        finding.at_most(
          Check(
            "mount.input_capacity",
            Unknown,
            demand.reason,
            [mode.instance.id],
            demand.inputs,
          ),
          [rating, ..demand.readings],
          "g",
          demand.mass,
          finding.interval(rating),
        ),
      ]
    }
    _, _ -> []
  }
}

fn anchor(mode: Mode, context: Context) -> List(Finding) {
  case mode.kind == "anchor" {
    False -> []
    True -> {
      let reading =
        facts.component(mode.instance, "mount.contract", context.value)
      let #(outcome, reason, terms) = case facts.terms(reading) {
        Ok(terms) -> #(Compatible, "declared_anchor_contract", terms)
        Error(_) -> #(
          Unknown,
          finding.unknown_reason([reading], "incomplete_anchor_contract"),
          [],
        )
      }
      [
        finding.explain(
          Check(
            "mount.anchor_contract",
            outcome,
            reason,
            [mode.instance.id],
            ctx.inputs(mode.instance),
          ),
          [reading],
        )
        |> finding.with_terms(terms),
      ]
    }
  }
}

fn path(mode: Mode, context: Context) -> List(Finding) {
  case mode.instance.location == "external" {
    True -> []
    False -> {
      let path = mount_flow.path(mode.instance, context)
      let base =
        Check(
          "mount.path",
          Unknown,
          path.reason,
          [mode.instance.id],
          path.inputs,
        )
      let path_check = case path.anchor {
        None -> finding.explain(base, path.readings)
        Some(anchor) ->
          finding.explain(
            Check(
              ..base,
              outcome: Compatible,
              instances: list.unique([mode.instance.id, anchor.id]),
            ),
            path.readings,
          )
      }
      let installation = case path.anchor {
        None ->
          finding.explain(
            Check(..base, code: "mount.installation"),
            path.readings,
          )
        Some(anchor) -> {
          let reading = facts.component(anchor, "mount.kind", context.value)
          let #(outcome, reason) = case facts.terms(reading) {
            Error(_) -> #(
              Unknown,
              finding.unknown_reason([reading], "incomplete_mount_kind"),
            )
            Ok(terms) ->
              case
                list.contains(terms, context.value.assembly.intent.mounting)
              {
                True -> #(Compatible, "installation_kind_agrees")
                False -> #(Incompatible, "installation_kind_mismatch")
              }
          }
          finding.explain(
            Check(
              code: "mount.installation",
              outcome:,
              reason:,
              instances: list.unique([mode.instance.id, anchor.id]),
              inputs: [BuildInput(["intent", "mounting"]), ..path.inputs],
            ),
            [reading, ..path.readings],
          )
        }
      }
      [path_check, installation]
    }
  }
}

fn port_budget(
  port: ports.Endpoint,
  context: Context,
) -> #(Demand, List(Finding)) {
  let connections = ctx.outgoing(ctx.key(port), context)
  let demands =
    list.map(connections, fn(c) { mount_flow.demand(c.to, context) })
  let scope = ctx.mode(port.instance, context)
  let demand =
    mount_flow.combined(demands, [scope.reading], ctx.inputs(port.instance))
  let demand = case scope.finding.check.outcome == Compatible {
    True -> demand
    False ->
      mount_flow.result(
        None,
        demand.readings,
        demand.inputs,
        "unsupported_mount_scope",
      )
  }
  let rating =
    facts.port(port.instance, port.port.id, "mount.capacity", context.value)
  let fanout =
    facts.port(port.instance, port.port.id, "fanout.maximum", context.value)
  let base =
    Check(
      "mount.output_capacity",
      Unknown,
      demand.reason,
      [port.instance.id],
      demand.inputs,
    )
  #(demand, [
    finding.at_most(
      base,
      [rating, ..demand.readings],
      "g",
      demand.mass,
      finding.interval(rating),
    ),
    finding.at_most(
      Check(..base, code: "mount.fanout"),
      [fanout],
      "count",
      finding.constant(list.length(connections)),
      finding.interval(fanout),
    ),
  ])
}

fn budgets(mode: Mode, context: Context) -> List(Finding) {
  let outputs =
    ctx.outputs(mode)
    |> list.filter(fn(p) { !list.is_empty(ctx.outgoing(ctx.key(p), context)) })
  case outputs {
    [] -> []
    _ -> {
      let budgets = list.map(outputs, port_budget(_, context))
      let demand = mount_flow.combined(list.map(budgets, fn(b) { b.0 }), [], [])
      let capacity =
        facts.component(mode.instance, "mount.capacity", context.value)
      [
        finding.at_most(
          Check(
            "mount.shared_capacity",
            Unknown,
            demand.reason,
            [mode.instance.id],
            demand.inputs,
          ),
          [capacity, ..demand.readings],
          "g",
          demand.mass,
          finding.interval(capacity),
        ),
        ..list.flat_map(budgets, fn(b) { b.1 })
      ]
    }
  }
}

fn cycle(context: Context) -> Result(Finding, Refusal) {
  let connections =
    list.filter(context.value.assembly.connections, fn(c) {
      case
        ports.resolve(c.from, context.value),
        ports.resolve(c.to, context.value)
      {
        Ok(from), Ok(to) ->
          from.port.kind == "mechanical" && to.port.kind == "mechanical"
        _, _ -> False
      }
    })
  use cyclic <- result.try(graph.cyclic_nodes(
    list.map(context.modes, fn(m) { m.instance.id }),
    list.map(connections, fn(c) { #(c.from.instance, c.to.instance) }),
  ))
  let #(outcome, reason) = case cyclic {
    [] -> #(Compatible, "acyclic")
    _ -> #(Incompatible, "cycle_detected")
  }
  Ok(
    finding.explain(
      Check("mount.acyclic", outcome, reason, cyclic, [
        BuildInput(["connections"]),
        ..list.flat_map(connections, ports.inputs(_, context.value))
      ]),
      [],
    ),
  )
}
