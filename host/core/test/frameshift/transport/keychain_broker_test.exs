defmodule Frameshift.Transport.KeychainBrokerTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Frameshift.Transport.KeychainBroker

  test "resolve returns a public certificate and a three-argument OTP signer" do
    owner = self()

    transport = fn path, request ->
      send(owner, {:broker_request, path, request})

      case request["operation"] do
        "resolve" ->
          {:ok,
           %{"ok" => true, "certificate" => Base.encode64(<<1, 2, 3>>), "algorithm" => "ecdsa"}}

        "sign" ->
          {:ok, %{"ok" => true, "signature" => Base.encode64(<<4, 5, 6>>)}}
      end
    end

    config = %{
      socket_path: "/private/test.sock",
      token: String.duplicate("a", 64),
      transport: transport
    }

    assert {:ok, %{certificate: <<1, 2, 3>>, private_key: key}} =
             KeychainBroker.resolve("keychain:identity", config)

    assert key.algorithm == :ecdsa

    assert_receive {:broker_request, "/private/test.sock",
                    %{
                      "operation" => "resolve",
                      "reference" => "keychain:identity"
                    }}

    assert :public_key.sign("tls-handshake", :sha256, key) == <<4, 5, 6>>

    assert_receive {:broker_request, "/private/test.sock",
                    %{
                      "operation" => "sign",
                      "scheme" => "ecdsa-sha256",
                      "digest" => digest
                    }}

    assert Base.decode64!(digest) == :crypto.hash(:sha256, "tls-handshake")
  end

  test "RSA-PSS requests preserve OTP's digest-sized salt policy" do
    owner = self()

    transport = fn _, request ->
      send(owner, {:broker_request, request})

      case request["operation"] do
        "resolve" ->
          {:ok, %{"ok" => true, "certificate" => Base.encode64(<<1>>), "algorithm" => "rsa"}}

        "sign" ->
          {:ok, %{"ok" => true, "signature" => Base.encode64(<<2>>)}}
      end
    end

    config = %{
      socket_path: "/private/test.sock",
      token: String.duplicate("b", 64),
      transport: transport
    }

    assert {:ok, %{private_key: key}} = KeychainBroker.resolve("keychain:rsa", config)
    assert_receive {:broker_request, %{"operation" => "resolve"}}

    digest = :crypto.hash(:sha256, "handshake")

    assert key.sign_fun.({:digest, digest}, :sha256,
             rsa_padding: :rsa_pkcs1_pss_padding,
             rsa_pss_saltlen: 32
           ) == <<2>>

    assert_receive {:broker_request, %{"operation" => "sign", "scheme" => "rsa-pss-sha256"}}

    assert_raise RuntimeError, "Keychain signing failed", fn ->
      key.sign_fun.({:digest, digest}, :sha256,
        rsa_padding: :rsa_pkcs1_pss_padding,
        rsa_pss_saltlen: 20
      )
    end

    refute_receive {:broker_request, %{"operation" => "sign"}}
  end

  test "the default broker transport authenticates and bounds one local socket exchange" do
    path = "/tmp/frameshift-broker-#{System.unique_integer([:positive, :monotonic])}.sock"
    on_exit(fn -> File.rm(path) end)

    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, packet: 4, active: false, ifaddr: {:local, path}])

    on_exit(fn -> :gen_tcp.close(listener) end)

    server =
      Task.async(fn ->
        {:ok, socket} = :gen_tcp.accept(listener)
        {:ok, wire} = :gen_tcp.recv(socket, 0, 5_000)
        request = Jason.decode!(wire)

        :ok =
          :gen_tcp.send(
            socket,
            RFC8785.encode!(%{
              "ok" => true,
              "certificate" => Base.encode64(<<1, 2, 3>>),
              "algorithm" => "ecdsa"
            })
          )

        :gen_tcp.close(socket)
        request
      end)

    token = String.duplicate("c", 64)

    assert {:ok, %{certificate: <<1, 2, 3>>}} =
             KeychainBroker.resolve("keychain:live-socket", %{socket_path: path, token: token})

    assert %{
             "operation" => "resolve",
             "reference" => "keychain:live-socket",
             "auth" => ^token
           } = Task.await(server)
  end

  test "malformed broker responses and identities fail closed" do
    transport = fn _, _ ->
      {:ok, %{"ok" => true, "certificate" => "!", "algorithm" => "ecdsa"}}
    end

    config = %{socket_path: "/unused", token: "secret", transport: transport}

    assert {:error, :credential_broker_contract_violation} =
             KeychainBroker.resolve("keychain:bad-cert", config)

    assert {:error, :credential_broker_unavailable} = KeychainBroker.resolve("", config)

    denied = fn _, _ -> {:ok, %{"ok" => false}} end

    assert {:error, :credential_broker_failure} =
             KeychainBroker.resolve("keychain:denied", %{config | transport: denied})

    assert {:error, :credential_broker_unavailable} =
             KeychainBroker.resolve("keychain:missing", %{
               socket_path: "/missing.sock",
               token: "x"
             })
  end

  test "signing rejects unsupported digests, malformed signatures, and oversized input" do
    owner = self()

    transport = fn _, request ->
      send(owner, request)

      case request["operation"] do
        "resolve" ->
          {:ok, %{"ok" => true, "certificate" => Base.encode64(<<1>>), "algorithm" => "rsa"}}

        "sign" ->
          {:ok, %{"ok" => true, "signature" => "!"}}
      end
    end

    config = %{socket_path: "/unused", token: "secret", transport: transport}
    assert {:ok, %{private_key: key}} = KeychainBroker.resolve("keychain:rsa", config)
    assert_receive %{"operation" => "resolve"}

    for {message, digest, options} <- [
          {"message", :sha1, []},
          {:binary.copy("x", 65_537), :sha256, []},
          {{:digest, <<1>>}, :sha256, []},
          {"message", :sha256, rsa_padding: :unsupported}
        ] do
      assert_raise RuntimeError, "Keychain signing failed", fn ->
        key.sign_fun.(message, digest, options)
      end
    end

    refute_receive %{"operation" => "sign"}

    assert_raise RuntimeError, "Keychain signing failed", fn ->
      key.sign_fun.("message", :sha384, rsa_padding: :rsa_pkcs1_padding)
    end

    assert_receive %{"operation" => "sign", "scheme" => "rsa-pkcs1-sha384"}
  end

  test "credential broker rejects invalid contracts and propagates transport failure" do
    config = %{socket_path: "/unused", token: "secret"}

    for response <- [
          %{"ok" => true, "certificate" => Base.encode64(<<1>>), "algorithm" => "unknown"},
          %{"ok" => true, "certificate" => "", "algorithm" => "ecdsa"},
          %{
            "ok" => true,
            "certificate" => Base.encode64(:binary.copy(<<1>>, 65_537)),
            "algorithm" => "rsa"
          },
          %{"ok" => true, "algorithm" => "rsa"},
          %{"ok" => "true"}
        ] do
      transport = fn _, _ -> {:ok, response} end

      assert {:error, :credential_broker_contract_violation} =
               KeychainBroker.resolve("keychain:invalid", Map.put(config, :transport, transport))
    end

    transport = fn _, _ -> {:error, :econnreset} end

    assert {:error, :econnreset} =
             KeychainBroker.resolve(
               "keychain:unavailable",
               Map.put(config, :transport, transport)
             )
  end
end
