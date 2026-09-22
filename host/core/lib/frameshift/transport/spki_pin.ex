defmodule Frameshift.Transport.SPKIPin do
  @moduledoc false

  require Record

  Record.defrecordp(
    :otp_certificate,
    Record.extract(:OTPCertificate, from_lib: "public_key/include/public_key.hrl")
  )

  Record.defrecordp(
    :otp_tbs_certificate,
    Record.extract(:OTPTBSCertificate, from_lib: "public_key/include/public_key.hrl")
  )

  @accepted_path_failures [:unknown_ca, :selfsigned_peer, :hostname_check_failed]

  @spec fingerprint(tuple()) :: {:ok, binary()} | {:error, :invalid_certificate}
  def fingerprint(certificate) when is_tuple(certificate) do
    public_key_info =
      certificate
      |> otp_certificate(:tbsCertificate)
      |> otp_tbs_certificate(:subjectPublicKeyInfo)

    encoded = :public_key.pkix_encode(:OTPSubjectPublicKeyInfo, public_key_info, :otp)
    {:ok, :crypto.hash(:sha256, encoded)}
  rescue
    _exception -> {:error, :invalid_certificate}
  catch
    _kind, _reason -> {:error, :invalid_certificate}
  end

  def fingerprint(_certificate), do: {:error, :invalid_certificate}

  @doc false
  @spec verify(tuple(), term(), map()) ::
          {:valid, map()} | {:unknown, map()} | {:fail, term()}
  def verify(_certificate, {:bad_cert, reason}, state) when reason in @accepted_path_failures,
    do: {:valid, state}

  def verify(_certificate, {:bad_cert, reason}, _state), do: {:fail, {:bad_cert, reason}}
  def verify(_certificate, {:extension, _extension}, state), do: {:unknown, state}
  def verify(_certificate, :valid, state), do: {:valid, state}

  def verify(certificate, :valid_peer, %{expected: expected} = state) do
    case fingerprint(certificate) do
      {:ok, ^expected} -> {:valid, Map.put(state, :matched, true)}
      {:ok, _different} -> {:fail, :server_spki_mismatch}
      {:error, _reason} -> {:fail, :invalid_peer_certificate}
    end
  end

  def verify(_certificate, _event, state), do: {:unknown, state}
end
