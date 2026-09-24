// Pure, cross-target decisions used by the host and installation guide.

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
