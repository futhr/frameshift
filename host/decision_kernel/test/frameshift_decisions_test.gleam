import frameshift_decisions as decisions
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn dwell_bounds_test() {
  assert decisions.select_dwell(180_000, 60_000) == Ok(180_000)
  assert decisions.select_dwell(180_000, 360_000) == Ok(360_000)
  assert decisions.select_dwell(0, 360_000) == Error(decisions.InvalidInput)
  let outside_safe_range = 9_007_199_254_740_991 + 1
  assert decisions.select_dwell(180_000, outside_safe_range)
    == Error(decisions.InvalidInput)
}

pub fn direct_confirmation_test() {
  assert decisions.direct_confirmation(
      3,
      "request",
      "digest",
      "pending",
      3,
      "request",
      "digest",
      "displayed",
    )
    == Ok(decisions.Commit)

  assert decisions.direct_confirmation(
      3,
      "request",
      "digest",
      "pending",
      3,
      "request",
      "digest",
      "pending",
    )
    == Ok(decisions.StillPending)

  assert decisions.direct_confirmation(
      3,
      "request",
      "digest",
      "displayed",
      3,
      "request",
      "digest",
      "displayed",
    )
    == Ok(decisions.Already)

  assert decisions.direct_confirmation(
      3,
      "request",
      "digest",
      "pending",
      4,
      "request",
      "digest",
      "displayed",
    )
    == Error(decisions.Conflict)

  assert decisions.direct_confirmation(
      3,
      "request",
      "digest",
      "pending",
      3,
      "other",
      "digest",
      "displayed",
    )
    == Error(decisions.Conflict)

  assert decisions.direct_confirmation(
      3,
      "request",
      "digest",
      "unknown",
      3,
      "request",
      "digest",
      "displayed",
    )
    == Error(decisions.InvalidInput)
}

pub fn pull_confirmation_test() {
  assert decisions.pull_confirmation(
      3,
      "digest",
      3,
      "digest",
      "verified",
      "displayed",
    )
    == Ok(decisions.Commit)

  assert decisions.pull_confirmation(3, "digest", 3, "", "verified", "failed")
    == Ok(decisions.StillPending)

  assert decisions.pull_confirmation(
      3,
      "digest",
      3,
      "digest",
      "unchanged",
      "displayed",
    )
    == Ok(decisions.Commit)

  assert decisions.pull_confirmation(
      3,
      "digest",
      3,
      "digest",
      "verified",
      "not-requested",
    )
    == Ok(decisions.StillPending)

  assert decisions.pull_confirmation(
      3,
      "digest",
      4,
      "digest",
      "verified",
      "displayed",
    )
    == Error(decisions.Conflict)

  assert decisions.pull_confirmation(
      3,
      "digest",
      3,
      "digest",
      "failed",
      "displayed",
    )
    == Error(decisions.StorageNotVerified)

  assert decisions.pull_confirmation(
      3,
      "digest",
      3,
      "other",
      "verified",
      "displayed",
    )
    == Error(decisions.CurrentAssetMismatch)
}
