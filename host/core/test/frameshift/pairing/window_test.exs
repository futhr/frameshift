defmodule Frameshift.Pairing.WindowTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Frameshift.Pairing.Window

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

  test "only a physical-open window admits a TLS-authenticated peer and consumes the secret",
       context do
    assert {:ok, initial} = Window.new(@device_id, @secret)

    assert {:error, :pair_mode_required, ^initial} =
             Window.authorize(
               initial,
               "pair-1",
               @device_id,
               @secret,
               context.client_certificate,
               1_000
             )

    assert {:ok, opened} = Window.open(initial, 1_000)

    assert {:ok, paired} =
             Window.authorize(
               opened,
               "pair-1",
               @device_id,
               @secret,
               context.client_certificate,
               2_000
             )

    assert paired.secret == nil
    assert paired.opened_at_ms == nil

    assert paired.host_certificate_fingerprint ==
             "sha256:" <>
               Base.encode16(:crypto.hash(:sha256, context.client_certificate), case: :lower)

    refute inspect(opened) =~ Base.encode64(@secret)
    assert {:error, :already_paired} = Window.open(paired, 3_000)

    assert {:ok, ^paired} =
             Window.authorize(
               paired,
               "pair-1",
               @device_id,
               @secret,
               context.client_certificate,
               3_000
             )

    assert {:error, :already_paired, ^paired} =
             Window.authorize(
               paired,
               "pair-2",
               @device_id,
               @secret,
               context.client_certificate,
               3_000
             )

    assert {:error, :already_paired, ^paired} =
             Window.authorize(
               paired,
               "pair-1",
               @device_id,
               @secret,
               context.other_certificate,
               3_000
             )
  end

  test "wrong device, secret, or certificate consumes attempts and locks the window", context do
    assert {:ok, initial} = Window.new(@device_id, @secret)
    assert {:ok, opened} = Window.open(initial, 10)

    assert {:error, :pairing_rejected, state1} =
             Window.authorize(
               opened,
               "pair-1",
               "another-device-id",
               @secret,
               context.client_certificate,
               11
             )

    assert {:error, :pairing_rejected, state2} =
             Window.authorize(
               state1,
               "pair-1",
               @device_id,
               <<0::128>>,
               context.client_certificate,
               12
             )

    assert {:error, :pairing_rejected, state3} =
             Window.authorize(state2, "pair-1", @device_id, @secret, <<1, 2>>, 13)

    assert {:error, :pairing_rejected, state4} =
             Window.authorize(state3, "pair-1", @device_id, @secret, <<1, 2>>, 14)

    assert {:error, :pairing_locked, locked} =
             Window.authorize(state4, "pair-1", @device_id, @secret, <<1, 2>>, 15)

    assert locked.opened_at_ms == nil

    assert {:error, :pair_mode_required, _} =
             Window.authorize(
               locked,
               "pair-1",
               @device_id,
               @secret,
               context.client_certificate,
               16
             )

    assert {:ok, reopened} = Window.open(locked, 17)
    assert reopened.attempts == 0
  end

  test "the physical window expires at exactly five minutes", context do
    assert {:ok, initial} = Window.new(@device_id, @secret)
    assert {:ok, opened} = Window.open(initial, 100)

    assert {:error, :pair_mode_required, expired} =
             Window.authorize(
               opened,
               "pair-1",
               @device_id,
               @secret,
               context.client_certificate,
               300_100
             )

    assert expired.opened_at_ms == nil
    assert {:ok, _reopened} = Window.open(expired, 300_101)
  end

  test "invalid input and clocks do not authorize a host", context do
    assert {:error, :invalid_pairing_state} = Window.new("short", @secret)
    assert {:error, :invalid_pairing_state} = Window.new(@device_id, <<1>>)
    assert {:ok, initial} = Window.new(@device_id, @secret)
    assert {:error, :invalid_time} = Window.open(initial, -1)
    assert {:ok, opened} = Window.open(initial, 100)

    assert {:error, :invalid_time, ^opened} =
             Window.authorize(
               opened,
               "pair-1",
               @device_id,
               @secret,
               context.client_certificate,
               -1
             )

    assert {:error, :invalid_pairing_request, ^opened} =
             Window.authorize(
               opened,
               "bad id",
               @device_id,
               @secret,
               context.client_certificate,
               101
             )

    assert {:error, :pair_mode_required, _closed} =
             Window.authorize(
               opened,
               "pair-1",
               @device_id,
               @secret,
               context.client_certificate,
               99
             )

    exhausted = %{opened | attempts: 5}

    assert {:error, :pairing_locked, locked} =
             Window.authorize(
               exhausted,
               "pair-1",
               @device_id,
               @secret,
               context.client_certificate,
               101
             )

    assert locked.opened_at_ms == nil
  end

  property "an incorrect 128-bit secret never authorizes a host", context do
    check all(candidate <- binary(length: 16), max_runs: 50) do
      wrong = if candidate == @secret, do: <<0::128>>, else: candidate
      {:ok, initial} = Window.new(@device_id, @secret)
      {:ok, opened} = Window.open(initial, 0)

      assert {:error, :pairing_rejected, next} =
               Window.authorize(
                 opened,
                 "pair-property",
                 @device_id,
                 wrong,
                 context.client_certificate,
                 1
               )

      assert next.host_certificate_fingerprint == nil
      assert next.secret == @secret
    end
  end
end
