/// One shared frame selection and coordinate contract for geometry stages.
import frameshift_build/assembly/model as a
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{
  type Check, BuildInput, Check, ProfileInput,
}
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/list
import gleam/option.{type Option, None, Some}

pub fn select(value: Resolution) -> #(Finding, Option(a.Instance)) {
  let frames =
    list.filter(value.assembly.instances, fn(instance) {
      instance.location == "enclosure"
    })
  let base =
    Check(
      "geometry.enclosure",
      Unknown,
      "missing_enclosure",
      list.map(frames, fn(frame) { frame.id }),
      [BuildInput(["instances"])],
    )
  case frames {
    [] -> #(finding.explain(base, []), None)
    [frame] -> enclosing_frame(frame, value, base)
    _ -> #(
      finding.explain(Check(..base, reason: "multiple_enclosures"), []),
      None,
    )
  }
}

fn enclosing_frame(
  frame: a.Instance,
  value: Resolution,
  base: Check,
) -> #(Finding, Option(a.Instance)) {
  let base =
    Check(..base, inputs: [
      ProfileInput(frame.id, frame.profile, ["kind"]),
      ..base.inputs
    ])
  let #(outcome, reason) = case
    frame.placement,
    resolution.find_profile(value, frame.profile)
  {
    a.Placement(0, 0, 0, 0), Ok(profile) ->
      case profile.kind {
        "frame" -> #(Compatible, "single_enclosure")
        _ -> #(Incompatible, "enclosure_kind_mismatch")
      }
    a.Placement(0, 0, 0, 0), Error(_) -> #(Unknown, "missing_profile")
    _, _ -> #(Incompatible, "enclosure_transform")
  }
  let selected = case outcome {
    Compatible -> Some(frame)
    _ -> None
  }
  #(finding.explain(Check(..base, outcome:, reason:), []), selected)
}
