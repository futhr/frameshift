/// Necessary common-alternative agreement; never executable qualification.
import frameshift_build/compiler/facts.{type Reading}
import frameshift_build/compiler/finding.{type Finding}
import frameshift_build/compiler/model.{type Check, Check}
import frameshift_physical.{Compatible, Incompatible, Unknown}
import gleam/list
import gleam/result
import gleam/string

pub fn agreement(base: Check, readings: List(Reading)) -> Finding {
  with_selector(
    base,
    readings,
    fn(reading) { facts.terms(reading) |> result.replace_error(Nil) },
    "declared_contract_agrees",
  )
}

pub fn with_selector(
  base: Check,
  readings: List(Reading),
  select: fn(Reading) -> Result(List(String), Nil),
  success: String,
) -> Finding {
  let known = list.filter_map(readings, select)
  let common = intersection(known)
  let #(outcome, reason) = case known, common {
    [_, ..], [] -> #(Incompatible, "no_common_declared_contract")
    [], _ -> #(Unknown, finding.unknown_reason(readings, base.reason))
    _, _ ->
      case list.length(known) == list.length(readings) {
        True -> #(Compatible, success)
        False -> #(Unknown, finding.unknown_reason(readings, base.reason))
      }
  }
  finding.explain(Check(..base, outcome:, reason:), readings)
  |> finding.with_terms(case outcome {
    Compatible -> common
    _ -> []
  })
}

fn intersection(sets: List(List(String))) -> List(String) {
  case sets {
    [] -> []
    [first, ..rest] ->
      list.fold(rest, first, fn(common, next) {
        list.filter(common, list.contains(next, _))
      })
      |> list.sort(string.compare)
  }
}
