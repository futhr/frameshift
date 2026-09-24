// Pure, cross-target decisions used by the host and installation guide.
import gleam/order
import gleam/string

pub type Decision {
  Commit
  Already
  StillPending
}

pub type Refusal {
  InvalidInput
  Conflict
  StorageNotVerified
  CurrentAssetMismatch
  UnsupportedProfile
}

pub type RasterCandidate {
  RasterCandidate(
    id: String,
    width: Int,
    height: Int,
    maximum_asset_bytes: Int,
    channel_order: String,
    bit_depth: Int,
    compression: String,
    row_alignment: Int,
    byte_order: String,
  )
}

pub fn select_dwell(
  minimum_ms: Int,
  requested_ms: Int,
) -> Result(Int, Refusal) {
  case safe_positive(minimum_ms) && safe_positive(requested_ms) {
    True ->
      case requested_ms >= minimum_ms {
        True -> Ok(requested_ms)
        False -> Ok(minimum_ms)
      }

    False -> Error(InvalidInput)
  }
}

pub fn select_rgb24_profile(
  candidates: List(RasterCandidate),
  requested_id: String,
  color_kind: String,
  color_spaces: List(String),
  transfer_function: String,
) -> Result(String, Refusal) {
  case duplicate_profile_ids(candidates, []), candidates, requested_id {
    True, _, _ -> Error(UnsupportedProfile)
    _, [], _ -> Error(UnsupportedProfile)
    _, _, "" ->
      select_default_profile(
        candidates,
        "",
        color_kind,
        color_spaces,
        transfer_function,
      )

    _, _, _ ->
      select_requested_profile(
        candidates,
        requested_id,
        color_kind,
        color_spaces,
        transfer_function,
      )
  }
}

fn duplicate_profile_ids(
  candidates: List(RasterCandidate),
  seen: List(String),
) -> Bool {
  case candidates {
    [] -> False
    [candidate, ..rest] ->
      case contains_id(seen, candidate.id) {
        True -> True
        False -> duplicate_profile_ids(rest, [candidate.id, ..seen])
      }
  }
}

fn contains_id(ids: List(String), id: String) -> Bool {
  case ids {
    [] -> False
    [first, ..rest] ->
      case first == id {
        True -> True
        False -> contains_id(rest, id)
      }
  }
}

fn select_default_profile(
  candidates: List(RasterCandidate),
  best_id: String,
  color_kind: String,
  color_spaces: List(String),
  transfer_function: String,
) -> Result(String, Refusal) {
  case candidates {
    [] ->
      case best_id {
        "" -> Error(UnsupportedProfile)
        _ -> Ok(best_id)
      }

    [candidate, ..rest] -> {
      let better =
        compatible_rgb24(candidate, color_kind, color_spaces, transfer_function)
        && {
          best_id == "" || string.compare(candidate.id, best_id) == order.Lt
        }

      let next_best = case better {
        True -> candidate.id
        False -> best_id
      }
      select_default_profile(
        rest,
        next_best,
        color_kind,
        color_spaces,
        transfer_function,
      )
    }
  }
}

fn select_requested_profile(
  candidates: List(RasterCandidate),
  requested_id: String,
  color_kind: String,
  color_spaces: List(String),
  transfer_function: String,
) -> Result(String, Refusal) {
  case candidates {
    [] -> Error(UnsupportedProfile)
    [candidate, ..rest] ->
      case candidate.id == requested_id {
        True ->
          case
            compatible_rgb24(
              candidate,
              color_kind,
              color_spaces,
              transfer_function,
            )
          {
            True -> Ok(candidate.id)
            False -> Error(UnsupportedProfile)
          }

        False ->
          select_requested_profile(
            rest,
            requested_id,
            color_kind,
            color_spaces,
            transfer_function,
          )
      }
  }
}

fn compatible_rgb24(
  candidate: RasterCandidate,
  color_kind: String,
  color_spaces: List(String),
  transfer_function: String,
) -> Bool {
  let dimensions_valid =
    candidate.width > 0
    && candidate.width <= 32_768
    && candidate.height > 0
    && candidate.height <= 32_768

  case dimensions_valid {
    False -> False
    True -> {
      let pixels = candidate.width * candidate.height
      candidate.id != ""
      && pixels <= 16_777_216
      && candidate.maximum_asset_bytes >= pixels * 3
      && candidate.maximum_asset_bytes <= 1_073_741_824
      && candidate.channel_order == "rgb"
      && candidate.bit_depth == 8
      && candidate.compression == "none"
      && candidate.row_alignment == 1
      && candidate.byte_order == "not-applicable"
      && color_kind == "continuous"
      && contains_srgb(color_spaces)
      && transfer_function == "srgb"
    }
  }
}

fn contains_srgb(spaces: List(String)) -> Bool {
  case spaces {
    [] -> False
    ["srgb", ..] -> True
    [_, ..rest] -> contains_srgb(rest)
  }
}

pub fn direct_confirmation(
  intent_revision: Int,
  intent_request_id: String,
  intent_digest: String,
  intent_status: String,
  revision: Int,
  request_id: String,
  digest: String,
  outcome: String,
) -> Result(Decision, Refusal) {
  case
    safe_positive(intent_revision) && safe_positive(revision),
    valid_direct_status(intent_status) && valid_direct_status(outcome)
  {
    True, True ->
      direct_match(
        intent_revision,
        intent_request_id,
        intent_digest,
        intent_status,
        revision,
        request_id,
        digest,
        outcome,
      )

    _, _ -> Error(InvalidInput)
  }
}

fn direct_match(
  intent_revision: Int,
  intent_request_id: String,
  intent_digest: String,
  intent_status: String,
  revision: Int,
  request_id: String,
  digest: String,
  outcome: String,
) -> Result(Decision, Refusal) {
  case
    intent_revision == revision,
    intent_request_id == request_id,
    intent_digest == digest
  {
    True, True, True ->
      case intent_status, outcome {
        "displayed", _ -> Ok(Already)
        _, "pending" -> Ok(StillPending)
        _, "displayed" -> Ok(Commit)
        _, _ -> Error(InvalidInput)
      }

    _, _, _ -> Error(Conflict)
  }
}

pub fn pull_confirmation(
  manifest_revision: Int,
  desired_digest: String,
  acknowledgement_revision: Int,
  current_digest: String,
  storage: String,
  refresh: String,
) -> Result(Decision, Refusal) {
  case
    safe_positive(manifest_revision) && safe_positive(acknowledgement_revision),
    valid_storage(storage) && valid_refresh(refresh)
  {
    True, True ->
      pull_match(
        manifest_revision,
        desired_digest,
        acknowledgement_revision,
        current_digest,
        storage,
        refresh,
      )

    _, _ -> Error(InvalidInput)
  }
}

fn pull_match(
  manifest_revision: Int,
  desired_digest: String,
  acknowledgement_revision: Int,
  current_digest: String,
  storage: String,
  refresh: String,
) -> Result(Decision, Refusal) {
  case manifest_revision == acknowledgement_revision, refresh {
    False, _ -> Error(Conflict)
    True, "not-requested" -> Ok(StillPending)
    True, "failed" -> Ok(StillPending)
    True, "displayed" -> displayed_pull(desired_digest, current_digest, storage)
    _, _ -> Error(InvalidInput)
  }
}

fn displayed_pull(
  desired_digest: String,
  current_digest: String,
  storage: String,
) -> Result(Decision, Refusal) {
  case storage, desired_digest == current_digest {
    "failed", _ -> Error(StorageNotVerified)
    _, False -> Error(CurrentAssetMismatch)
    _, True -> Ok(Commit)
  }
}

fn safe_positive(value: Int) -> Bool {
  value > 0 && value <= 9_007_199_254_740_991
}

fn valid_direct_status(status: String) -> Bool {
  case status {
    "pending" | "displayed" -> True
    _ -> False
  }
}

fn valid_storage(storage: String) -> Bool {
  case storage {
    "verified" | "unchanged" | "failed" -> True
    _ -> False
  }
}

fn valid_refresh(refresh: String) -> Bool {
  case refresh {
    "not-requested" | "displayed" | "failed" -> True
    _ -> False
  }
}
