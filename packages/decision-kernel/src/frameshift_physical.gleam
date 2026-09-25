// Pure physical arithmetic. Callers must attach provenance and assemble all
// required constraints; these comparisons cannot authorize a physical build.
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub type Unit {
  Micrometre
  Millivolt
  Milliampere
  Milliwatt
  Gram
}

pub type Fact {
  Known(minimum: Int, maximum: Int)
  Missing
  Conflicting
}

pub type Interval {
  Interval(minimum: Int, maximum: Int)
}

pub type Outcome {
  Compatible
  Incompatible
  Unknown
}

pub type Reason {
  WithinBounds
  ExceedsCapacity
  VoltageOutsideRange
  MissingFact
  ConflictingFact
}

pub type Refusal {
  InvalidRange
  InvalidCount
  InvalidDecimal
  OutOfRange
  InvalidDimension
}

pub type Comparison {
  Comparison(
    unit: Unit,
    outcome: Outcome,
    reason: Reason,
    required: Option(Interval),
    available: Option(Interval),
  )
}

/// Each physical input is limited before addition or multiplication. The
/// largest intermediate (64 geometry contributions) is only 320,000,000.
pub fn ceiling(unit: Unit) -> Int {
  case unit {
    Micrometre -> 5_000_000
    Millivolt -> 300_000
    Milliampere -> 100_000
    Milliwatt -> 1_000_000
    Gram -> 100_000
  }
}

pub fn from_tolerance(
  unit: Unit,
  value: Int,
  tolerance: Int,
) -> Result(Fact, Refusal) {
  case value < 0 || tolerance < 0 || tolerance > value {
    True -> Error(InvalidRange)
    False ->
      case value > ceiling(unit) || tolerance > ceiling(unit) - value {
        True -> Error(OutOfRange)
        False -> Ok(Known(value - tolerance, value + tolerance))
      }
  }
}

/// Exact ASCII decimal millimetres. No rounding, floats, signs or exponents.
pub fn millimetres(text: String) -> Result(Int, Refusal) {
  case string.byte_size(text) > 8 {
    True -> Error(InvalidDecimal)
    False ->
      case string.split(text, ".") {
        [whole] -> decimal_parts(whole, "")
        [whole, fraction] if fraction != "" -> decimal_parts(whole, fraction)
        _ -> Error(InvalidDecimal)
      }
  }
}

fn decimal_parts(whole: String, fraction: String) -> Result(Int, Refusal) {
  case
    digits(whole)
    && { fraction == "" || digits(fraction) }
    && string.byte_size(whole) <= 4
    && string.byte_size(fraction) <= 3
  {
    False -> Error(InvalidDecimal)
    True -> {
      use major <- result.try(
        int.parse(whole) |> result.replace_error(InvalidDecimal),
      )
      use minor <- result.try(
        int.parse(string.pad_end(fraction, 3, "0"))
        |> result.replace_error(InvalidDecimal),
      )
      let value = major * 1000 + minor
      case value <= ceiling(Micrometre) {
        True -> Ok(value)
        False -> Error(OutOfRange)
      }
    }
  }
}

fn digits(text: String) -> Bool {
  text != ""
  && list.all(string.to_graphemes(text), fn(char) {
    list.contains(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"], char)
  })
}

pub fn validate(unit: Unit, fact: Fact) -> Result(Fact, Refusal) {
  case fact {
    Known(low, high) if low < 0 || high < low -> Error(InvalidRange)
    Known(_, high) ->
      case high > ceiling(unit) {
        True -> Error(OutOfRange)
        False -> Ok(fact)
      }
    _ -> Ok(fact)
  }
}

/// For one consistent rail, load or dimension. An omitted contribution must
/// appear as Missing; constructing a complete contribution list is upstream.
pub fn capacity(
  unit: Unit,
  contributions: List(Fact),
  available: Fact,
) -> Result(Comparison, Refusal) {
  use _ <- result.try(count(contributions, 64))
  use facts <- result.try(
    list.try_map(contributions, fn(fact) { validate(unit, fact) }),
  )
  use available <- result.try(validate(unit, available))
  Ok(compare_capacity(unit, sum(facts), available))
}

pub fn grid_axis(
  modules: Int,
  outline: Fact,
  gap: Fact,
  clearance: Fact,
  available: Fact,
) -> Result(Comparison, Refusal) {
  case modules < 1 || modules > 8 {
    True -> Error(InvalidCount)
    False -> {
      use outline <- result.try(positive_geometry(outline))
      use gap <- result.try(validate(Micrometre, gap))
      use clearance <- result.try(validate(Micrometre, clearance))
      use available <- result.try(positive_geometry(available))
      let gaps = case modules {
        1 -> Known(0, 0)
        _ -> scale(gap, modules - 1)
      }
      let required = sum([scale(outline, modules), gaps, scale(clearance, 2)])
      Ok(compare_capacity(Micrometre, required, available))
    }
  }
}

pub fn aperture(
  opening: Fact,
  active_area: Fact,
) -> Result(Comparison, Refusal) {
  use opening <- result.try(positive_geometry(opening))
  use active_area <- result.try(positive_geometry(active_area))
  Ok(compare_capacity(Micrometre, opening, active_area))
}

pub fn voltage(supply: Fact, input: Fact) -> Result(Comparison, Refusal) {
  use supply <- result.try(validate(Millivolt, supply))
  use input <- result.try(validate(Millivolt, input))
  case supply, input {
    Known(low, high), Known(allowed_low, allowed_high) -> {
      let within = low >= allowed_low && high <= allowed_high
      let reason = case within {
        True -> WithinBounds
        False -> VoltageOutsideRange
      }
      Ok(known_comparison(Millivolt, supply, input, within, reason))
    }
    _, _ -> Ok(unknown_comparison(Millivolt, supply, input))
  }
}

pub fn aggregate(comparisons: List(Comparison)) -> Result(Outcome, Refusal) {
  use _ <- result.try(count(comparisons, 1024))
  Ok(
    list.fold(comparisons, Compatible, fn(acc, comparison) {
      case acc, comparison.outcome {
        Incompatible, _ | _, Incompatible -> Incompatible
        Unknown, _ | _, Unknown -> Unknown
        _, _ -> Compatible
      }
    }),
  )
}

pub fn reason_code(reason: Reason) -> String {
  case reason {
    WithinBounds -> "within-bounds"
    ExceedsCapacity -> "exceeds-capacity"
    VoltageOutsideRange -> "voltage-outside-range"
    MissingFact -> "missing-fact"
    ConflictingFact -> "conflicting-fact"
  }
}

fn count(items: List(a), maximum: Int) -> Result(Nil, Refusal) {
  let size = list.length(list.take(items, maximum + 1))
  case size < 1 || size > maximum {
    True -> Error(InvalidCount)
    False -> Ok(Nil)
  }
}

fn positive_geometry(fact: Fact) -> Result(Fact, Refusal) {
  use fact <- result.try(validate(Micrometre, fact))
  case fact {
    Known(0, _) -> Error(InvalidDimension)
    _ -> Ok(fact)
  }
}

fn sum(facts: List(Fact)) -> Fact {
  list.fold(facts, Known(0, 0), fn(acc, fact) {
    case acc, fact {
      Conflicting, _ | _, Conflicting -> Conflicting
      Missing, _ | _, Missing -> Missing
      Known(a, b), Known(c, d) -> Known(a + c, b + d)
    }
  })
}

fn scale(fact: Fact, quantity: Int) -> Fact {
  case fact {
    Known(low, high) -> Known(low * quantity, high * quantity)
    _ -> fact
  }
}

fn compare_capacity(unit: Unit, required: Fact, available: Fact) -> Comparison {
  case required, available {
    Known(_, worst), Known(least, _) -> {
      let within = worst <= least
      let reason = case within {
        True -> WithinBounds
        False -> ExceedsCapacity
      }
      known_comparison(unit, required, available, within, reason)
    }
    _, _ -> unknown_comparison(unit, required, available)
  }
}

fn known_comparison(
  unit: Unit,
  required: Fact,
  available: Fact,
  within: Bool,
  reason: Reason,
) -> Comparison {
  let outcome = case within {
    True -> Compatible
    False -> Incompatible
  }
  Comparison(unit, outcome, reason, interval(required), interval(available))
}

fn unknown_comparison(
  unit: Unit,
  required: Fact,
  available: Fact,
) -> Comparison {
  let reason = case required, available {
    Conflicting, _ | _, Conflicting -> ConflictingFact
    _, _ -> MissingFact
  }
  Comparison(unit, Unknown, reason, interval(required), interval(available))
}

fn interval(fact: Fact) -> Option(Interval) {
  case fact {
    Known(low, high) -> Some(Interval(low, high))
    _ -> None
  }
}
