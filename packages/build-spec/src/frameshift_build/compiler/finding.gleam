/// Evidence attached to a compiler-stage check. Never a whole-build admission.
import frameshift_build/compiler/evidence
import frameshift_build/compiler/facts.{type Reading}
import frameshift_build/compiler/model.{type Check, Check}
import frameshift_build/compiler/rectangles.{type Rectangle}
import frameshift_physical.{
  type Interval, Compatible, Incompatible, Interval, Unknown,
}
import gleam/list
import gleam/option.{type Option, None, Some}

pub type Relation {
  AtMost
  Within
}

pub type Measurement {
  Measurement(
    unit: String,
    relation: Relation,
    required: Option(Interval),
    available: Option(Interval),
  )
}

pub type Finding {
  Finding(
    check: Check,
    readings: List(Reading),
    measurement: Option(Measurement),
    regions: List(RegionEvidence),
    common_terms: List(String),
  )
}

pub type RegionEvidence {
  RegionEvidence(
    instance: String,
    role: String,
    possible: Option(Rectangle),
    guaranteed: Option(Rectangle),
  )
}

pub fn with_regions(value: Finding, regions: List(RegionEvidence)) -> Finding {
  Finding(..value, regions:)
}

pub fn with_terms(value: Finding, common_terms: List(String)) -> Finding {
  Finding(..value, common_terms:)
}

pub fn explain(check: Check, readings: List(Reading)) -> Finding {
  Finding(
    Check(
      ..check,
      inputs: evidence.inputs(list.append(
        check.inputs,
        list.map(readings, facts.input),
      )),
    ),
    evidence.readings(readings),
    None,
    [],
    [],
  )
}

pub fn at_most(
  check: Check,
  readings: List(Reading),
  unit: String,
  required: Option(Interval),
  available: Option(Interval),
) -> Finding {
  compare(check, readings, unit, required, available, AtMost)
}

pub fn within(
  check: Check,
  readings: List(Reading),
  unit: String,
  required: Option(Interval),
  available: Option(Interval),
) -> Finding {
  compare(check, readings, unit, required, available, Within)
}

fn compare(
  check: Check,
  readings: List(Reading),
  unit: String,
  required: Option(Interval),
  available: Option(Interval),
  relation: Relation,
) -> Finding {
  let check = case required, available {
    Some(required), Some(available) -> {
      let permitted = case relation {
        AtMost -> required.maximum <= available.minimum
        Within ->
          required.minimum >= available.minimum
          && required.maximum <= available.maximum
      }
      Check(
        ..check,
        outcome: case permitted {
          True -> Compatible
          False -> Incompatible
        },
        reason: case permitted, relation {
          True, _ -> "within_bounds"
          False, AtMost -> "exceeds_capacity"
          False, Within -> "outside_range"
        },
      )
    }
    _, _ ->
      Check(
        ..check,
        outcome: Unknown,
        reason: unknown_reason(readings, check.reason),
      )
  }
  Finding(
    ..explain(check, readings),
    measurement: Some(Measurement(unit, relation, required, available)),
  )
}

pub fn constant(value: Int) -> Option(Interval) {
  Some(Interval(value, value))
}

pub fn interval(reading: Reading) -> Option(Interval) {
  case facts.numeric(reading) {
    Ok(#(low, high)) -> Some(Interval(low, high))
    Error(_) -> None
  }
}

/// Callers own the bounded contribution set and its complete scope.
pub fn sum(values: List(Option(Interval))) -> Option(Interval) {
  list.fold(values, constant(0), fn(total, value) {
    case total, value {
      Some(a), Some(b) ->
        Some(Interval(a.minimum + b.minimum, a.maximum + b.maximum))
      _, _ -> None
    }
  })
}

pub fn unknown_reason(readings: List(Reading), fallback: String) -> String {
  case list.any(readings, fn(r) { r.status == facts.ConflictingFact }) {
    True -> facts.status_code(facts.ConflictingFact)
    False ->
      case list.find(readings, fn(r) { r.status != facts.Usable }) {
        Ok(reading) -> facts.status_code(reading.status)
        Error(_) -> fallback
      }
  }
}
