import frameshift_physical as p
import gleam/list
import gleam/option.{None, Some}

pub fn exact_units_test() {
  assert p.millimetres("596.736") == Ok(596_736)
  assert p.millimetres("270.40") == Ok(270_400)
  assert p.millimetres("192") == Ok(192_000)
  assert p.millimetres("0.001") == Ok(1)
  assert p.millimetres("5000.000") == Ok(5_000_000)
  assert p.millimetres("5000.001") == Error(p.OutOfRange)
}

pub fn malformed_units_test() {
  list.each(
    [
      "",
      "1.",
      ".2",
      " 1",
      "1 ",
      "-1",
      "+1",
      "1e3",
      "1,000",
      "１",
      "1.0001",
      "1.2.3",
    ],
    fn(text) {
      assert p.millimetres(text) == Error(p.InvalidDecimal)
    },
  )
}

pub fn tolerance_limits_test() {
  assert p.from_tolerance(p.Micrometre, 1000, 25) == Ok(p.Known(975, 1025))
  assert p.from_tolerance(p.Gram, 10, 11) == Error(p.InvalidRange)
  assert p.from_tolerance(p.Milliampere, 100_000, 1) == Error(p.OutOfRange)
  let outside_safe_range = 9_007_199_254_740_991 + 1
  assert p.from_tolerance(p.Millivolt, outside_safe_range, 0)
    == Error(p.OutOfRange)
  assert p.validate(p.Micrometre, p.Known(2, 1)) == Error(p.InvalidRange)
  assert p.validate(p.Gram, p.Known(-1, 1)) == Error(p.InvalidRange)
}

pub fn grid_includes_gaps_and_both_clearances_test() {
  let assert Ok(result) =
    p.grid_axis(
      3,
      p.Known(192_000, 192_000),
      p.Known(1000, 1000),
      p.Known(2000, 2000),
      p.Known(582_000, 582_000),
    )
  assert result.outcome == p.Compatible
  assert result.required == Some(p.Interval(582_000, 582_000))
  let assert Ok(tight) =
    p.grid_axis(
      3,
      p.Known(192_000, 192_100),
      p.Known(1000, 1000),
      p.Known(2000, 2000),
      p.Known(582_000, 582_100),
    )
  assert tight.outcome == p.Incompatible
  assert tight.required == Some(p.Interval(582_000, 582_300))
  assert tight.reason == p.ExceedsCapacity
}

pub fn absent_gap_is_irrelevant_for_one_module_test() {
  let assert Ok(result) =
    p.grid_axis(
      1,
      p.Known(100, 100),
      p.Missing,
      p.Known(0, 0),
      p.Known(100, 100),
    )
  assert result.outcome == p.Compatible
  let assert Ok(multiple) =
    p.grid_axis(
      2,
      p.Known(100, 100),
      p.Missing,
      p.Known(0, 0),
      p.Known(1000, 1000),
    )
  assert multiple.outcome == p.Unknown
  assert multiple.reason == p.MissingFact
}

pub fn every_stack_and_load_contribution_counts_test() {
  let assert Ok(depth) =
    p.capacity(
      p.Micrometre,
      [p.Known(850, 900), p.Known(3000, 4000), p.Known(1000, 1200)],
      p.Known(6000, 6100),
    )
  assert depth.outcome == p.Incompatible
  assert depth.required == Some(p.Interval(4850, 6100))
  let assert Ok(current) =
    p.capacity(
      p.Milliampere,
      list.repeat(p.Known(4000, 4000), 6),
      p.Known(24_000, 24_000),
    )
  assert current.outcome == p.Compatible
  assert current.required == Some(p.Interval(24_000, 24_000))
  let assert Ok(extra_load) =
    p.capacity(
      p.Milliampere,
      [p.Known(1, 1), ..list.repeat(p.Known(4000, 4000), 6)],
      p.Known(24_000, 24_000),
    )
  assert extra_load.outcome == p.Incompatible
}

pub fn voltage_requires_containment_not_overlap_test() {
  let assert Ok(inside) = p.voltage(p.Known(4750, 5250), p.Known(4500, 5500))
  assert inside.outcome == p.Compatible
  let assert Ok(overlap) = p.voltage(p.Known(4250, 5000), p.Known(4500, 5500))
  assert overlap.outcome == p.Incompatible
  assert overlap.reason == p.VoltageOutsideRange
  let assert Ok(above) = p.voltage(p.Known(5000, 5600), p.Known(4500, 5500))
  assert above.outcome == p.Incompatible
}

pub fn aperture_respects_active_area_and_tolerance_test() {
  let assert Ok(result) =
    p.aperture(p.Known(269_000, 270_400), p.Known(270_300, 270_500))
  assert result.outcome == p.Incompatible
  assert p.aperture(p.Known(0, 0), p.Known(1, 1)) == Error(p.InvalidDimension)
}

pub fn unknown_and_conflict_cannot_pass_test() {
  let assert Ok(missing) =
    p.capacity(p.Gram, [p.Known(100, 110), p.Missing], p.Known(1000, 1000))
  assert missing.outcome == p.Unknown
  assert missing.reason == p.MissingFact
  assert missing.required == None
  let assert Ok(conflict) =
    p.capacity(p.Gram, [p.Missing, p.Conflicting], p.Known(1000, 1000))
  assert conflict.outcome == p.Unknown
  assert conflict.reason == p.ConflictingFact
  let assert Ok(failed) = p.capacity(p.Gram, [p.Known(10, 11)], p.Known(9, 9))
  assert p.aggregate([missing, failed, conflict]) == Ok(p.Incompatible)
  assert p.aggregate([missing]) == Ok(p.Unknown)
  assert p.aggregate([]) == Error(p.InvalidCount)
}

pub fn count_and_range_refusal_test() {
  let known = p.Known(1, 1)
  assert p.capacity(p.Milliampere, [], known) == Error(p.InvalidCount)
  assert p.capacity(p.Milliampere, list.repeat(known, 65), known)
    == Error(p.InvalidCount)
  assert p.grid_axis(0, known, known, known, known) == Error(p.InvalidCount)
  assert p.grid_axis(9, known, known, known, known) == Error(p.InvalidCount)
  assert p.capacity(p.Gram, [p.Known(100_001, 100_001)], known)
    == Error(p.OutOfRange)
  assert p.capacity(p.Gram, [p.Missing, p.Known(-1, 0)], known)
    == Error(p.InvalidRange)
}
