defmodule FrameshiftBuild do
  @moduledoc """
  Canonical physical profile identity shared with the browser's Gleam codec.

  A valid document preserves claims and provenance. It does not grant assembly
  compatibility, source authenticity, safety qualification or purchasing rights.
  """

  @doc "Validates canonical bytes and returns their versioned SHA-256 identity."
  @spec profile_identity(binary()) :: {:ok, binary()} | {:error, binary()}
  def profile_identity(bytes) when is_binary(bytes) do
    case :frameshift_build.identity_payload(bytes) do
      {:ok, payload} ->
        {:ok, "sha256:" <> Base.encode16(:crypto.hash(:sha256, payload), case: :lower)}

      {:error, refusal} ->
        {:error, :frameshift_build.refusal_code(refusal)}
    end
  end

  def profile_identity(_), do: {:error, "invalid_document"}
end
