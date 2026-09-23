defmodule Frameshift.Delivery.Transition do
  @moduledoc """
  Pure delivery decisions shared by the SQLite transaction owner.

  An accepted transport call is not display confirmation. These decisions
  preserve one pending direct intent and require exact revision and digest
  matches before current state may advance.
  """

  @type direct_intent :: %{
          required(:request_id) => String.t(),
          required(:desired_digest) => String.t(),
          required(:profile_id) => String.t(),
          required(:status) => String.t(),
          optional(:revision) => pos_integer()
        }

  @doc "Chooses whether a push request reuses, conflicts with, or creates an intent."
  @spec direct_request(direct_intent() | nil, String.t(), String.t(), String.t()) ::
          :insert | {:reuse, direct_intent()} | {:error, atom()}
  def direct_request(nil, _digest, _profile_id, _request_id), do: :insert

  def direct_request(existing, digest, profile_id, request_id) do
    cond do
      existing.request_id == request_id and existing.desired_digest == digest and
          existing.profile_id == profile_id ->
        {:reuse, existing}

      existing.request_id == request_id ->
        {:error, :request_id_conflict}

      existing.status == "pending" ->
        {:error, :direct_delivery_pending}

      true ->
        :insert
    end
  end

  @doc "Permits current-state activation only for the exact pending push intent."
  @spec direct_confirmation(
          direct_intent(),
          pos_integer(),
          String.t(),
          String.t(),
          :displayed | :pending
        ) :: :commit | :already | :pending | {:error, atom()}
  def direct_confirmation(intent, revision, request_id, digest, outcome)
      when outcome in [:displayed, :pending] do
    cond do
      intent.revision != revision or intent.request_id != request_id or
          intent.desired_digest != digest ->
        {:error, :direct_delivery_conflict}

      intent.status == "displayed" ->
        :already

      outcome == :pending ->
        :pending

      true ->
        :commit
    end
  end

  def direct_confirmation(_intent, _revision, _request_id, _digest, _outcome),
    do: {:error, :invalid_direct_delivery}

  @doc "Checks a pull acknowledgement against the one current manifest."
  @spec pull_confirmation(map(), map()) :: :commit | :pending | {:error, atom()}
  def pull_confirmation(manifest, acknowledgement) do
    cond do
      acknowledgement["manifestRevision"] != manifest["revision"] ->
        {:error, :outbox_revision_conflict}

      acknowledgement["refresh"] == "displayed" and
          acknowledgement["storage"] == "failed" ->
        {:error, :storage_not_verified}

      acknowledgement["refresh"] == "displayed" and
          acknowledgement["currentAsset"] != manifest["desiredAsset"] ->
        {:error, :current_asset_mismatch}

      acknowledgement["refresh"] == "displayed" ->
        :commit

      true ->
        :pending
    end
  end
end
