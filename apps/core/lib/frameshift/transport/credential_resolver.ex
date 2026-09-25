defmodule Frameshift.Transport.CredentialResolver do
  @moduledoc """
  Resolves an opaque paired-frame reference immediately before direct TLS I/O.

  A macOS implementation must use Keychain-backed identity access. It returns
  the certificate and an OTP-compatible private-key signer or key handle; the
  reference, certificate, and signer never appear in a local UI command,
  recipe, Thing Description, audit entry, or response.
  """

  @type identity :: %{certificate: binary(), private_key: term()}

  @doc "Resolves one opaque Keychain reference without persisting credential material."
  @callback resolve(String.t(), term()) :: {:ok, identity()} | {:error, atom()}
end
