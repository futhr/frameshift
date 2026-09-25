/// Exact pixel rectangles. Logical coverage does not qualify the physical
/// orientation, pixel wiring or a driver's execution of these assignments.
import frameshift_build/artifact/model.{type Tile} as _
import frameshift_build/assembly/model as a
import frameshift_build/compiler/artifact_layout.{type Layout}
import frameshift_build/compiler/facts.{type Reading}
import frameshift_build/compiler/finding.{type Finding, RegionEvidence}
import frameshift_build/compiler/model.{
  type Input, Check, LayoutInput, ProfileInput,
}
import frameshift_build/compiler/ownership
import frameshift_build/compiler/rectangles.{type Rectangle, Rectangle}
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/list
import gleam/option.{type Option, None, Some}

type Placed {
  Placed(
    instance: a.Instance,
    rectangle: Option(Rectangle),
    readings: List(Reading),
    inputs: List(Input),
    findings: List(Finding),
  )
}

pub fn evaluate(layout: Layout, value: Resolution) -> List(Finding) {
  let placed = list.map(layout.document.tiles, place(_, layout, value))
  list.flatten([
    list.flat_map(placed, fn(p) { p.findings }),
    [coverage(placed, layout)],
    overlaps(placed),
  ])
}

pub fn kind(
  instance: a.Instance,
  expected: String,
  layout: Layout,
  value: Resolution,
) -> Finding {
  let #(outcome, reason) = case
    resolution.find_profile(value, instance.profile)
  {
    Error(_) -> #(Unknown, "missing_profile")
    Ok(profile) if profile.kind == expected -> #(
      Compatible,
      "layout_role_present",
    )
    Ok(_) -> #(Incompatible, "wrong_layout_role")
  }
  finding.explain(
    Check("artifact." <> expected <> "_kind", outcome, reason, [instance.id], [
      ProfileInput(instance.id, instance.profile, ["kind"]),
      LayoutInput(layout.document.controller, layout.identity, case expected {
        "controller" -> ["controller"]
        _ -> ["tiles", instance.id, "display"]
      }),
    ]),
    [],
  )
}

fn place(tile: Tile, layout: Layout, value: Resolution) -> Placed {
  let assert Ok(instance) = resolution.find_instance(value, tile.display)
  let width = facts.component(instance, "raster.width", value)
  let height = facts.component(instance, "raster.height", value)
  let rectangle = case exact(width), exact(height) {
    Some(w), Some(h) -> {
      let #(w, h) = case tile.rotation {
        90 | 270 -> #(h, w)
        _ -> #(w, h)
      }
      Some(Rectangle(tile.x, tile.y, tile.x + w, tile.y + h))
    }
    _, _ -> None
  }
  let inputs = [
    LayoutInput(layout.document.controller, layout.identity, [
      "tiles",
      tile.display,
    ]),
  ]
  let readings = [width, height]
  let raster =
    finding.explain(
      Check(
        "artifact.tile_raster",
        case rectangle {
          Some(_) -> Compatible
          None -> Unknown
        },
        case rectangle {
          Some(_) -> "exact_raster"
          None -> finding.unknown_reason(readings, "ambiguous_raster_dimension")
        },
        [instance.id],
        inputs,
      ),
      readings,
    )
    |> finding.with_regions([
      RegionEvidence(instance.id, "pixel-tile", "count", rectangle, rectangle),
    ])
  let #(owner, selected) = ownership.controller(instance, value)
  let owner_check = case selected {
    Some(owner_instance) if owner_instance.id != layout.document.controller ->
      Check(
        ..owner.check,
        outcome: Incompatible,
        reason: "wrong_layout_controller",
      )
    _ -> owner.check
  }
  let owner =
    finding.explain(
      Check(
        ..owner_check,
        code: "artifact.controller_owner",
        instances: list.unique([
          layout.document.controller,
          ..owner_check.instances
        ]),
        inputs: list.append(inputs, owner_check.inputs),
      ),
      owner.readings,
    )
  Placed(instance, rectangle, readings, inputs, [
    kind(instance, "display", layout, value),
    owner,
    raster,
    fits("width", rectangle, readings, inputs, instance.id, layout),
    fits("height", rectangle, readings, inputs, instance.id, layout),
  ])
}

fn exact(reading: Reading) -> Option(Int) {
  case facts.numeric(reading) {
    Ok(#(low, high)) if low == high -> Some(low)
    _ -> None
  }
}

fn fits(
  axis: String,
  rectangle: Option(Rectangle),
  readings: List(Reading),
  inputs: List(Input),
  id: String,
  layout: Layout,
) -> Finding {
  let available = case axis {
    "width" -> layout.document.width
    _ -> layout.document.height
  }
  let required = case rectangle {
    None -> None
    Some(r) ->
      finding.constant(case axis {
        "width" -> r.right
        _ -> r.bottom
      })
  }
  finding.at_most(
    Check("artifact.tile_" <> axis, Unknown, "incomplete_tile_raster", [id], [
      LayoutInput(layout.document.controller, layout.identity, [axis]),
      ..inputs
    ]),
    readings,
    "count",
    required,
    finding.constant(available),
  )
}

fn coverage(placed: List(Placed), layout: Layout) -> Finding {
  let canvas = Rectangle(0, 0, layout.document.width, layout.document.height)
  let known =
    list.filter_map(placed, fn(p) {
      case p.rectangle {
        Some(r) -> Ok(r)
        None -> Error(Nil)
      }
    })
  let #(outcome, reason) = case list.length(known) == list.length(placed) {
    False -> #(Unknown, "incomplete_tile_raster")
    True -> {
      let assert Ok(covered) = rectangles.covers(canvas, known)
      case covered {
        True -> #(Compatible, "canvas_covered")
        False -> #(Incompatible, "canvas_gap")
      }
    }
  }
  finding.explain(
    Check(
      "artifact.coverage",
      outcome,
      reason,
      [layout.document.controller, ..list.map(placed, fn(p) { p.instance.id })],
      [
        LayoutInput(layout.document.controller, layout.identity, ["width"]),
        LayoutInput(layout.document.controller, layout.identity, ["height"]),
        ..list.flat_map(placed, fn(p) { p.inputs })
      ],
    ),
    list.flat_map(placed, fn(p) { p.readings }),
  )
  |> finding.with_regions([
    RegionEvidence(
      layout.document.controller,
      "pixel-canvas",
      "count",
      Some(canvas),
      Some(canvas),
    ),
    ..list.map(placed, fn(p) {
      RegionEvidence(
        p.instance.id,
        "pixel-tile",
        "count",
        p.rectangle,
        p.rectangle,
      )
    })
  ])
}

fn overlaps(placed: List(Placed)) -> List(Finding) {
  case placed {
    [] -> []
    [first, ..rest] ->
      list.append(list.map(rest, overlap(first, _)), overlaps(rest))
  }
}

fn overlap(first: Placed, second: Placed) -> Finding {
  let #(outcome, reason) = case first.rectangle, second.rectangle {
    Some(a), Some(b) -> {
      case
        a.left < b.right
        && b.left < a.right
        && a.top < b.bottom
        && b.top < a.bottom
      {
        True -> #(Incompatible, "overlapping_pixel_tiles")
        False -> #(Compatible, "separate_pixel_tiles")
      }
    }
    _, _ -> #(Unknown, "incomplete_tile_raster")
  }
  finding.explain(
    Check(
      "artifact.tile_separation",
      outcome,
      reason,
      [first.instance.id, second.instance.id],
      list.append(first.inputs, second.inputs),
    ),
    list.append(first.readings, second.readings),
  )
  |> finding.with_regions([
    RegionEvidence(
      first.instance.id,
      "pixel-tile",
      "count",
      first.rectangle,
      first.rectangle,
    ),
    RegionEvidence(
      second.instance.id,
      "pixel-tile",
      "count",
      second.rectangle,
      second.rectangle,
    ),
  ])
}
