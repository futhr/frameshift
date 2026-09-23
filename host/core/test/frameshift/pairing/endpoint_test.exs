defmodule Frameshift.Pairing.EndpointTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Pairing.{Endpoint, Window}
  alias Frameshift.Protocol.Schema

  @device_id "frame-000000000001"
  @secret :binary.copy(<<1, 2, 3, 4>>, 4)

  setup_all do
    key = {:rsa, 2048, 65_537}

    certificates =
      :public_key.pkix_test_data(%{
        server_chain: %{root: [key: key], intermediates: [], peer: [key: key]},
        client_chain: %{root: [key: key], intermediates: [], peer: [key: key]}
      })

    %{
      client_certificate: Keyword.fetch!(certificates.client_config, :cert),
      other_certificate: Keyword.fetch!(certificates.server_config, :cert)
    }
  end

  test "physical pairing commits identity before responding and replays idempotently", context do
    {:ok, initial} = Window.new(@device_id, @secret)
    {:ok, opened} = Window.open(initial, 100)
    request = request("pair-1", @secret)

    {response, paired} = Endpoint.handle(opened, context.client_certificate, request, 101)
    assert response.status == 201
    assert response.content_type == "application/json"
    assert paired.secret == nil

    document = Jason.decode!(response.body)
    assert :ok = Schema.validate("pairing-response", document)
    assert document["requestId"] == "pair-1"
    assert document["hostCertificateFingerprint"] == paired.host_certificate_fingerprint
    refute response.body =~ Base.url_encode64(@secret, padding: false)

    {replayed, ^paired} = Endpoint.handle(paired, context.client_certificate, request, 102)
    assert replayed.status == 200
    assert replayed.body == response.body

    {rejected, ^paired} = Endpoint.handle(paired, context.other_certificate, request, 103)
    assert rejected.status == 409
  end

  test "wrong secrets return one generic problem without revealing the failed factor", context do
    {:ok, initial} = Window.new(@device_id, @secret)
    {:ok, opened} = Window.open(initial, 100)

    {wrong_secret, next} =
      Endpoint.handle(opened, context.client_certificate, request("pair-1", <<0::128>>), 101)

    {wrong_certificate, _} = Endpoint.handle(next, <<1>>, request("pair-1", @secret), 102)

    assert wrong_secret.status == 403
    assert wrong_secret.body == wrong_certificate.body
    assert :ok = Schema.validate("problem", Jason.decode!(wrong_secret.body))
  end

  defp request(request_id, secret) do
    Jason.encode!(%{
      version: 1,
      requestId: request_id,
      deviceId: @device_id,
      secret: Base.url_encode64(secret, padding: false)
    })
  end
end
