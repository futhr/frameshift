/// Straight-on viewing constraints. Geometry evidence remains distinct from
/// optical, electrical and complete assembly qualification.
import frameshift_build/assembly/model.{type Instance} as _
import frameshift_build/compiler/enclosure
import frameshift_build/compiler/facts.{type Reading}
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{
  type Input, BuildInput, Check, ProfileInput,
}
import frameshift_build/compiler/projection.{type Region}
import frameshift_build/compiler/rectangles.{type Rectangle, Rectangle}
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{type Interval, Compatible, Incompatible, Unknown}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

type Mask {
  Mask(region: Region, back: Option(Interval), depth_readings: List(Reading))
}

type Display {
  Display(region: Region, plane: Finding)
}

pub fn evaluate(value: Resolution) -> List(Finding) {
  let #(selected, frame) = enclosure.select(value)
  let selected =
    finding.explain(Check(..selected.check, code: "view.enclosure"), [])
  let displays =
    parts(value, "display") |> list.map(projection.active(_, value))
  let mats =
    parts(value, "mat")
    |> list.sort(mat_order)
    |> list.map(projection.opening(_, value))
  let prerequisites =
    list.flatten([
      [selected, display_required(displays, value)],
      list.flat_map(value.assembly.instances, classification(_, value)),
      list.flat_map(list.append(displays, mats), fn(region) { region.checks }),
    ])
  let evaluated = case frame {
    None -> []
    Some(frame) ->
      evaluate_frame(projection.opening(frame, value), mats, displays, value)
  }
  list.append(prerequisites, evaluated)
}

fn parts(value: Resolution, kind: String) -> List(Instance) {
  list.filter(value.assembly.instances, fn(instance) {
    instance.location == "internal" && is_kind(instance, kind, value)
  })
}

fn is_kind(instance: Instance, kind: String, value: Resolution) -> Bool {
  case resolution.find_profile(value, instance.profile) {
    Ok(profile) -> profile.kind == kind
    Error(_) -> False
  }
}

fn classification(instance: Instance, value: Resolution) -> List(Finding) {
  let base =
    Check("view.classification", Unknown, "missing_profile", [instance.id], [
      ProfileInput(instance.id, instance.profile, ["kind"]),
      BuildInput(["instances", instance.id, "location"]),
    ])
  case resolution.find_profile(value, instance.profile) {
    Error(_) -> [finding.explain(base, [])]
    Ok(profile) ->
      case profile.kind == "display" || profile.kind == "mat" {
        False -> []
        True -> [
          finding.explain(
            Check(
              ..base,
              code: "view.location",
              outcome: case instance.location {
                "internal" -> Compatible
                _ -> Unknown
              },
              reason: case instance.location {
                "internal" -> "internal_view_component"
                _ -> "unsupported_view_location"
              },
            ),
            [],
          ),
        ]
      }
  }
}

fn display_required(displays: List(Region), value: Resolution) -> Finding {
  let present = !list.is_empty(displays)
  finding.explain(
    Check(
      "view.display.required",
      case present {
        True -> Compatible
        False -> Unknown
      },
      case present {
        True -> "internal_display_present"
        False -> "missing_internal_display"
      },
      list.map(displays, fn(d) { d.instance.id }),
      [
        BuildInput(["instances"]),
        ..list.map(value.assembly.instances, fn(i) {
          ProfileInput(i.id, i.profile, ["kind"])
        })
      ],
    ),
    [],
  )
}

fn mat_order(a: Instance, b: Instance) {
  case a.placement.z_um == b.placement.z_um {
    True -> string.compare(a.id, b.id)
    False -> int.compare(a.placement.z_um, b.placement.z_um)
  }
}

fn evaluate_frame(
  frame: Region,
  mats: List(Region),
  displays: List(Region),
  value: Resolution,
) -> List(Finding) {
  let initial = Mask(frame, finding.constant(0), [])
  let #(mask, mask_checks) =
    list.fold(mats, #(initial, []), fn(state, mat) {
      let #(previous, checks) = state
      let #(next, more) = mask_step(previous, mat, value)
      #(next, list.append(checks, more))
    })
  let displays =
    list.map(displays, fn(region) {
      Display(region, plane_check("view.display.plane", mask, region))
    })
  list.flatten([
    frame.checks,
    mask_checks,
    list.map(displays, fn(d) { d.plane }),
    [coverage(mask, displays)],
    list.flat_map(displays, fn(display) {
      value.assembly.instances
      |> list.filter(fn(i) {
        i.location == "internal"
        && i.id != display.region.instance.id
        && !is_kind(i, "mat", value)
      })
      |> list.map(fn(i) {
        obstruction(mask.region, display.region, projection.outline(i, value))
      })
    }),
  ])
}

fn mask_step(
  previous: Mask,
  mat: Region,
  value: Resolution,
) -> #(Mask, List(Finding)) {
  let depth = facts.component(mat.instance, "outline.depth", value)
  let back =
    finding.sum([
      finding.constant(mat.instance.placement.z_um),
      finding.interval(depth),
    ])
  let outer = projection.outline(mat.instance, value)
  #(Mask(mat, back, [depth]), [
    contains("view.mask.outer", previous.region, outer),
    contains("view.mask.opening", mat, previous.region),
    plane_check("view.mask.plane", previous, mat),
  ])
}

fn contains(code: String, target: Region, covering: Region) -> Finding {
  let readings = list.append(target.readings, covering.readings)
  let #(outcome, reason) = case
    projection.possible(target),
    projection.guaranteed(covering)
  {
    Some(target), Some(covering) ->
      case rectangles.covers(target, [covering]) {
        Ok(True) -> #(Compatible, "region_contained")
        Ok(False) -> #(Incompatible, "region_not_contained")
        Error(_) -> #(Unknown, "unsupported_region")
      }
    _, _ -> #(Unknown, finding.unknown_reason(readings, "no_guaranteed_region"))
  }
  finding.explain(
    Check(
      code,
      outcome,
      reason,
      [target.instance.id, covering.instance.id],
      list.append(projection.inputs(target), projection.inputs(covering)),
    ),
    readings,
  )
  |> finding.with_regions([
    projection.evidence(target, "target"),
    projection.evidence(covering, "covering"),
  ])
}

fn plane_check(code: String, mask: Mask, region: Region) -> Finding {
  finding.at_most(
    Check(
      code,
      Unknown,
      "missing_mask_depth",
      [mask.region.instance.id, region.instance.id],
      list.append(projection.inputs(mask.region), projection.inputs(region)),
    ),
    mask.depth_readings,
    "um",
    mask.back,
    finding.constant(region.instance.placement.z_um),
  )
}

fn admitted(display: Display) -> Option(Rectangle) {
  case display.plane.check.outcome {
    Compatible -> projection.guaranteed(display.region)
    _ -> None
  }
}

fn coverage(mask: Mask, displays: List(Display)) -> Finding {
  let available = list.map(displays, admitted)
  let rectangles = option.values(available)
  let incomplete =
    list.is_empty(displays) || list.any(available, option.is_none)
  let regions = [mask.region, ..list.map(displays, fn(d) { d.region })]
  let readings =
    list.append(
      mask.depth_readings,
      list.flat_map(regions, fn(r) { r.readings }),
    )
  let #(outcome, reason) = case projection.possible(mask.region) {
    None -> #(Unknown, projection.unavailable_reason(mask.region))
    Some(target) ->
      case rectangles.covers(target, rectangles) {
        Ok(True) -> #(Compatible, "aperture_covered")
        Ok(False) ->
          case incomplete {
            True -> #(
              Unknown,
              finding.unknown_reason(readings, "incomplete_active_coverage"),
            )
            False -> #(Incompatible, "aperture_not_covered")
          }
        Error(_) -> #(Unknown, "unsupported_region")
      }
  }
  finding.explain(
    Check(
      "view.coverage",
      outcome,
      reason,
      list.map(regions, fn(r) { r.instance.id }),
      region_inputs(regions),
    ),
    readings,
  )
  |> finding.with_regions([
    projection.evidence(mask.region, "target"),
    ..list.map(displays, fn(d) { projection.evidence(d.region, "active") })
  ])
}

fn region_inputs(regions: List(Region)) -> List(Input) {
  list.flat_map(regions, projection.inputs)
}

fn obstruction(mask: Region, display: Region, obstacle: Region) -> Finding {
  let regions = [mask, display, obstacle]
  let readings = list.flat_map(regions, fn(r) { r.readings })
  let #(outcome, reason) = case
    obstacle.instance.placement.z_um >= display.instance.placement.z_um
  {
    True -> #(Compatible, "behind_view_plane")
    False -> obstruction_projection(mask, display, obstacle, readings)
  }
  finding.explain(
    Check(
      "view.obstruction",
      outcome,
      reason,
      [display.instance.id, obstacle.instance.id],
      region_inputs(regions),
    ),
    readings,
  )
  |> finding.with_regions([
    projection.evidence(mask, "target"),
    projection.evidence(display, "active"),
    projection.evidence(obstacle, "obstacle"),
  ])
}

fn obstruction_projection(
  mask: Region,
  display: Region,
  obstacle: Region,
  readings: List(Reading),
) {
  case
    projection.possible(mask),
    projection.possible(display),
    projection.possible(obstacle)
  {
    Some(mask), Some(display), Some(obstacle) ->
      case intersection(mask, display) {
        None -> #(Compatible, "outside_view")
        Some(visible) ->
          case intersection(visible, obstacle) {
            None -> #(Compatible, "outside_view")
            Some(_) -> #(Unknown, "possible_obstruction")
          }
      }
    _, _, _ -> #(Unknown, finding.unknown_reason(readings, "incomplete_view"))
  }
}

fn intersection(a: Rectangle, b: Rectangle) -> Option(Rectangle) {
  let value =
    Rectangle(
      int.max(a.left, b.left),
      int.max(a.top, b.top),
      int.min(a.right, b.right),
      int.min(a.bottom, b.bottom),
    )
  case value.left < value.right && value.top < value.bottom {
    True -> Some(value)
    False -> None
  }
}
