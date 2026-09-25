/// Conservative interval projections from exact source facts. Possible and
/// guaranteed regions are deliberately distinct; no centering is inferred.
import frameshift_build/assembly/model.{type Instance} as _
import frameshift_build/compiler/facts.{type Reading}
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{type Input, BuildInput, Check}
import frameshift_build/compiler/rectangles.{type Rectangle, Rectangle}
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{type Interval, Compatible, Interval, Unknown}
import gleam/list
import gleam/option.{type Option, None, Some}

pub type Edges {
  Edges(left: Interval, top: Interval, right: Interval, bottom: Interval)
}

pub type Region {
  Region(
    instance: Instance,
    readings: List(Reading),
    checks: List(Finding),
    edges: Option(Edges),
  )
}

pub fn active(instance: Instance, value: Resolution) -> Region {
  region(
    instance,
    value,
    "active",
    "active.offset.x",
    "active.offset.y",
    "outline",
  )
}

pub fn opening(instance: Instance, value: Resolution) -> Region {
  let container = case instance.location {
    "enclosure" -> "inner"
    _ -> "outline"
  }
  region(instance, value, "opening", "opening.x", "opening.y", container)
}

pub fn outline(instance: Instance, value: Resolution) -> Region {
  let keys = case instance.placement.rotation {
    90 | 270 -> #("outline.height", "outline.width")
    _ -> #("outline.width", "outline.height")
  }
  let width = facts.component(instance, keys.0, value)
  let height = facts.component(instance, keys.1, value)
  let edges = case finding.interval(width), finding.interval(height) {
    Some(w), Some(h) -> Some(Edges(Interval(0, 0), Interval(0, 0), w, h))
    _, _ -> None
  }
  Region(instance, [width, height], [], option.map(edges, place(_, instance)))
}

fn region(
  instance: Instance,
  value: Resolution,
  kind: String,
  x_key: String,
  y_key: String,
  container: String,
) -> Region {
  let x = facts.component(instance, x_key, value)
  let y = facts.component(instance, y_key, value)
  let width = facts.component(instance, kind <> ".width", value)
  let height = facts.component(instance, kind <> ".height", value)
  let outer_w = facts.component(instance, container <> ".width", value)
  let outer_h = facts.component(instance, container <> ".height", value)
  let readings = [x, y, width, height, outer_w, outer_h]
  let checks = [
    contains(instance, kind, "x", x, width, outer_w),
    contains(instance, kind, "y", y, height, outer_h),
  ]
  let edges = case
    finding.interval(x),
    finding.interval(y),
    finding.interval(width),
    finding.interval(height),
    finding.interval(outer_w),
    finding.interval(outer_h)
  {
    Some(x), Some(y), Some(w), Some(h), Some(ow), Some(oh) -> {
      let original = Edges(x, y, add(x, w), add(y, h))
      Some(place(
        rotate(original, ow, oh, instance.placement.rotation),
        instance,
      ))
    }
    _, _, _, _, _, _ -> None
  }
  Region(instance, readings, checks, edges)
}

fn contains(
  instance: Instance,
  kind: String,
  axis: String,
  offset: Reading,
  size: Reading,
  outer: Reading,
) -> Finding {
  finding.at_most(
    Check(
      "view." <> kind <> "." <> axis,
      Unknown,
      "incomplete_region",
      [instance.id],
      [],
    ),
    [offset, size, outer],
    "um",
    finding.sum([finding.interval(offset), finding.interval(size)]),
    finding.interval(outer),
  )
}

fn rotate(
  edges: Edges,
  width: Interval,
  height: Interval,
  rotation: Int,
) -> Edges {
  case rotation {
    90 ->
      Edges(
        subtract(height, edges.bottom),
        edges.left,
        subtract(height, edges.top),
        edges.right,
      )
    180 ->
      Edges(
        subtract(width, edges.right),
        subtract(height, edges.bottom),
        subtract(width, edges.left),
        subtract(height, edges.top),
      )
    270 ->
      Edges(
        edges.top,
        subtract(width, edges.right),
        edges.bottom,
        subtract(width, edges.left),
      )
    _ -> edges
  }
}

fn add(a: Interval, b: Interval) -> Interval {
  Interval(a.minimum + b.minimum, a.maximum + b.maximum)
}

fn subtract(a: Interval, b: Interval) -> Interval {
  Interval(a.minimum - b.maximum, a.maximum - b.minimum)
}

fn place(edges: Edges, instance: Instance) -> Edges {
  let x = Interval(instance.placement.x_um, instance.placement.x_um)
  let y = Interval(instance.placement.y_um, instance.placement.y_um)
  Edges(
    add(x, edges.left),
    add(y, edges.top),
    add(x, edges.right),
    add(y, edges.bottom),
  )
}

pub fn possible(value: Region) -> Option(Rectangle) {
  use edges <- option.then(usable(value))
  checked(Rectangle(
    edges.left.minimum,
    edges.top.minimum,
    edges.right.maximum,
    edges.bottom.maximum,
  ))
}

pub fn guaranteed(value: Region) -> Option(Rectangle) {
  use edges <- option.then(usable(value))
  checked(Rectangle(
    edges.left.maximum,
    edges.top.maximum,
    edges.right.minimum,
    edges.bottom.minimum,
  ))
}

fn usable(value: Region) -> Option(Edges) {
  case list.all(value.checks, fn(check) { check.check.outcome == Compatible }) {
    True -> value.edges
    False -> None
  }
}

fn checked(value: Rectangle) -> Option(Rectangle) {
  case rectangles.validate(value) {
    Ok(_) -> Some(value)
    Error(_) -> None
  }
}

pub fn inputs(value: Region) -> List(Input) {
  [
    BuildInput(["instances", value.instance.id, "placement"]),
    BuildInput(["instances", value.instance.id, "location"]),
  ]
}

pub fn evidence(value: Region, role: String) -> finding.RegionEvidence {
  finding.RegionEvidence(
    value.instance.id,
    role,
    possible(value),
    guaranteed(value),
  )
}

pub fn unavailable_reason(value: Region) -> String {
  finding.unknown_reason(
    value.readings,
    case list.all(value.checks, fn(c) { c.check.outcome == Compatible }) {
      True -> "no_guaranteed_region"
      False -> "region_outside_outline"
    },
  )
}
