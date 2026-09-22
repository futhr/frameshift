defmodule Frameshift.Simulator do
  @moduledoc """
  Persistent in-process simulator for Frame Protocol conformance work.

  The simulator models verified immutable storage, desired/current separation,
  physical display completion, still playlists, and injected interruption
  points. It is not evidence for a physical panel or production TLS stack.
  """

  use GenServer

  alias Frameshift.ContentStore
  alias Frameshift.Digest
  alias Frameshift.Protocol.Schema
  alias Frameshift.Simulator.Persistence
  alias Frameshift.Simulator.State

  @allowed_faults [
    :corrupt_upload,
    :display_failure,
    :missed_contact,
    :power_loss_at,
    :slow_refresh_ms,
    :storage_full
  ]

  @type server :: GenServer.server()

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    with {:ok, capabilities} <- Keyword.fetch(options, :capabilities),
         :ok <- Schema.validate("capabilities", capabilities) do
      case Keyword.get(options, :name, __MODULE__) do
        nil -> GenServer.start_link(__MODULE__, options)
        name -> GenServer.start_link(__MODULE__, options, name: name)
      end
    else
      :error -> {:error, :capabilities_required}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec capabilities(server()) :: map()
  def capabilities(server \\ __MODULE__), do: GenServer.call(server, :capabilities)

  @spec state(server()) :: %{state: map(), etag: String.t()}
  def state(server \\ __MODULE__), do: GenServer.call(server, :state)

  @spec set_faults(server(), map()) :: :ok | {:error, term()}
  def set_faults(server \\ __MODULE__, faults), do: GenServer.call(server, {:set_faults, faults})

  @spec put_asset(server(), String.t(), String.t(), binary()) ::
          {:ok, :created | :existing} | {:error, term()}
  def put_asset(server \\ __MODULE__, digest, profile_id, bytes) do
    GenServer.call(server, {:put_asset, digest, profile_id, bytes}, :infinity)
  end

  @spec has_asset?(server(), String.t()) :: boolean()
  def has_asset?(server \\ __MODULE__, digest), do: GenServer.call(server, {:has_asset, digest})

  @spec delete_asset(server(), String.t()) :: :ok | {:error, term()}
  def delete_asset(server \\ __MODULE__, digest),
    do: GenServer.call(server, {:delete_asset, digest})

  @spec set_desired(server(), map(), String.t()) :: {:ok, map()} | {:error, term()}
  def set_desired(server \\ __MODULE__, request, precondition) do
    GenServer.call(server, {:set_desired, request, precondition}, :infinity)
  end

  @spec retry_display(server()) :: {:ok, map()} | {:error, term()}
  def retry_display(server \\ __MODULE__), do: GenServer.call(server, :retry_display, :infinity)

  @spec set_playlist(server(), map(), String.t()) :: {:ok, map()} | {:error, term()}
  def set_playlist(server \\ __MODULE__, playlist, precondition) do
    GenServer.call(server, {:set_playlist, playlist, precondition})
  end

  @spec pull_outbox(server(), map(), binary()) ::
          {:ok, :no_work | map()} | {:error, term()}
  def pull_outbox(server \\ __MODULE__, manifest, bytes) do
    GenServer.call(server, {:pull_outbox, manifest, bytes}, :infinity)
  end

  @impl true
  def init(options) do
    capabilities = Keyword.fetch!(options, :capabilities)
    data_dir = options |> Keyword.fetch!(:data_dir) |> Path.expand()

    with :ok <- Schema.validate("capabilities", capabilities),
         :ok <- ContentStore.prepare(data_dir),
         {:ok, state} <- load_state(data_dir, capabilities),
         :ok <- verify_assets(state),
         {:ok, recovered} <- recover_interrupted(state) do
      {:ok, recovered}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call(:capabilities, _from, state), do: {:reply, state.capabilities, state}

  def handle_call(:state, _from, state) do
    {:reply, %{state: State.public(state), etag: State.etag(state)}, state}
  end

  def handle_call({:set_faults, faults}, _from, state) do
    if valid_faults?(faults),
      do: {:reply, :ok, %{state | faults: faults}},
      else: {:reply, {:error, :invalid_faults}, state}
  end

  def handle_call({:has_asset, digest}, _from, state) do
    {:reply, Map.has_key?(state.assets, digest), state}
  end

  def handle_call({:put_asset, digest, profile_id, bytes}, _from, state) do
    case put_asset_record(state, digest, profile_id, bytes) do
      {:ok, disposition, next_state} -> {:reply, {:ok, disposition}, next_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:delete_asset, digest}, _from, state) do
    case delete_asset_record(state, digest) do
      {:ok, next_state} -> {:reply, :ok, next_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:set_desired, request, precondition}, _from, state) do
    case set_desired_record(state, request, precondition) do
      {:ok, next_state} -> {:reply, {:ok, State.public(next_state)}, next_state}
      {:error, reason, next_state} -> {:reply, {:error, reason}, next_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:retry_display, _from, %{desired_asset: nil} = state) do
    {:reply, {:error, :asset_missing}, state}
  end

  def handle_call(:retry_display, _from, state) do
    preparing =
      state
      |> Map.put(:display_state, "preparing")
      |> Map.put(:last_error, nil)
      |> State.bump()

    case Persistence.save(preparing) do
      :ok ->
        case perform_display(preparing) do
          {:ok, next_state} -> {:reply, {:ok, State.public(next_state)}, next_state}
          {:error, reason, next_state} -> {:reply, {:error, reason}, next_state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:set_playlist, playlist, precondition}, _from, state) do
    case set_playlist_record(state, playlist, precondition) do
      {:ok, next_state} -> {:reply, {:ok, State.public(next_state)}, next_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:pull_outbox, manifest, bytes}, _from, state) do
    case pull_outbox_record(state, manifest, bytes) do
      {:ok, acknowledgement, next_state} ->
        {:reply, {:ok, acknowledgement}, next_state}

      {:error, reason, next_state} ->
        {:reply, {:error, reason}, next_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp load_state(data_dir, capabilities) do
    case Persistence.load(data_dir) do
      :empty -> {:ok, State.new(capabilities, data_dir)}
      {:ok, payload} -> {:ok, State.from_persisted(payload, capabilities, data_dir)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp recover_interrupted(%{display_state: display_state} = state)
       when display_state in ["preparing", "refreshing"] do
    recovered =
      state
      |> Map.put(:display_state, "recovering")
      |> Map.put(:last_error, problem("power-interrupted", "Display outcome requires recovery"))
      |> State.bump()

    case Persistence.save(recovered) do
      :ok -> {:ok, recovered}
      {:error, reason} -> {:error, reason}
    end
  end

  defp recover_interrupted(state), do: {:ok, state}

  defp verify_assets(state) do
    case Enum.find(Map.keys(state.assets), fn digest ->
           not File.regular?(ContentStore.object_path(state.data_dir, digest))
         end) do
      nil -> :ok
      digest -> {:error, {:asset_missing, digest}}
    end
  end

  defp valid_faults?(faults) when is_map(faults) do
    Enum.all?(Map.keys(faults), &(&1 in @allowed_faults)) and
      Enum.all?(
        [:corrupt_upload, :display_failure, :missed_contact, :storage_full],
        &(Map.get(faults, &1) in [nil, true, false])
      ) and
      valid_slow_refresh?(Map.get(faults, :slow_refresh_ms, 0)) and
      Map.get(faults, :power_loss_at) in [nil, :after_desired, :during_refresh, :after_refresh]
  end

  defp valid_faults?(_faults), do: false

  defp valid_slow_refresh?(milliseconds),
    do: is_integer(milliseconds) and milliseconds >= 0 and milliseconds <= 60_000

  defp put_asset_record(state, digest, profile_id, bytes) when is_binary(bytes) do
    candidate = if state.faults[:corrupt_upload], do: bytes <> <<0>>, else: bytes

    with true <- Digest.valid_sha256?(digest),
         true <- Digest.sha256(candidate) == digest,
         {:ok, profile} <- find_profile(state, profile_id),
         :ok <- validate_asset_size(profile, candidate),
         :ok <- ensure_storage(state, digest, byte_size(candidate)),
         {:ok, _digest, byte_count, placement} <- ContentStore.put(state.data_dir, candidate) do
      commit_asset(state, digest, profile_id, byte_count, placement)
    else
      false -> {:error, :digest_mismatch}
      :not_found -> {:error, :unsupported_profile}
      {:error, reason} -> {:error, reason}
    end
  end

  defp put_asset_record(_state, _digest, _profile_id, _bytes), do: {:error, :invalid_asset}

  defp find_profile(state, profile_id) do
    case Enum.find(state.capabilities["storage"]["artifactProfiles"], &(&1["id"] == profile_id)) do
      nil -> :not_found
      profile -> {:ok, profile}
    end
  end

  defp validate_asset_size(profile, bytes) do
    byte_count = byte_size(bytes)

    cond do
      byte_count > profile["maximumAssetBytes"] -> {:error, :asset_too_large}
      exact_size(profile) not in [nil, byte_count] -> {:error, :invalid_dimensions}
      true -> :ok
    end
  end

  defp exact_size(
         %{"compression" => "none", "channelOrder" => order, "bitDepth" => bit_depth} = profile
       )
       when order in ["rgb", "bgr", "rgba", "bgra"] and is_integer(bit_depth) do
    channels = if order in ["rgb", "bgr"], do: 3, else: 4
    bytes_per_channel = div(bit_depth + 7, 8)
    profile["width"] * profile["height"] * channels * bytes_per_channel
  end

  defp exact_size(_profile), do: nil

  defp ensure_storage(state, digest, byte_count) do
    storage = state.capabilities["storage"]
    summary = State.storage_summary(state)

    cond do
      Map.has_key?(state.assets, digest) -> :ok
      state.faults[:storage_full] -> {:error, :storage_full}
      map_size(state.assets) >= storage["maximumAssetCount"] -> {:error, :storage_full}
      byte_count > storage["maximumAssetBytes"] -> {:error, :asset_too_large}
      byte_count > summary["availableBytes"] -> {:error, :storage_full}
      true -> :ok
    end
  end

  defp commit_asset(state, digest, profile_id, byte_count, placement) do
    if Map.has_key?(state.assets, digest) do
      {:ok, :existing, state}
    else
      persist_new_asset(state, digest, profile_id, byte_count, placement)
    end
  end

  defp persist_new_asset(state, digest, profile_id, byte_count, placement) do
    next_state =
      state
      |> Map.update!(
        :assets,
        &Map.put(&1, digest, %{"profileId" => profile_id, "byteCount" => byte_count})
      )
      |> State.bump()

    case Persistence.save(next_state) do
      :ok ->
        disposition = if placement == :existing, do: :existing, else: :created
        {:ok, disposition, next_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp delete_asset_record(state, digest) do
    cond do
      not Map.has_key?(state.assets, digest) -> {:ok, state}
      protected_asset?(state, digest) -> {:error, :asset_referenced}
      true -> delete_unreferenced_asset(state, digest)
    end
  end

  defp protected_asset?(state, digest) do
    digest in [state.desired_asset, state.current_asset, state.previous_known_good] or
      Enum.any?(get_in(state.playlist || %{}, ["entries"]) || [], &(&1["assetDigest"] == digest))
  end

  defp delete_unreferenced_asset(state, digest) do
    next_state = state |> Map.update!(:assets, &Map.delete(&1, digest)) |> State.bump()

    case Persistence.save(next_state) do
      :ok ->
        case ContentStore.delete_active(state.data_dir, digest) do
          :ok -> {:ok, next_state}
          {:error, :enoent} -> {:ok, next_state}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp set_desired_record(state, request, precondition) do
    with :ok <- Schema.validate("desired", request),
         {:new, request_hash} <- request_status(state, request),
         :ok <- check_precondition(state, precondition),
         {:ok, asset} <- Map.fetch(state.assets, request["assetDigest"]),
         true <- asset["profileId"] == request["artifactProfile"] do
      accept_desired(state, request, request_hash)
    else
      {:repeat, _request_hash} -> {:ok, state}
      {:conflict, _request_hash} -> {:error, :request_id_conflict}
      :error -> {:error, :asset_missing}
      false -> {:error, :unsupported_profile}
      {:error, reason} -> {:error, normalize_schema_error(reason)}
    end
  end

  defp request_status(state, request) do
    request_hash = Digest.sha256(RFC8785.encode!(request))

    case state.requests[request["requestId"]] do
      nil -> {:new, request_hash}
      ^request_hash -> {:repeat, request_hash}
      _different -> {:conflict, request_hash}
    end
  end

  defp check_precondition(%{desired_asset: nil}, "*"), do: :ok

  defp check_precondition(state, precondition) do
    if precondition == State.etag(state), do: :ok, else: {:error, :state_precondition}
  end

  defp accept_desired(state, request, request_hash) do
    accepted =
      state
      |> Map.put(:desired_asset, request["assetDigest"])
      |> Map.put(:desired_profile, request["artifactProfile"])
      |> Map.put(:pending_request_id, request["requestId"])
      |> Map.put(:display_state, "preparing")
      |> Map.put(:last_error, nil)
      |> Map.update!(:requests, &Map.put(&1, request["requestId"], request_hash))
      |> State.bump()

    with :ok <- Persistence.save(accepted) do
      if accepted.faults[:power_loss_at] == :after_desired,
        do: {:error, :power_loss, accepted},
        else: perform_display(accepted)
    end
  end

  defp perform_display(state) do
    refreshing = state |> Map.put(:display_state, "refreshing") |> State.bump()

    case Persistence.save(refreshing) do
      :ok ->
        maybe_delay(refreshing.faults[:slow_refresh_ms])
        display_outcome(refreshing)

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  defp display_outcome(%{faults: %{power_loss_at: checkpoint}} = state)
       when checkpoint in [:during_refresh, :after_refresh],
       do: {:error, :power_loss, state}

  defp display_outcome(%{faults: %{display_failure: true}} = state) do
    failed =
      state
      |> Map.put(:display_state, "failed")
      |> Map.put(:last_error, problem("display-failed", "Display adapter reported failure"))
      |> State.bump()

    case Persistence.save(failed) do
      :ok -> {:error, :display_failed, failed}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp display_outcome(state) do
    displayed =
      state
      |> Map.put(:previous_known_good, state.current_asset)
      |> Map.put(:current_asset, state.desired_asset)
      |> Map.put(:pending_request_id, nil)
      |> Map.put(:display_state, "displayed")
      |> Map.put(:last_error, nil)
      |> State.bump()

    case Persistence.save(displayed) do
      :ok -> {:ok, displayed}
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp maybe_delay(nil), do: :ok
  defp maybe_delay(0), do: :ok
  defp maybe_delay(milliseconds), do: Process.sleep(milliseconds)

  defp set_playlist_record(state, playlist, precondition) do
    with :ok <- Schema.validate("playlist", playlist),
         :ok <- check_precondition(state, precondition),
         :ok <- validate_playlist_capabilities(state, playlist) do
      next_state = state |> Map.put(:playlist, playlist) |> State.bump()

      case Persistence.save(next_state) do
        :ok -> {:ok, next_state}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, reason} -> {:error, normalize_schema_error(reason)}
    end
  end

  defp pull_outbox_record(%{faults: %{missed_contact: true}}, _manifest, _bytes),
    do: {:error, :contact_missed}

  defp pull_outbox_record(state, manifest, bytes) when is_binary(bytes) do
    case Schema.validate("outbox-manifest", manifest) do
      :ok -> receive_outbox_manifest(state, manifest, bytes)
      {:error, reason} -> {:error, normalize_schema_error(reason)}
    end
  end

  defp pull_outbox_record(_state, _manifest, _bytes), do: {:error, :invalid_document}

  defp receive_outbox_manifest(state, %{"desiredAsset" => nil}, _bytes),
    do: {:ok, :no_work, state}

  defp receive_outbox_manifest(state, manifest, bytes),
    do: receive_outbox_asset(state, manifest, bytes)

  defp receive_outbox_asset(state, manifest, bytes) do
    digest = manifest["desiredAsset"]
    profile_id = manifest["artifactProfile"]

    case put_asset_record(state, digest, profile_id, bytes) do
      {:ok, disposition, uploaded} -> activate_outbox_asset(uploaded, manifest, disposition)
      {:error, reason} -> {:error, reason}
    end
  end

  defp activate_outbox_asset(state, manifest, disposition) do
    request = %{
      "assetDigest" => manifest["desiredAsset"],
      "artifactProfile" => manifest["artifactProfile"],
      "requestId" => "outbox-#{manifest["revision"]}"
    }

    precondition = if state.desired_asset == nil, do: "*", else: State.etag(state)

    case set_desired_record(state, request, precondition) do
      {:ok, next_state} ->
        complete_outbox_display(next_state, manifest, disposition)

      {:error, :display_failed, failed} ->
        outbox_acknowledgement(manifest, disposition, "failed", failed)

      {:error, reason, next_state} ->
        {:error, reason, next_state}

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  defp complete_outbox_display(state, manifest, disposition) do
    cond do
      state.current_asset == manifest["desiredAsset"] and state.display_state == "displayed" ->
        outbox_acknowledgement(manifest, disposition, "displayed", state)

      state.desired_asset == manifest["desiredAsset"] ->
        resume_outbox_display(state, manifest, disposition)

      true ->
        {:error, :manifest_superseded, state}
    end
  end

  defp resume_outbox_display(state, manifest, disposition) do
    case perform_display(state) do
      {:ok, displayed} ->
        outbox_acknowledgement(manifest, disposition, "displayed", displayed)

      {:error, :display_failed, failed} ->
        outbox_acknowledgement(manifest, disposition, "failed", failed)

      {:error, reason, next_state} ->
        {:error, reason, next_state}
    end
  end

  defp outbox_acknowledgement(manifest, disposition, refresh, state) do
    acknowledgement = %{
      "manifestRevision" => manifest["revision"],
      "storage" => if(disposition == :existing, do: "unchanged", else: "verified"),
      "refresh" => refresh,
      "currentAsset" => state.current_asset,
      "lastError" => state.last_error
    }

    case Schema.validate("outbox-ack", acknowledgement) do
      :ok -> {:ok, acknowledgement, state}
      {:error, reason} -> {:error, normalize_schema_error(reason), state}
    end
  end

  defp validate_playlist_capabilities(state, playlist) do
    storage = state.capabilities["storage"]
    minimum_dwell = state.capabilities["refresh"]["minimumDwellMs"]

    cond do
      length(playlist["entries"]) > storage["maximumPlaylistLength"] ->
        {:error, :playlist_too_long}

      Enum.any?(playlist["entries"], &(&1["dwellMs"] < minimum_dwell)) ->
        {:error, :dwell_too_short}

      Enum.any?(playlist["entries"], &(not Map.has_key?(state.assets, &1["assetDigest"]))) ->
        {:error, :asset_missing}

      true ->
        :ok
    end
  end

  defp normalize_schema_error(%JSV.ValidationError{}), do: :invalid_document
  defp normalize_schema_error(reason), do: reason

  defp problem(type, title) do
    %{"type" => "urn:frameshift:problem:#{type}", "title" => title}
  end
end
