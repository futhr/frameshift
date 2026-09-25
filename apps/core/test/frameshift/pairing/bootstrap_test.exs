defmodule Frameshift.Pairing.BootstrapTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Pairing.Bootstrap
  alias Frameshift.Transport.SPKIPin

  @device_id "frame-000000000001"
  @spki "sha256:" <> String.duplicate("a", 64)
  @secret :binary.copy(<<1, 2, 3, 4>>, 4)

  test "accepts a canonical physical record but never inspects its secret" do
    source =
      Jason.encode!(%{
        version: 1,
        deviceId: @device_id,
        serverSpki: @spki,
        secret: Base.url_encode64(@secret, padding: false)
      })

    assert {:ok, bootstrap} = Bootstrap.parse(source)
    assert bootstrap.device_id == @device_id
    assert bootstrap.server_spki == @spki
    assert bootstrap.secret == @secret
    refute inspect(bootstrap) =~ "secret"
    refute inspect(bootstrap) =~ Base.url_encode64(@secret, padding: false)
  end

  test "rejects duplicate fields, extra routing hints, and weak secrets" do
    valid_secret = Base.url_encode64(@secret, padding: false)

    assert {:error, :invalid_bootstrap_record} =
             Bootstrap.parse(
               ~s({"version":1,"deviceId":"#{@device_id}","deviceId":"#{@device_id}","serverSpki":"#{@spki}","secret":"#{valid_secret}"})
             )

    assert {:error, :invalid_bootstrap_record} =
             Bootstrap.parse(
               Jason.encode!(%{
                 version: 1,
                 deviceId: @device_id,
                 serverSpki: @spki,
                 secret: valid_secret,
                 url: "https://untrusted.local/pair"
               })
             )

    assert {:error, :invalid_bootstrap_record} =
             Bootstrap.parse(
               Jason.encode!(%{
                 version: 1,
                 deviceId: @device_id,
                 serverSpki: @spki,
                 secret: Base.url_encode64(<<1, 2, 3>>, padding: false)
               })
             )
  end

  test "pins the discovered TLS peer and post-pairing TD to the physical record" do
    key = {:rsa, 2048, 65_537}

    certificates =
      :public_key.pkix_test_data(%{
        server_chain: %{root: [key: key], intermediates: [], peer: [key: key]},
        client_chain: %{root: [key: key], intermediates: [], peer: [key: key]}
      })

    certificate = Keyword.fetch!(certificates.server_config, :cert)
    other_certificate = Keyword.fetch!(certificates.client_config, :cert)
    assert {:ok, pin} = SPKIPin.fingerprint_der(certificate)

    record =
      Jason.encode!(%{
        version: 1,
        deviceId: "sim-photo-00000001",
        serverSpki: pin,
        secret: Base.url_encode64(@secret, padding: false)
      })

    assert {:ok, bootstrap} = Bootstrap.parse(record)
    assert :ok = Bootstrap.verify_peer(bootstrap, certificate)
    assert {:error, :peer_identity_mismatch} = Bootstrap.verify_peer(bootstrap, other_certificate)
    assert {:error, :peer_identity_mismatch} = Bootstrap.verify_peer(bootstrap, <<1, 2, 3>>)

    td_path =
      Path.expand("../../../../../protocol/fixtures/valid/thing-description.json", __DIR__)

    td_source = File.read!(td_path)
    assert :ok = Bootstrap.verify_thing_description(bootstrap, td_source)

    wrong_device = %{bootstrap | device_id: "frame-000000000002"}

    assert {:error, :device_identity_mismatch} =
             Bootstrap.verify_thing_description(wrong_device, td_source)
  end
end
