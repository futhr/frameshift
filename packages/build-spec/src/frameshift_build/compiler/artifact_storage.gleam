/// Exact encoded payload and complete declared retention requirements. Usable
/// physical allocation and runtime qualification remain independent stages.
import frameshift_build/compiler/artifact_layout.{type Layout}
import frameshift_build/compiler/facts
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{
  BuildInput, Check, LayoutInput, ProfileInput,
}
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Compatible, Interval, Unknown}
import gleam/option.{None, Some}

pub fn evaluate(layout: Layout, value: Resolution) -> List(Finding) {
  let doc = layout.document
  let assert Ok(controller) = resolution.find_instance(value, doc.controller)
  let supported = doc.encoding == "rgb24-srgb-v1"
  let pixels = doc.width * doc.height
  let bytes = case supported {
    True -> finding.constant(pixels * 3)
    False -> None
  }
  let limit = facts.component(controller, "artifact.maximum", value)
  let slots = facts.component(controller, "storage.retained_artifacts", value)
  let required = case bytes, facts.numeric(slots) {
    Some(bytes), Ok(#(low, high)) ->
      Some(Interval(bytes.minimum * low, bytes.maximum * high))
    _, _ -> None
  }
  let base =
    Check(
      "artifact.encoding",
      case supported {
        True -> Compatible
        False -> Unknown
      },
      case supported {
        True -> "rgb24_srgb_encoding"
        False -> "unsupported_artifact_encoding"
      },
      [controller.id],
      [
        LayoutInput(controller.id, layout.identity, ["encoding"]),
        LayoutInput(controller.id, layout.identity, ["width"]),
        LayoutInput(controller.id, layout.identity, ["height"]),
        LayoutInput(controller.id, layout.identity, ["artifact"]),
        LayoutInput(controller.id, layout.identity, ["firmware"]),
        LayoutInput(controller.id, layout.identity, ["protocol"]),
        ProfileInput(controller.id, controller.profile, ["kind"]),
        BuildInput(["intent", "artifact"]),
        BuildInput(["intent", "firmware"]),
        BuildInput(["intent", "protocol"]),
      ],
    )
  [
    finding.explain(base, []),
    finding.at_most(
      Check(..base, code: "artifact.renderer_pixels"),
      [],
      "count",
      finding.constant(pixels),
      case supported {
        True -> finding.constant(16_777_216)
        False -> None
      },
    ),
    finding.at_most(
      Check(
        ..base,
        code: "artifact.payload_limit",
        reason: "incomplete_artifact_size",
      ),
      [limit],
      "byte",
      bytes,
      finding.interval(limit),
    ),
    finding.at_most(
      Check(
        ..base,
        code: "artifact.retention_minimum",
        reason: "incomplete_retention",
      ),
      [slots],
      "count",
      finding.constant(3),
      finding.interval(slots),
    ),
    finding.at_most(
      Check(
        ..base,
        code: "artifact.retained_payload",
        reason: "incomplete_retained_payload",
        inputs: [BuildInput(["intent", "storage_bytes"]), ..base.inputs],
      ),
      [slots],
      "byte",
      required,
      finding.constant(value.assembly.intent.storage_bytes),
    ),
  ]
}
