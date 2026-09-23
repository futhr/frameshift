defmodule FrameshiftContainerReceiver do
  @moduledoc """
  Independent one-contact frame receiver for Docker integration tests.

  Its disk state and TLS peer are separate from the host process. The selected
  class labels a manufacturer fixture; no physical display is emulated.
  """

  require Record

  Record.defrecordp(
    :otp_certificate,
    Record.extract(:OTPCertificate, from_lib: "public_key/include/public_key.hrl")
  )

  Record.defrecordp(
    :otp_tbs_certificate,
    Record.extract(:OTPTBSCertificate, from_lib: "public_key/include/public_key.hrl")
  )

  @maximum_control_bytes 65_536
  @maximum_asset_bytes 32 * 1024 * 1024
  @maximum_header_bytes 65_536

  @profiles %{
    "paper" => %{model: "Waveshare 13.3-inch e-Paper HAT+ (E)", width: 1600, height: 1200, refresh_ms: 19_000},
    "photo" => %{model: "BOE MV270QHM-N40 Rev.P1", width: 2560, height: 1440, refresh_ms: 17},
    "pixel" => %{model: "Waveshare RGB-Matrix-P3-64x64 3x2", width: 192, height: 128, refresh_ms: 17}
  }

  def main do
    config = configuration!()
    File.mkdir_p!(config.data_dir)
    state = load_state!(config)

    result =
      case config.fault do
        "missed_contact" -> %{outcome: "missed_contact", state: state}
        _ -> contact!(config, state)
      end

    IO.puts(encode_json(result))
  rescue
    exception ->
      IO.puts(:stderr, Exception.message(exception))
      System.halt(1)
  end

  defp configuration! do
    class = System.fetch_env!("FS_FRAME_CLASS")
    profile = Map.fetch!(@profiles, class)
    fault = System.get_env("FS_FAULT", "none")

    unless fault in ~w(none missed_contact corrupt_transfer storage_full display_failure power_loss_after_download stale_ack) do
      raise "invalid fault"
    end

    %{
      class: class,
      model: profile.model,
      artifact_bytes: profile.width * profile.height * 3,
      scenario_refresh_ms: profile.refresh_ms,
      fault: fault,
      data_dir: System.fetch_env!("FS_DATA_DIR"),
      host: System.fetch_env!("FS_HOST"),
      port: System.fetch_env!("FS_PORT") |> String.to_integer(),
      host_pin: System.fetch_env!("FS_HOST_SPKI"),
      certfile: System.fetch_env!("FS_CERTFILE"),
      keyfile: System.fetch_env!("FS_KEYFILE"),
      profile_id: System.fetch_env!("FS_PROFILE_ID"),
      refresh_delay_ms: System.get_env("FS_REFRESH_DELAY_MS", "0") |> String.to_integer(),
      temperature_c: System.get_env("FS_TEMPERATURE_C", "25") |> String.to_integer()
    }
  end

  defp load_state!(config) do
    path = Path.join(config.data_dir, "state.json")

    state =
      case File.read(path) do
        {:ok, bytes} when byte_size(bytes) <= @maximum_control_bytes ->
          decode_json(bytes)

        {:error, :enoent} ->
          %{"class" => config.class, "currentAsset" => nil, "desiredAsset" => nil}

        _ ->
          raise "invalid persisted state"
      end

    if state["class"] != config.class, do: raise("frame class changed across restart")
    verify_current!(state, config.data_dir, config.artifact_bytes)
    state
  end

  defp verify_current!(%{"currentAsset" => nil}, _, _), do: :ok

  defp verify_current!(%{"currentAsset" => digest}, data_dir, expected_bytes) do
    path = asset_path!(data_dir, digest)
    bytes = File.read!(path)
    if byte_size(bytes) != expected_bytes or digest_bytes(bytes) != digest,
      do: raise("persisted current asset corrupt")
  end

  defp contact!(config, state) do
    case exchange!(config, "GET", "/v0/outbox/manifest", nil) do
      %{status: 204} -> %{outcome: "empty", state: state}
      %{status: 200, body: body} -> process_manifest!(config, state, body)
      _ -> raise "manifest request failed"
    end
  end

  defp process_manifest!(config, state, body) do
    if byte_size(body) > @maximum_control_bytes, do: raise("manifest too large")
    manifest = decode_json(body)
    digest = Map.fetch!(manifest, "desiredAsset")
    revision = Map.fetch!(manifest, "revision")
    profile_id = Map.fetch!(manifest, "artifactProfile")

    unless is_integer(revision) and revision > 0 and profile_id == config.profile_id do
      raise "unexpected manifest profile or revision"
    end

    cond do
      is_nil(digest) -> %{outcome: "no_work", state: state}
      not valid_digest?(digest) -> raise "invalid manifest digest"
      true -> apply_manifest!(config, state, digest, revision)
    end
  end

  defp apply_manifest!(config, state, digest, revision) do
    existing = verified_asset?(config.data_dir, digest, config.artifact_bytes)

    cond do
      config.fault == "storage_full" and not existing ->
        acknowledge_failure!(config, state, revision, "failed", "not-requested", "storage-full")

      true ->
        store_and_display!(config, state, digest, revision, existing)
    end
  end

  defp store_and_display!(config, state, digest, revision, existing) do
    unless existing do
      hex = String.replace_prefix(digest, "sha256:", "")
      response = exchange!(config, "GET", "/v0/outbox/assets/sha256/#{hex}", nil)
      if response.status != 200, do: raise("asset request failed")
      verify_asset_response!(response, digest, config.fault, config.artifact_bytes)
      durable_write!(asset_path!(config.data_dir, digest), response.body)
    end

    desired = Map.put(state, "desiredAsset", digest)
    durable_state!(config.data_dir, desired)

    case config.fault do
      "power_loss_after_download" ->
        System.halt(23)

      "display_failure" ->
        acknowledge_failure!(
          config,
          desired,
          revision,
          storage(existing),
          "failed",
          "display-failed"
        )

      _ ->
        maybe_display!(config, desired, digest, revision, existing)
    end
  end

  defp maybe_display!(
         %{class: "paper", temperature_c: temperature} = config,
         state,
         _digest,
         revision,
         existing
       )
       when temperature < 0 or temperature > 40 do
    acknowledge_failure!(
      config,
      state,
      revision,
      storage(existing),
      "failed",
      "temperature-out-of-range"
    )
  end

  defp maybe_display!(config, state, digest, revision, existing),
    do: display_and_ack!(config, state, digest, revision, existing)

  defp display_and_ack!(config, state, digest, revision, existing) do
    Process.sleep(config.refresh_delay_ms)
    displayed = Map.put(state, "currentAsset", digest)
    durable_state!(config.data_dir, displayed)
    ack_revision = if config.fault == "stale_ack", do: revision + 1, else: revision
    ack = acknowledgement(ack_revision, storage(existing), "displayed", digest, nil)
    response = exchange!(config, "POST", "/v0/outbox/ack", encode_json(ack))

    case response.status do
      200 ->
        %{
          outcome: "displayed",
          state: displayed,
          model: config.model,
          scenarioRefreshMs: config.scenario_refresh_ms
        }

      409 ->
        %{outcome: "ack_conflict", state: displayed}

      _ ->
        raise "acknowledgement failed: #{response.status} #{response.body}"
    end
  end

  defp acknowledge_failure!(config, state, revision, storage, refresh, code) do
    error = %{"type" => "urn:frameshift:problem:#{code}", "title" => code}
    ack = acknowledgement(revision, storage, refresh, state["currentAsset"], error)
    response = exchange!(config, "POST", "/v0/outbox/ack", encode_json(ack))

    if response.status != 200,
      do: raise("failure acknowledgement rejected: #{response.status} #{response.body}")

    %{outcome: code, state: state}
  end

  defp acknowledgement(revision, storage, refresh, current, error) do
    %{
      "manifestRevision" => revision,
      "storage" => storage,
      "refresh" => refresh,
      "currentAsset" => current,
      "lastError" => error
    }
  end

  defp storage(true), do: "unchanged"
  defp storage(false), do: "verified"

  defp verify_asset_response!(response, digest, fault, expected_bytes) do
    bytes = if fault == "corrupt_transfer", do: response.body <> <<0>>, else: response.body
    expected_header = "sha-256=:#{Base.encode64(:crypto.hash(:sha256, response.body))}:"

    unless byte_size(bytes) == expected_bytes and byte_size(bytes) <= @maximum_asset_bytes and
             response.headers["content-type"] == "application/vnd.frameshift.rgb24" and
             digest_bytes(bytes) == digest and
             response.headers["content-digest"] == expected_header do
      raise "asset digest mismatch"
    end
  end

  defp verified_asset?(data_dir, digest, expected_bytes) do
    case File.read(asset_path!(data_dir, digest)) do
      {:ok, bytes} -> byte_size(bytes) == expected_bytes and digest_bytes(bytes) == digest
      _ -> false
    end
  end

  defp asset_path!(data_dir, digest) do
    unless valid_digest?(digest), do: raise("invalid digest path")
    Path.join(data_dir, digest <> ".bin")
  end

  defp valid_digest?("sha256:" <> hex) when byte_size(hex) == 64 do
    String.match?(hex, ~r/\A[0-9a-f]{64}\z/)
  end

  defp valid_digest?(_), do: false

  defp digest_bytes(bytes),
    do: "sha256:" <> Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)

  defp durable_state!(data_dir, state) do
    durable_write!(Path.join(data_dir, "state.json"), encode_json(state))
  end

  defp durable_write!(path, contents) do
    temporary = path <> ".tmp"
    {:ok, file} = File.open(temporary, [:write, :binary, :exclusive])

    try do
      :ok = IO.binwrite(file, contents)
      :ok = :file.sync(file)
    after
      File.close(file)
    end

    File.rename!(temporary, path)
  end

  defp exchange!(config, method, path, body) do
    :ok = :ssl.start()

    options = [
      active: false,
      mode: :binary,
      certfile: String.to_charlist(config.certfile),
      keyfile: String.to_charlist(config.keyfile),
      verify: :verify_peer,
      cacerts: [],
      verify_fun: {&verify_server/3, %{expected: config.host_pin}},
      versions: [:"tlsv1.3"],
      server_name_indication: :disable,
      alpn_advertised_protocols: ["http/1.1"]
    ]

    {:ok, socket} = :ssl.connect(String.to_charlist(config.host), config.port, options, 5_000)

    try do
      verify_peer_pin!(socket, config.host_pin)
      request = request(method, path, body)
      :ok = :ssl.send(socket, request)

      read_response!(
        socket,
        if(path =~ "/assets/", do: @maximum_asset_bytes, else: @maximum_control_bytes)
      )
    after
      :ssl.close(socket)
    end
  end

  defp request(method, path, nil), do: "#{method} #{path} HTTP/1.1\r\nHost: frame-host\r\n\r\n"

  defp request(method, path, body) do
    bytes = IO.iodata_to_binary(body)

    "#{method} #{path} HTTP/1.1\r\nHost: frame-host\r\nContent-Type: application/json\r\n" <>
      "Content-Length: #{byte_size(bytes)}\r\n\r\n" <> bytes
  end

  defp read_response!(socket, body_limit) do
    wire = receive_to_close!(socket, [], 0, body_limit + @maximum_header_bytes)

    case :binary.split(wire, "\r\n\r\n") do
      [head, body]
      when byte_size(head) <= @maximum_header_bytes and byte_size(body) <= body_limit ->
        parse_response!(head, body)

      _ ->
        raise "invalid response framing"
    end
  end

  defp receive_to_close!(socket, chunks, size, limit) do
    case :ssl.recv(socket, 0, 5_000) do
      {:ok, bytes} when size + byte_size(bytes) <= limit ->
        receive_to_close!(socket, [bytes | chunks], size + byte_size(bytes), limit)

      {:error, :closed} ->
        chunks |> Enum.reverse() |> IO.iodata_to_binary()

      _ ->
        raise "response exceeded limit or timed out"
    end
  end

  defp parse_response!(head, body) do
    [status_line | header_lines] = String.split(head, "\r\n")
    ["HTTP/1.1", status, _reason] = String.split(status_line, " ", parts: 3)

    headers =
      Enum.reduce(header_lines, %{}, fn line, result ->
        [name, value] = String.split(line, ":", parts: 2)
        key = String.downcase(name)
        if Map.has_key?(result, key), do: raise("duplicate response header")
        Map.put(result, key, String.trim(value))
      end)

    if headers["content-length"] != Integer.to_string(byte_size(body)) do
      raise "response length mismatch"
    end

    %{status: String.to_integer(status), headers: headers, body: body}
  end

  defp verify_server(_, {:bad_cert, reason}, state)
       when reason in [:unknown_ca, :selfsigned_peer],
       do: {:valid, state}

  defp verify_server(_, {:bad_cert, reason}, _), do: {:fail, reason}
  defp verify_server(_, {:extension, _}, state), do: {:unknown, state}
  defp verify_server(_, :valid, state), do: {:valid, state}

  defp verify_server(certificate, :valid_peer, %{expected: expected} = state) do
    public_key_info =
      certificate
      |> otp_certificate(:tbsCertificate)
      |> otp_tbs_certificate(:subjectPublicKeyInfo)

    encoded = :public_key.pkix_encode(:OTPSubjectPublicKeyInfo, public_key_info, :otp)
    pin = "sha256:" <> Base.encode16(:crypto.hash(:sha256, encoded), case: :lower)
    if pin == expected, do: {:valid, state}, else: {:fail, :host_spki_mismatch}
  end

  defp verify_server(_, _, state), do: {:unknown, state}

  defp verify_peer_pin!(socket, expected) do
    {:ok, der} = :ssl.peercert(socket)
    certificate = :public_key.pkix_decode_cert(der, :otp)

    public_key_info =
      certificate
      |> otp_certificate(:tbsCertificate)
      |> otp_tbs_certificate(:subjectPublicKeyInfo)

    encoded = :public_key.pkix_encode(:OTPSubjectPublicKeyInfo, public_key_info, :otp)
    pin = "sha256:" <> Base.encode16(:crypto.hash(:sha256, encoded), case: :lower)
    if pin != expected, do: raise("host SPKI mismatch")
  end

  defp encode_json(value), do: value |> json_nulls() |> :json.encode() |> IO.iodata_to_binary()
  defp decode_json(bytes), do: bytes |> :json.decode() |> elixir_nulls()

  defp json_nulls(nil), do: :null

  defp json_nulls(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, json_nulls(value)} end)

  defp json_nulls(list) when is_list(list), do: Enum.map(list, &json_nulls/1)
  defp json_nulls(value), do: value

  defp elixir_nulls(:null), do: nil

  defp elixir_nulls(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, elixir_nulls(value)} end)

  defp elixir_nulls(list) when is_list(list), do: Enum.map(list, &elixir_nulls/1)
  defp elixir_nulls(value), do: value
end

FrameshiftContainerReceiver.main()
