defmodule Frameshift.Digest do
  @moduledoc "Content identity helpers for immutable Frameshift objects."

  @sha256_pattern ~r/^sha256:[0-9a-f]{64}$/

  @spec sha256(iodata()) :: String.t()
  def sha256(bytes) do
    "sha256:" <> (:crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower))
  end

  @spec valid_sha256?(term()) :: boolean()
  def valid_sha256?(digest) when is_binary(digest), do: Regex.match?(@sha256_pattern, digest)
  def valid_sha256?(_digest), do: false

  @spec hex!(String.t()) :: String.t()
  def hex!("sha256:" <> hex) when byte_size(hex) == 64, do: hex
end
