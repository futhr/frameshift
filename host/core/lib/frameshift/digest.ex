defmodule Frameshift.Digest do
  @moduledoc "Content identity helpers for immutable Frameshift objects."

  @sha256_pattern ~r/^sha256:[0-9a-f]{64}$/

  @doc "Hashes content bytes into the lowercase `sha256:` identifier used on disk and on wire."
  @spec sha256(iodata()) :: String.t()
  def sha256(bytes) do
    "sha256:" <> (:crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower))
  end

  @doc "Checks the exact lowercase protocol spelling of a SHA-256 digest."
  @spec valid_sha256?(term()) :: boolean()
  def valid_sha256?(digest) when is_binary(digest), do: Regex.match?(@sha256_pattern, digest)
  def valid_sha256?(_), do: false

  @doc "Extracts the 64 hexadecimal characters from an already validated digest."
  @spec hex!(String.t()) :: String.t()
  def hex!("sha256:" <> hex) when byte_size(hex) == 64, do: hex
end
