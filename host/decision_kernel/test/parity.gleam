// Test-only deterministic corpus, executed on Erlang and JavaScript.
import frameshift_decisions as decisions
import gleam/int
import gleam/io

pub fn main() -> Nil {
  emit(0, 256)
}

fn emit(index: Int, remaining: Int) -> Nil {
  case remaining {
    0 -> Nil
    _ -> {
      io.println(record(index))
      emit(index + 1, remaining - 1)
    }
  }
}

fn record(index: Int) -> String {
  "case|"
  <> int.to_string(index)
  <> "|"
  <> dwell_record(index)
  <> "|"
  <> profile_record(index)
  <> "|"
  <> direct_record(index)
  <> "|"
  <> pull_record(index)
}

fn divisible(index: Int, divisor: Int) -> Bool {
  int.remainder(index, divisor) == Ok(0)
}

fn dwell_record(index: Int) -> String {
  let minimum = 1 + index * 73
  let requested = case divisible(index, 7), divisible(index, 5) {
    True, _ -> 0
    False, True -> minimum - 1
    False, False -> minimum + index
  }
  case decisions.select_dwell(minimum, requested) {
    Ok(value) -> "ok:" <> int.to_string(value)
    Error(reason) -> "error:" <> refusal_name(reason)
  }
}

fn profile_record(index: Int) -> String {
  let width = 1 + index * 7
  let height = 1 + index * 5
  let capacity = width * height * 3
  let candidate =
    decisions.RasterCandidate(
      id: "p" <> int.to_string(index),
      width: width,
      height: height,
      maximum_asset_bytes: case divisible(index, 3) {
        True -> capacity - 1
        False -> capacity
      },
      channel_order: "rgb",
      bit_depth: 8,
      compression: "none",
      row_alignment: 1,
      byte_order: "not-applicable",
    )
  let candidates = case divisible(index, 17) {
    True -> [candidate, candidate]
    False -> [candidate]
  }
  let requested_id = case divisible(index, 11) {
    True -> "missing"
    False -> ""
  }
  let color_kind = case divisible(index, 13) {
    True -> "indexed"
    False -> "continuous"
  }
  case
    decisions.select_rgb24_profile(
      candidates,
      requested_id,
      color_kind,
      ["srgb"],
      "srgb",
    )
  {
    Ok(value) -> "ok:" <> value
    Error(reason) -> "error:" <> refusal_name(reason)
  }
}

fn direct_record(index: Int) -> String {
  let revision = index + 1
  let acknowledgement_revision = case divisible(index, 5) {
    True -> revision + 1
    False -> revision
  }
  let acknowledgement_digest = case divisible(index, 7) {
    True -> "other"
    False -> "digest"
  }
  let status = case divisible(index, 23) {
    True -> "unknown"
    False -> "pending"
  }
  let outcome = case divisible(index, 11), int.is_even(index) {
    True, _ -> "unknown"
    False, True -> "displayed"
    False, False -> "pending"
  }
  decisions.direct_confirmation(
    revision,
    "request",
    "digest",
    status,
    acknowledgement_revision,
    "request",
    acknowledgement_digest,
    outcome,
  )
  |> decision_record
}

fn pull_record(index: Int) -> String {
  let revision = index + 1
  let acknowledgement_revision = case divisible(index, 19) {
    True -> revision + 1
    False -> revision
  }
  let current_digest = case divisible(index, 7) {
    True -> "other"
    False -> "digest"
  }
  let storage = case divisible(index, 23) {
    True -> "failed"
    False -> "verified"
  }
  let refresh = case divisible(index, 13), divisible(index, 5) {
    True, _ -> "unknown"
    False, True -> "failed"
    False, False -> "displayed"
  }
  decisions.pull_confirmation(
    revision,
    "digest",
    acknowledgement_revision,
    current_digest,
    storage,
    refresh,
  )
  |> decision_record
}

fn decision_record(
  result: Result(decisions.Decision, decisions.Refusal),
) -> String {
  case result {
    Ok(decisions.Commit) -> "ok:commit"
    Ok(decisions.Already) -> "ok:already"
    Ok(decisions.StillPending) -> "ok:pending"
    Error(reason) -> "error:" <> refusal_name(reason)
  }
}

fn refusal_name(reason: decisions.Refusal) -> String {
  case reason {
    decisions.InvalidInput -> "invalid-input"
    decisions.Conflict -> "conflict"
    decisions.StorageNotVerified -> "storage-not-verified"
    decisions.CurrentAssetMismatch -> "current-asset-mismatch"
    decisions.UnsupportedProfile -> "unsupported-profile"
  }
}
