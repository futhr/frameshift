defmodule Frameshift.Pairing.Window do
  @moduledoc """
  Enforces the frame's physical pairing window in the software state machine.

  Only a local physical adapter should call `open/2`; a network request can
  never open a window. A successful request needs the one-time QR secret and
  an already authenticated TLS client certificate. The secret is consumed and
  the allowed certificate fingerprint is recorded before normal traffic is
  enabled. Real firmware must persist this transition atomically.
  """

  @window_ms 5 * 60 * 1_000
  @maximum_attempts 5
  @device_id_pattern ~r/^[A-Za-z0-9._~-]{16,128}$/
  @request_id_pattern ~r/^[A-Za-z0-9._~-]{1,128}$/

  @derive {Inspect,
           only: [
             :device_id,
             :host_certificate_fingerprint,
             :paired_request_id,
             :opened_at_ms,
             :attempts
           ]}
  @enforce_keys [:device_id, :secret]
  defstruct [
    :device_id,
    :secret,
    :host_certificate_fingerprint,
    :paired_request_id,
    :opened_at_ms,
    attempts: 0
  ]

  @type t :: %__MODULE__{
          device_id: String.t(),
          secret: binary() | nil,
          host_certificate_fingerprint: String.t() | nil,
          paired_request_id: String.t() | nil,
          opened_at_ms: non_neg_integer() | nil,
          attempts: non_neg_integer()
        }

  @doc "Creates an unpaired frame state from a device-owned random bootstrap secret."
  @spec new(String.t(), binary()) :: {:ok, t()} | {:error, :invalid_pairing_state}
  def new(device_id, secret)
      when is_binary(device_id) and byte_size(device_id) in 16..128 and is_binary(secret) and
             byte_size(secret) in 16..64 do
    if Regex.match?(@device_id_pattern, device_id),
      do: {:ok, %__MODULE__{device_id: device_id, secret: secret}},
      else: {:error, :invalid_pairing_state}
  end

  def new(_device_id, _secret), do: {:error, :invalid_pairing_state}

  @doc "Opens the five-minute window after a physical action on the frame."
  @spec open(t(), non_neg_integer()) :: {:ok, t()} | {:error, :already_paired | :invalid_time}
  def open(%__MODULE__{host_certificate_fingerprint: nil} = state, now_ms)
      when is_integer(now_ms) and now_ms >= 0 do
    {:ok, %{state | opened_at_ms: now_ms, attempts: 0}}
  end

  def open(%__MODULE__{host_certificate_fingerprint: fingerprint}, _now_ms)
      when is_binary(fingerprint),
      do: {:error, :already_paired}

  def open(%__MODULE__{}, _now_ms), do: {:error, :invalid_time}

  @doc "Authorizes an authenticated TLS peer only during the physical window."
  @spec authorize(t(), String.t(), String.t(), binary(), binary(), non_neg_integer()) ::
          {:ok, t()} | {:error, atom(), t()}
  def authorize(
        %__MODULE__{host_certificate_fingerprint: fingerprint} = state,
        request_id,
        device_id,
        _candidate,
        peer_certificate,
        now_ms
      )
      when is_binary(fingerprint) and is_integer(now_ms) and now_ms >= 0 do
    if replay?(state, request_id, device_id, peer_certificate),
      do: {:ok, state},
      else: {:error, :already_paired, state}
  end

  def authorize(%__MODULE__{} = state, request_id, device_id, candidate, peer_certificate, now_ms)
      when is_integer(now_ms) and now_ms >= 0 do
    cond do
      not valid_request_id?(request_id) ->
        {:error, :invalid_pairing_request, state}

      not window_open?(state, now_ms) ->
        {:error, :pair_mode_required, %{state | opened_at_ms: nil}}

      state.attempts >= @maximum_attempts ->
        {:error, :pairing_locked, %{state | opened_at_ms: nil}}

      device_id != state.device_id or not secure_equal?(candidate, state.secret) ->
        reject_attempt(state)

      not valid_peer_certificate?(peer_certificate) ->
        reject_attempt(state)

      true ->
        fingerprint =
          "sha256:" <> Base.encode16(:crypto.hash(:sha256, peer_certificate), case: :lower)

        {:ok,
         %{
           state
           | secret: nil,
             host_certificate_fingerprint: fingerprint,
             paired_request_id: request_id,
             opened_at_ms: nil,
             attempts: 0
         }}
    end
  end

  def authorize(
        %__MODULE__{} = state,
        _request_id,
        _device_id,
        _candidate,
        _peer_certificate,
        _now_ms
      ),
      do: {:error, :invalid_time, state}

  defp replay?(state, request_id, device_id, peer_certificate) do
    valid_request_id?(request_id) and request_id == state.paired_request_id and
      device_id == state.device_id and
      valid_peer_certificate?(peer_certificate) and
      "sha256:" <> Base.encode16(:crypto.hash(:sha256, peer_certificate), case: :lower) ==
        state.host_certificate_fingerprint
  end

  defp valid_request_id?(request_id) when is_binary(request_id),
    do: Regex.match?(@request_id_pattern, request_id)

  defp valid_request_id?(_request_id), do: false

  defp window_open?(%__MODULE__{opened_at_ms: opened}, now_ms) when is_integer(opened),
    do: now_ms >= opened and now_ms - opened < @window_ms

  defp window_open?(_state, _now_ms), do: false

  defp reject_attempt(state) do
    attempts = state.attempts + 1
    next = %{state | attempts: attempts}

    if attempts >= @maximum_attempts,
      do: {:error, :pairing_locked, %{next | opened_at_ms: nil}},
      else: {:error, :pairing_rejected, next}
  end

  defp valid_peer_certificate?(certificate)
       when is_binary(certificate) and byte_size(certificate) in 1..65_536 do
    case Frameshift.Transport.SPKIPin.fingerprint_der(certificate) do
      {:ok, _fingerprint} -> true
      _invalid -> false
    end
  end

  defp valid_peer_certificate?(_certificate), do: false

  defp secure_equal?(left, right)
       when is_binary(left) and is_binary(right) and byte_size(left) == byte_size(right) do
    left
    |> :binary.bin_to_list()
    |> Enum.zip(:binary.bin_to_list(right))
    |> Enum.reduce(0, fn {left_byte, right_byte}, difference ->
      Bitwise.bor(difference, Bitwise.bxor(left_byte, right_byte))
    end)
    |> Kernel.==(0)
  end

  defp secure_equal?(_left, _right), do: false
end
