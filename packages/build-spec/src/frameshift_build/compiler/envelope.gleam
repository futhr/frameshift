/// Axis-aligned service envelopes for validated canonical component instances.
import frameshift_build/assembly/model.{type Instance} as _
import frameshift_build/compiler/facts.{type Reading}
import frameshift_build/compiler/model.{type Input, BuildInput}
import frameshift_build/resolution.{type Resolution}
import gleam/list
import gleam/option.{type Option, None, Some}

pub type Axis {
  Axis(
    name: String,
    position: Int,
    outline: Reading,
    negative: Reading,
    positive: Reading,
  )
}

pub type Envelope {
  Envelope(instance: Instance, axes: List(Axis))
}

pub type Extent {
  Extent(minimum: Int, maximum: Int)
}

pub fn read(instance: Instance, value: Resolution) -> Envelope {
  let #(width, height, left, right, top, bottom) = case
    instance.placement.rotation
  {
    90 -> #("height", "width", "bottom", "top", "left", "right")
    180 -> #("width", "height", "right", "left", "bottom", "top")
    270 -> #("height", "width", "top", "bottom", "right", "left")
    _ -> #("width", "height", "left", "right", "top", "bottom")
  }
  Envelope(instance, [
    axis(instance, value, "x", instance.placement.x_um, width, left, right),
    axis(instance, value, "y", instance.placement.y_um, height, top, bottom),
    axis(
      instance,
      value,
      "z",
      instance.placement.z_um,
      "depth",
      "front",
      "back",
    ),
  ])
}

fn axis(
  instance: Instance,
  value: Resolution,
  name: String,
  position: Int,
  size: String,
  negative: String,
  positive: String,
) -> Axis {
  Axis(
    name,
    position,
    facts.component(instance, "outline." <> size, value),
    facts.component(instance, "clearance." <> negative, value),
    facts.component(instance, "clearance." <> positive, value),
  )
}

pub fn extent(axis: Axis) -> Option(Extent) {
  case
    facts.numeric(axis.outline),
    facts.numeric(axis.negative),
    facts.numeric(axis.positive)
  {
    Ok(#(_, size)), Ok(#(_, negative)), Ok(#(_, positive)) ->
      Some(Extent(axis.position - negative, axis.position + size + positive))
    _, _, _ -> None
  }
}

pub fn readings(value: Envelope) -> List(Reading) {
  list.flat_map(value.axes, fn(axis) {
    [axis.outline, axis.negative, axis.positive]
  })
}

pub fn inputs(value: Envelope) -> List(Input) {
  [
    BuildInput(["instances", value.instance.id, "placement"]),
    BuildInput(["instances", value.instance.id, "location"]),
  ]
}

/// One known separating axis suffices; missing other axes cannot invalidate it.
pub fn separated(first: Envelope, second: Envelope) -> Bool {
  list.any(list.zip(first.axes, second.axes), fn(pair) {
    let #(a, b) = pair
    case extent(a), extent(b) {
      Some(a), Some(b) -> a.maximum <= b.minimum || b.maximum <= a.minimum
      _, _ -> False
    }
  })
}
