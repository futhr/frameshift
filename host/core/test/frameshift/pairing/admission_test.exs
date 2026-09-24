defmodule Frameshift.Pairing.AdmissionTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Library
  alias Frameshift.Pairing.Admission

  @thing_source File.read!(
                  Path.expand(
                    "../../../../../protocol/fixtures/valid/thing-description.json",
                    __DIR__
                  )
                )
                |> String.replace("https://frame.invalid/", "https://frame.local/")
  @device_id "sim-photo-00000001"
  @pin "sha256:" <> String.duplicate("a", 64)
  @secret :binary.copy(<<17, 29, 43, 61>>, 4)
  @encoded_secret Base.url_encode64(@secret, padding: false)

  defmodule Resolver do
    @moduledoc false

    @spec resolve(term(), map()) :: {:ok, map()}
    def resolve(_, %{owner: owner}) do
      send(owner, :resolved_identity)
      {:ok, %{certificate: <<1, 2, 3>>, private_key: {:rsa, :test_key}}}
    end
  end

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "frameshift-pair-admission-#{System.unique_integer([:positive, :monotonic])}"
      )

    {:ok, library} = Library.start_link(data_dir: root, name: nil)
    on_exit(fn -> File.rm_rf!(root) end)
    %{library: library, root: root}
  end

  test "admits only the authenticated TD and never stores the bootstrap secret", context do
    owner = self()

    pairer = fn bootstrap, credential, request_id ->
      send(owner, {:paired, bootstrap.device_id, credential.server_spki_sha256, request_id})
      {:ok, %{device_id: bootstrap.device_id}}
    end

    assert {:ok, %{"frameId" => @device_id}} =
             Admission.pair(
               bootstrap(),
               @device_id,
               "https://frame.local",
               "keychain:admission-test",
               "pair-request-1",
               options(context, pairer, fn _, _ -> {:ok, @thing_source} end)
             )

    assert_receive :resolved_identity
    assert_receive {:paired, @device_id, _pin, "pair-request-1"}
    assert {:ok, frame} = Library.get_paired_frame(context.library, @device_id)
    assert frame["credential_ref"] == "keychain:admission-test"

    assert {:error, :pairing_preflight_failed} =
             Admission.pair(
               bootstrap(),
               @device_id,
               "https://frame.local",
               "keychain:admission-test",
               "pair-request-repeat",
               options(context, fn _, _, _ -> flunk("re-paired a registered frame") end, fn _,
                                                                                            _ ->
                 flunk("re-fetched TD")
               end)
             )

    refute_receive :resolved_identity

    for path <- Path.wildcard(Path.join(context.root, "**/*")), File.regular?(path) do
      assert :binary.match(File.read!(path), @encoded_secret) == :nomatch
    end
  end

  test "rejects a discovery mismatch before resolving an identity", context do
    assert {:error, :pairing_preflight_failed} =
             Admission.pair(
               bootstrap(),
               "other-frame-00001",
               "https://frame.local",
               "keychain:admission-test",
               "pair-request-2",
               options(context, fn _, _, _ -> flunk("pair sent") end, fn _, _ ->
                 flunk("TD fetched")
               end)
             )

    refute_receive :resolved_identity
    assert Library.list_paired_frames(context.library) == []
  end

  test "an uncertain pair exchange and a mismatched TD leave no paired frame", context do
    uncertain = fn _, _, _ -> {:error, :pairing_transport_failure} end
    fetcher = fn _, _ -> flunk("TD fetched after uncertain pair") end

    assert {:error, :pairing_outcome_unknown} =
             Admission.pair(
               bootstrap(),
               @device_id,
               "https://frame.local",
               "keychain:admission-test",
               "pair-request-3",
               options(context, uncertain, fetcher)
             )

    mismatched_td = String.replace(@thing_source, @device_id, "other-frame-00001")

    assert {:error, :pairing_incomplete} =
             Admission.pair(
               bootstrap(),
               @device_id,
               "https://frame.local",
               "keychain:admission-test",
               "pair-request-4",
               options(
                 context,
                 fn bootstrap, _, _ -> {:ok, %{device_id: bootstrap.device_id}} end,
                 fn _, _ ->
                   {:ok, mismatched_td}
                 end
               )
             )

    other_origin = String.replace(@thing_source, "https://frame.local/", "https://other.local/")

    assert {:error, :pairing_incomplete} =
             Admission.pair(
               bootstrap(),
               @device_id,
               "https://frame.local",
               "keychain:admission-test",
               "pair-request-5",
               options(
                 context,
                 fn bootstrap, _, _ -> {:ok, %{device_id: bootstrap.device_id}} end,
                 fn _, _ ->
                   {:ok, other_origin}
                 end
               )
             )

    assert Library.list_paired_frames(context.library) == []
  end

  test "recovery fetches only the pinned authenticated TD and refuses a mismatched QR", context do
    owner = self()

    fetcher = fn credential, path ->
      send(owner, {:read_only_recovery, credential.server_spki_sha256, path})
      {:ok, @thing_source}
    end

    assert {:error, :pairing_preflight_failed} =
             Admission.recover(
               bootstrap(),
               "other-frame-00001",
               "https://frame.local",
               "keychain:admission-test",
               options(context, fn _, _, _ -> flunk("pair POST replayed") end, fetcher)
             )

    refute_receive :resolved_identity

    assert {:ok, %{"frameId" => @device_id}} =
             Admission.recover(
               bootstrap(),
               @device_id,
               "https://frame.local",
               "keychain:admission-test",
               options(context, fn _, _, _ -> flunk("pair POST replayed") end, fetcher)
             )

    assert_receive :resolved_identity
    assert_receive {:read_only_recovery, pin, "/.well-known/wot"}
    assert "sha256:" <> Base.encode16(pin, case: :lower) == @pin
    assert {:ok, _} = Library.get_paired_frame(context.library, @device_id)
  end

  defp bootstrap do
    Jason.encode!(%{
      "version" => 1,
      "deviceId" => @device_id,
      "serverSpki" => @pin,
      "secret" => @encoded_secret
    })
  end

  defp options(context, pairer, fetcher) do
    [
      library: context.library,
      resolver: {Resolver, %{owner: self()}},
      pairer: pairer,
      fetcher: fetcher
    ]
  end
end
