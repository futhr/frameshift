defmodule Frameshift.Transport.MTLSCredentialTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Transport.MTLSCredential

  @pin "sha256:" <> String.duplicate("a", 64)

  test "accepts an OTP-compatible non-exportable signer without exposing it in inspection" do
    owner = self()

    signer = fn message, digest, options ->
      send(owner, {:sign_called, message, digest, options})
      <<1, 2, 3>>
    end

    key = %{algorithm: :rsa, sign_fun: signer}

    assert {:ok, credential} =
             MTLSCredential.new("https://frame.local", @pin, <<4, 5, 6>>, key)

    assert credential.client_private_key.algorithm == :rsa
    assert is_function(credential.client_private_key.sign_fun, 3)

    assert :public_key.sign("handshake", :sha256, key) == <<1, 2, 3>>
    assert_receive {:sign_called, "handshake", :sha256, []}

    assert credential.server_spki_sha256 ==
             Base.decode16!(String.duplicate("a", 64), case: :lower)

    refute inspect(credential) =~ inspect(key)
    refute inspect(credential) =~ inspect(<<4, 5, 6>>)

    assert {:error, :invalid_client_private_key} =
             MTLSCredential.new("https://frame.local", @pin, <<4, 5, 6>>, %{
               algorithm: :rsa,
               sign_fun: fn _ -> <<1>> end
             })
  end
end
