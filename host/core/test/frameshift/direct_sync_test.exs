defmodule Frameshift.DirectSyncTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Digest
  alias Frameshift.DirectSync
  alias Frameshift.DirectSync.Artifact
  alias Frameshift.Protocol.Thing
  alias Wotex.Binding.HTTP
  alias Wotex.Binding.HTTP.{Headers, Request, Response}
  alias Wotex.Runtime.Context

  @fixture Path.expand("../../../../protocol/fixtures/valid/thing-description.json", __DIR__)
  @media_type "application/vnd.frameshift.rgb24"
  @profile_id "urn:frameshift:profile:sim-rgb24-v1"
  @control_bytes 64 * 1024

  defmodule ScriptedClient do
    @moduledoc false

    @behaviour Wotex.Binding.HTTP.Client

    @impl true
    def request(request, credential, %{agent: agent, credential: expected, owner: owner}) do
      send(owner, {:direct_sync_request, request, credential == expected})

      Agent.get_and_update(agent, fn
        [response | rest] -> {response, rest}
        [] -> {{:error, :unexpected_request}, []}
      end)
    end

    @impl true
    def subscribe(_, _, _, _),
      do: {:error, :streaming_not_available}

    @impl true
    def close(_, _), do: :ok
  end

  setup do
    bytes = <<1, 3, 5, 7, 9, 11>>
    digest = Digest.sha256(bytes)
    {:ok, artifact} = Artifact.new(bytes, digest, @profile_id, @media_type)
    %{artifact: artifact}
  end

  test "follows arbitrary advertised Forms and reconciles physical display state", context do
    variants = [
      %{state: "observed/state", install: "blobs/{digest}", desired: "commands/display"},
      %{state: "status/current", install: "objects/{digest}/content", desired: "intent/still"}
    ]

    Enum.with_index(variants, 1)
    |> Enum.each(fn {paths, index} ->
      td = frame_td(paths)
      request_id = "direct-request-#{index}"

      config =
        scripted_config([
          state_response(empty_state(), ~s("state-0")),
          response(201),
          json_response(202, pending_state(context.artifact, request_id)),
          state_response(displayed_state(context.artifact), ~s("state-2"))
        ])

      assert {:ok, result} =
               DirectSync.sync(
                 td,
                 context.artifact,
                 :ephemeral_credential,
                 config,
                 context(request_id)
               )

      assert result.outcome == :displayed
      assert result.installation == :created
      assert result.state["currentAsset"] == context.artifact.digest

      requests = receive_requests(4)
      assert Enum.all?(requests, fn {_, credential_ok?} -> credential_ok? end)

      [{initial, _}, {install, _}, {desired, _}, {reconciled, _}] = requests
      base = "https://frame.local/root/"
      expected_state_uri = base |> URI.merge(paths.state) |> URI.to_string()
      expected_desired_uri = base |> URI.merge(paths.desired) |> URI.to_string()

      assert Request.method(initial) == "GET"
      assert Request.uri(initial) == expected_state_uri
      assert Request.uri(reconciled) == Request.uri(initial)

      assert Request.method(install) == "PUT"

      assert Request.uri(install) ==
               base
               |> URI.merge(
                 String.replace(paths.install, "{digest}", Digest.hex!(context.artifact.digest))
               )
               |> URI.to_string()

      assert Request.body(install) == context.artifact.bytes
      assert Headers.get(Request.headers(install), "content-type") == @media_type
      assert Headers.get(Request.headers(install), "frameshift-artifact-profile") == @profile_id
      assert Headers.get(Request.headers(install), "if-none-match") == "*"

      expected_content_digest =
        :sha256
        |> :crypto.hash(context.artifact.bytes)
        |> Base.encode64()
        |> then(&"sha-256=:#{&1}:")

      assert Headers.get(Request.headers(install), "content-digest") ==
               expected_content_digest

      assert Request.method(desired) == "PUT"
      assert Request.uri(desired) == expected_desired_uri
      assert Headers.get(Request.headers(desired), "if-none-match") == "*"

      assert {:ok,
              %{
                "assetDigest" => digest,
                "artifactProfile" => @profile_id,
                "requestId" => ^request_id
              }} = RFC8785.decode(Request.body(desired))

      assert digest == context.artifact.digest
    end)
  end

  test "does no mutation when the exact artifact is already displayed", context do
    config =
      scripted_config([
        state_response(displayed_state(context.artifact), ~s("state-8"))
      ])

    assert {:ok, result} =
             DirectSync.sync(
               frame_td(),
               context.artifact,
               :ephemeral_credential,
               config,
               context("already-current")
             )

    assert result.outcome == :displayed
    assert result.installation == :not_required
    assert [{request, true}] = receive_requests(1)
    assert Request.method(request) == "GET"
    refute_receive {:direct_sync_request, _, _}
  end

  test "read-only observation confirms display without mutating the frame", context do
    config = scripted_config([state_response(displayed_state(context.artifact), ~s("state-9"))])

    assert {:ok, :displayed} =
             DirectSync.observe(
               frame_td(),
               context.artifact.digest,
               "original-request",
               :ephemeral_credential,
               config,
               context("original-request")
             )

    assert [{request, true}] = receive_requests(1)
    assert Request.method(request) == "GET"
    refute_receive {:direct_sync_request, _, _}
  end

  test "read-only observation never adopts another request's pending state", context do
    config =
      scripted_config([
        state_response(pending_state(context.artifact, "another-request"), ~s("state-10"))
      ])

    assert {:ok, :not_applied} =
             DirectSync.observe(
               frame_td(),
               context.artifact.digest,
               "original-request",
               :ephemeral_credential,
               config,
               context("original-request")
             )

    assert [{request, true}] = receive_requests(1)
    assert Request.method(request) == "GET"
  end

  test "returns pending without replaying an accepted desired request", context do
    config =
      scripted_config([
        state_response(pending_state(context.artifact, "earlier-request"), ~s("state-4"))
      ])

    assert {:ok, %{outcome: :pending, installation: :not_required}} =
             DirectSync.sync(
               frame_td(),
               context.artifact,
               :ephemeral_credential,
               config,
               context("new-request")
             )

    assert [_] = receive_requests(1)
    refute_receive {:direct_sync_request, _, _}
  end

  test "retries an immutable conditional upload once after a timeout", context do
    request_id = "upload-retry"

    config =
      scripted_config([
        state_response(empty_state(), ~s("state-0")),
        {:error, :timeout},
        response(204),
        json_response(202, pending_state(context.artifact, request_id)),
        state_response(pending_state(context.artifact, request_id), ~s("state-1"))
      ])

    assert {:ok, %{outcome: :pending, installation: :present}} =
             DirectSync.sync(
               frame_td(),
               context.artifact,
               :ephemeral_credential,
               config,
               context(request_id)
             )

    [_, {first, true}, {second, true}, _, _] = receive_requests(5)
    assert Request.method(first) == "PUT"
    assert Request.uri(first) == Request.uri(second)
    assert Request.body(first) == Request.body(second)
    assert Request.headers(first) == Request.headers(second)
  end

  test "re-reads state before retrying an uncertain desired mutation", context do
    request_id = "desired-retry"

    config =
      scripted_config([
        state_response(empty_state(), ~s("state-0")),
        response(201),
        {:error, :timeout},
        state_response(empty_state(), ~s("state-0")),
        json_response(202, pending_state(context.artifact, request_id)),
        state_response(displayed_state(context.artifact), ~s("state-2"))
      ])

    assert {:ok, %{outcome: :displayed}} =
             DirectSync.sync(
               frame_td(),
               context.artifact,
               :ephemeral_credential,
               config,
               context(request_id)
             )

    [_, _, {first, true}, _, {second, true}, _] =
      receive_requests(6)

    assert Request.method(first) == "PUT"
    assert Request.uri(first) == Request.uri(second)
    assert Request.body(first) == Request.body(second)
    assert Headers.get(Request.headers(first), "if-none-match") == "*"
  end

  test "maps a bounded frame problem without leaking its detail", context do
    problem = %{
      "type" => "urn:frameshift:problem:storage-full",
      "title" => "No inactive slot is available",
      "status" => 507,
      "detail" => "private adapter detail"
    }

    config =
      scripted_config([
        state_response(empty_state(), ~s("state-0")),
        problem_response(507, problem)
      ])

    assert {:error, :storage_full} =
             DirectSync.sync(
               frame_td(),
               context.artifact,
               :ephemeral_credential,
               config,
               context("storage-problem")
             )

    assert [_, _] = receive_requests(2)
    refute_receive {:direct_sync_request, _, _}
  end

  test "rejects incompatible transfer capabilities and forged artifact structs", context do
    document = frame_document()
    pull_only = put_in(document, ["frameshift:capabilities", "transferModes"], ["pull"])
    {:ok, pull_td} = pull_only |> RFC8785.encode!() |> Thing.parse_frame()
    config = scripted_config([])

    assert {:error, :compatible_binding_unavailable} =
             DirectSync.sync(
               pull_td,
               context.artifact,
               :ephemeral_credential,
               config,
               context("pull-only")
             )

    forged = %{context.artifact | bytes: "different", byte_count: 9}

    assert {:error, :invalid_artifact} =
             DirectSync.sync(
               frame_td(),
               forged,
               :ephemeral_credential,
               config,
               context("forged")
             )

    refute_receive {:direct_sync_request, _, _}
  end

  test "artifact inspection omits artwork bytes", context do
    inspected = inspect(context.artifact)
    assert inspected =~ context.artifact.digest
    refute inspected =~ inspect(context.artifact.bytes)
    assert {:error, :invalid_artifact} = Artifact.new("bytes", Digest.sha256("other"), "p", "m")
  end

  defp scripted_config(responses) do
    {:ok, agent} = Agent.start_link(fn -> responses end)

    on_exit(fn ->
      if Process.alive?(agent) do
        try do
          Agent.stop(agent)
        catch
          :exit, _ -> :ok
        end
      end
    end)

    {:ok, config} =
      HTTP.config(
        client:
          {ScriptedClient, %{agent: agent, credential: :ephemeral_credential, owner: self()}},
        max_request_bytes: @control_bytes,
        max_response_bytes: @control_bytes,
        max_event_bytes: @control_bytes,
        max_header_count: 64,
        max_header_bytes: 64 * 8 * 1024,
        max_uri_bytes: 1_024
      )

    config
  end

  defp context(request_id) do
    Context.new!(
      request_id: request_id,
      deadline: System.monotonic_time(:millisecond) + 5_000
    )
  end

  defp frame_td(paths \\ %{state: "state", install: "assets/{digest}", desired: "desired"}) do
    document = frame_document()

    customized =
      document
      |> Map.put("base", "https://frame.local/root/")
      |> put_in(["properties", "state", "forms"], [
        %{
          "href" => paths.state,
          "contentType" => "application/json",
          "op" => "readproperty"
        }
      ])
      |> put_in(["actions", "installAsset", "forms"], [
        %{
          "href" => paths.install,
          "contentType" => @media_type,
          "op" => "invokeaction",
          "htv:methodName" => "PUT",
          "frameshift:artifactProfile" => @profile_id
        }
      ])
      |> put_in(["actions", "setDesired", "forms"], [
        %{
          "href" => paths.desired,
          "contentType" => "application/json",
          "op" => "invokeaction",
          "htv:methodName" => "PUT"
        }
      ])

    {:ok, td} = customized |> RFC8785.encode!() |> Thing.parse_frame()
    td
  end

  defp frame_document do
    {:ok, document} = @fixture |> File.read!() |> RFC8785.decode()
    document
  end

  defp empty_state do
    %{
      "stateRevision" => 0,
      "displayState" => "empty",
      "desiredAsset" => nil,
      "currentAsset" => nil,
      "previousKnownGood" => nil,
      "pendingRequestId" => nil,
      "lastError" => nil
    }
  end

  defp pending_state(artifact, request_id) do
    %{
      "stateRevision" => 1,
      "displayState" => "refreshing",
      "desiredAsset" => artifact.digest,
      "currentAsset" => nil,
      "previousKnownGood" => nil,
      "pendingRequestId" => request_id,
      "lastError" => nil
    }
  end

  defp displayed_state(artifact) do
    %{
      "stateRevision" => 2,
      "displayState" => "displayed",
      "desiredAsset" => artifact.digest,
      "currentAsset" => artifact.digest,
      "previousKnownGood" => nil,
      "pendingRequestId" => nil,
      "lastError" => nil
    }
  end

  defp state_response(state, etag) do
    json_response(200, state, [{"etag", etag}])
  end

  defp json_response(status, document, extra_headers \\ []) do
    body = RFC8785.encode!(document)

    response(
      status,
      [
        {"content-type", "application/json"},
        {"content-length", Integer.to_string(byte_size(body))}
      ] ++
        extra_headers,
      body
    )
  end

  defp problem_response(status, document) do
    body = RFC8785.encode!(document)

    response(
      status,
      [
        {"content-type", "application/problem+json"},
        {"content-length", Integer.to_string(byte_size(body))}
      ],
      body
    )
  end

  defp response(status, headers \\ [], body \\ "") do
    {:ok, response} = Response.new(status, headers, body)
    {:ok, response}
  end

  defp receive_requests(count) do
    Enum.map(1..count, fn _ ->
      assert_receive {:direct_sync_request, request, credential_ok?}
      {request, credential_ok?}
    end)
  end
end
