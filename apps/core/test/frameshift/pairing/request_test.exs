defmodule Frameshift.Pairing.RequestTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Pairing.{Request, Window}

  @device_id "frame-000000000001"
  @secret :binary.copy(<<1, 2, 3, 4>>, 4)

  test "bounded request keeps the secret out of inspection and authenticates through TLS peer state" do
    source =
      Jason.encode!(%{
        version: 1,
        requestId: "pair-1",
        deviceId: @device_id,
        secret: Base.url_encode64(@secret, padding: false)
      })

    assert {:ok, request} = Request.parse(source)
    assert request.secret == @secret
    refute inspect(request) =~ Base.url_encode64(@secret, padding: false)

    assert {:ok, window} = Window.new(@device_id, @secret)
    assert {:error, :pair_mode_required, ^window} = Request.authorize(window, request, <<1>>, 0)
  end

  test "ambiguous fields and a JSON-supplied certificate are rejected" do
    secret = Base.url_encode64(@secret, padding: false)

    assert {:error, :invalid_pairing_request} =
             Request.parse(
               ~s({"version":1,"requestId":"pair-1","requestId":"pair-2","deviceId":"#{@device_id}","secret":"#{secret}"})
             )

    assert {:error, :invalid_pairing_request} =
             Request.parse(
               Jason.encode!(%{
                 version: 1,
                 requestId: "pair-1",
                 deviceId: @device_id,
                 secret: secret,
                 hostCertificate: "untrusted"
               })
             )

    assert {:error, :invalid_pairing_request} = Request.parse(:binary.copy("x", 2_049))
  end
end
