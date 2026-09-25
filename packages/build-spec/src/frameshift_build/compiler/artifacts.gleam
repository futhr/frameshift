/// Fixed controller/display layout obligations and payload budgets. This typed
/// stage cannot grant complete runtime qualification or public admission.
import frameshift_build/compiler/artifact_layout.{type Layout}
import frameshift_build/compiler/artifact_storage
import frameshift_build/compiler/artifact_tiles
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{
  BuildInput, Check, LayoutInput, ProfileInput,
}
import frameshift_build/model.{type Refusal} as _
import frameshift_build/resolution.{type Resolution}
import frameshift_physical.{Compatible, Unknown}
import gleam/list
import gleam/result

pub fn evaluate(
  value: Resolution,
  layouts: List(Layout),
) -> Result(List(Finding), Refusal) {
  use _ <- result.try(artifact_layout.validate(layouts, value))
  let presence =
    list.flat_map(value.assembly.instances, fn(i) {
      case resolution.find_profile(value, i.profile) {
        Error(_) -> [
          finding.explain(
            Check(
              "artifact.classification",
              Unknown,
              "missing_profile",
              [i.id],
              [ProfileInput(i.id, i.profile, ["kind"])],
            ),
            [],
          ),
        ]
        Ok(profile)
          if profile.kind == "controller" || profile.kind == "display"
        -> {
          let assigned =
            list.filter(layouts, fn(l) {
              case profile.kind {
                "controller" -> l.document.controller == i.id
                _ -> list.any(l.document.tiles, fn(t) { t.display == i.id })
              }
            })
          [
            finding.explain(
              Check(
                "artifact.assignment",
                case assigned {
                  [] -> Unknown
                  _ -> Compatible
                },
                case assigned {
                  [] -> "missing_artifact_layout"
                  _ -> "layout_assigned"
                },
                [i.id],
                [
                  BuildInput(["instances", i.id]),
                  ProfileInput(i.id, i.profile, ["kind"]),
                  ..list.map(assigned, fn(l) {
                    LayoutInput(l.document.controller, l.identity, ["tiles"])
                  })
                ],
              ),
              [],
            ),
          ]
        }
        _ -> []
      }
    })
  Ok(list.append(
    presence,
    list.flat_map(layouts, fn(layout) {
      let assert Ok(controller) =
        resolution.find_instance(value, layout.document.controller)
      list.flatten([
        [artifact_tiles.kind(controller, "controller", layout, value)],
        artifact_tiles.evaluate(layout, value),
        artifact_storage.evaluate(layout, value),
      ])
    }),
  ))
}
